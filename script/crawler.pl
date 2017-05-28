#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature q(say);

use lib 'lib/';
use Gion;
use Gion::Config;

use Carp;
use Date::Parse;
use DateTime;
use DateTime::Format::ISO8601;
use DateTime::Format::Mail;
use DateTime::Format::W3CDTF;
use Encode;
use File::Spec;
use Furl;
use Getopt::Long qw(GetOptionsFromArray);
use HTTP::Date ();
use JSON;
use Time::Piece;
use Try::Tiny;
use URI;
use XML::Atom::Feed;
use XML::RSS::LibXML;

#指定取得かどうか

my $eid;
my $term;
GetOptionsFromArray(\@ARGV,
    "e=i{,}" => \@$eid,
    "silent" => \(my $verbose_tmp),
    "term=i" =>\$term,
);

verbose($verbose_tmp ? 0 : 1);

#DBへ接続
my $db = Gion->cli_dbh;

my $ua = Furl->new(
    headers => [
        "Accept-Encoding" => 'gzip',
        Connection => 'close'
    ],
    max_redirects => 0,
    %{config->param('crawler')},
);
$ua->env_proxy;

#取得先を取得
my $rs;
if (@$eid) {
    $rs = $db->select_all("SELECT * FROM feed WHERE id IN :entry_id", { entry_id => $eid });
} elsif ($term) {
    $rs = $db->select_all('SELECT * FROM feed WHERE term = ?', $term);
} else {
    $rs = $db->select_all('SELECT * FROM feed');
}

my $now = Time::Piece->new()->epoch;

for my $c (@$rs) {

    # 取得する
    my $cache = JSON::from_json($c->{cache}) if $c->{cache};
    my $res = agent($c->{url}, $cache);

    # 結果が得られない場合、次の対象を処理する
    if ($res->{headers}{code} eq '404' or $res->{headers}{code} =~ /5\d\d/) {
        $db->query('
            UPDATE feed SET http_status = 404, term = 4, cache = ? WHERE id = ?
        ', JSON::to_json($res->{headers}), $c->{id});
        logger(sprintf "404 %4d %s",
            $c->{id},
            encode_utf8($c->{title}));
        next;
    }

    # 301 Moved Permanentlyの場合
    if (defined $res->{headers}{_code} and $res->{headers}{_code} eq '301') {
        $db->query('
            UPDATE feed SET url = ? WHERE id = ?
        ', $res->{headers}->{location}, $c->{id});
        logger(sprintf "301 %s -> %s",
            $c->{url},
            $res->{headers}{location});
        delete $res->{headers}{location};
        delete $res->{headers}{_code};
    }

    logger(sprintf "%3d %4d %s",
        $res->{headers}{code},
        $c->{id},
        encode_utf8($c->{title}));

    # 304 Not Modifiedの場合更新しない場合次の対象を処理する
    if ($res->{headers}{code} eq '304') {
        # 更新
        $db->query('
            UPDATE feed SET http_status = 304, term = ?, cache = ? WHERE id = ?
        ',
            update_term(from_mysql_datetime($c->{pubdate})->epoch),
            JSON::to_json($res->{headers}),
            $c->{id});
        next;
    }

    my $errorcount = 0;
    my $data;

    #パースする
    try {
        if ($c->{parser} == 0 or $c->{parser} == 1) {
            $data = parser_rss($res->{content}, $c->{url});
        }
    } catch {
        $errorcount++;
    };
    try {
        if (
            ($c->{parser} == 0 and $errorcount == 1) or $c->{parser} == 2 
        ) {
            $data = parser_atom( $res->{content}, $c->{url} );
        }
    } catch {
        logger(sprintf "ERR %4d %s", $c->{id}, encode_utf8($c->{title}));

        # パースにいずれも失敗した場合、パーサーの設定を初期化する。
        # 次回のクロール時にクロールする
        $db->query('
            UPDATE feed
            SET http_status = ?,
                parser = 0,
                term = 1,
                cache = ?
            WHERE id = ?
        ', 
            $res->{headers}{code},
            JSON::to_json($res->{headers}),
            $c->{id});
        next;
    };

    # パーサ種類を保存
    $db->query('
        UPDATE feed SET parser = ? WHERE id = ?
    ', ($errorcount + 1), $c->{id});

    # クロール対象のエントリーの最新の情報の日付を取得する
    my $latest = from_mysql_datetime($c->{pubdate});

    # term の判断基準となるlast-Modifiedを取得
    # agentの戻り値では、 If-Modified-Since として返却される
    my $last_modified = HTTP::Date::str2time($res->{headers}{'If-Modified-Since'});

    my $import_counter = 0;
    for my $d (@$data) {

        # If-Modified-Sinceが取得できなかった場合、RSSのフィードから得る
        unless ($last_modified) {
            $last_modified = $d->{pubdate}->epoch;
        }

        # 新しいもののみを取り込む XXX デバッグ時は以下を抑止
        next if $d->{pubdate}->epoch <= $latest->epoch;

        # RSSのデータから最終更新時間を更新する
        if ($d->{pubdate}->epoch > $last_modified) {
            $last_modified = $d->{pubdate}->epoch;
        }

        # 取り込まれたら、カウンタを更新する
        $import_counter++;

        #購読リストを取得する
        my $target = $db->select_all('
            SELECT * FROM target WHERE feed_id = ?
        ', $c->{id});

        for (@$target) {

            # 既読管理から最終既読を参照
            my $entry = $db->select_one('
                SELECT pubdate
                FROM entry
                WHERE target_id = ? 
                    AND readflag = 1
                ORDER BY pubdate DESC
                LIMIT 1
            ', $_->{id});

            my $state = 0;
            unless ($entry) {
                # 既読データが存在しない場合
                $state = 1;
            } else {
                $state = from_mysql_datetime($entry) < $d->{pubdate};
            }

            if ($state) {
                # 購読リストに基づいて、更新情報をユーザーごとへ挿入
                $db->query('
                    INSERT IGNORE INTO entry 
                    (guid, pubdate, readflag, target_id, update_at, user_id)
                    VALUES (?,?,0,?,CURRENT_TIMESTAMP,?)
                ', $d->{guid},
                to_mysql_datetime($d->{pubdate}),
                $_->{id},
                $_->{user_id},
                );
                logger(sprintf "INSERT user_id:%4d guid: %s",
                    $_->{user_id},
                    $d->{guid});
            }
        }

        # エントリに対するストーリーを挿入
        $db->query('
            INSERT IGNORE INTO story
            (guid, title, description, url)
            VALUES (?,?,?,?)
        ',
            $d->{guid},
            $d->{title}       ? $d->{title}       : '',
            $d->{description} ? $d->{description} : '',
            $d->{url},
        );
    }

    # 200で、取得物があれば1とする
    my $_term;
    if ($import_counter) {
        $_term = 1;
    } else {
        $_term = update_term($last_modified);
    }

    $db->query('
        UPDATE feed 
        SET http_status = ?,
            pubdate = ?,
            term = ?,
            cache = ?
        WHERE id = ?
    ', $res->{headers}{code},
        to_mysql_datetime(Time::Piece->new($last_modified)),
        $_term,
        JSON::to_json($res->{headers}),
        $c->{id});
}

sub update_term {
    my $epoch = shift;

    return 1 unless $epoch;
    # 1: half hour, 2: every hour, 3: half day, 4: 2days, 5: one week
    my $term = 1; 
    my $ans = $now - $epoch;

    #更新がない場合、クロールを疎遠にしていく。
    if ( $ans > 86400 * 14 ) {
        # 14日以上に更新がない場合は、1週間に1回クロールする
        $term = 5;
    } elsif ( $ans > 86400 * 7 ) {
        # 7日以上に更新がない場合は、2日に1回クロールする
        $term = 4;
    } elsif ( $ans > 86400 * 4 ) {
        # 4日以上に更新がない場合は、半日に1回クロールする
        $term = 3;
    } elsif ( $ans > 3600 * 12 ) {
        # 12時間以上に更新がない場合は、毎時に1回クロールする
        $term = 2;
    }
    return $term;
}

sub to_mysql_datetime {
    shift->strftime('%Y-%m-%d %H:%M:%S');
}

sub from_mysql_datetime {
    my $t = shift;
    if ($t eq '0000-00-00 00:00:00') {
        return Time::Piece->new;
    }
    localtime( Time::Piece->strptime( $t, '%Y-%m-%d %H:%M:%S' ) );
}

#すごく汚い日付のパース
sub from_feed_datetime {
    my $t = shift;
    my $dt;

    eval {
        $dt = DateTime::Format::Mail->parse_datetime($t) unless defined $dt;
    };

    eval {
        $dt = DateTime::Format::W3CDTF->parse_datetime($t)
          unless defined $dt;
    };

    eval {
        $dt = DateTime::Format::ISO8601->parse_datetime($t)
          unless defined $dt;
    };

    eval {
        $dt = DateTime->from_epoch( epoch => HTTP::Date::str2time($t) )
          unless defined $dt;
    };

    eval {
        $dt = DateTime->from_epoch( epoch => Date::Parse::str2time($t) )
          unless defined $dt;
    };

    return Time::Piece->new( $dt->epoch() ) if defined $dt;

    return Time::Piece->new();

    #croak("ERROR:Time Parse");
}

#RSSの場合
sub parser_rss {
    my $str = shift;
    my $rsurl = shift;

    my $data;
    my $ns_dc = "http://purl.org/dc/elements/1.1/";
    my $rss = XML::RSS::LibXML->new();
    try {
        $rss->parse($str);
    } catch {
        return croak("error");
    };
 
    foreach ( @{ $rss->{items} } ) {
        my $dt;
        if ( defined $_->{pubDate} ) {
            $dt = from_feed_datetime($_->{pubDate});
        } elsif ( defined $_->{$ns_dc}->{date} ) {
            $dt = from_feed_datetime($_->{$ns_dc}{date});
        } else {
            $dt = localtime;
        }

        my $guid = $_->{guid};
        my $url = $_->{link};
        if (!$guid or $guid eq '') {
            $guid = $url;    #guidがない場合は、URLを代用
        } elsif (!$url or $url eq '') {
            $url = $guid;    #URLがない場合は、GUIDを代用
        }

        if ($url eq '' or $guid eq '') {
            next;   # 両方空の場合は登録できない
        }

        #相対パスだと修正する
        if ($url !~ /^http/) {
            $url = URI->new_abs($url, $rsurl)->as_string;
        }

        my %h = (
            guid => $guid,
            title => $_->{title},
            description => $_->{description},
            pubdate => $dt,
            url => $url,
        );
        push @$data, \%h;
    }
    croak("error") unless $data;
    $data;
}

#Atomの場合
sub parser_atom {
    my $str = shift;
    my $rsurl = shift;

    my $data;
    my $atom = XML::Atom::Feed->new( \$str );
    my @entry = $atom->entries;
    foreach (@entry) {
        my $dt = from_feed_datetime( $_->updated );

        my $url = $_->link->href;

        #相対パスだと修正する
        if ( $url !~ /^http/ ) {
            $url = URI->new_abs($url, $rsurl)->as_string;
        }

        my %h = (
            guid => $url,
            title => decode( 'utf-8', $_->title ),
            description => decode( 'utf-8', $_->summary ),
            pubdate => $dt,
            url => $url,
        );
        push @$data, \%h;
    }
    croak("error") unless $data;
    $data;
}

sub logger {
    my $str = shift . "\n";
    if (verbose()) {
        print STDERR $str;
    }
}

sub agent {
    my $url = shift;
    my $opt = shift;

    my $response;
    my @headers;
    if (ref $opt eq 'HASH') {
        while (my ($key, $value) = each(%$opt)){
            next if $key eq 'code';
            push @headers, $key => $value;
        }
        $response = $opt;
    }
    my $res = $ua->get($url, \@headers);
    my $code = $res->code;

    # ここで違う名称で保存する
    # キャッシュして、取得時にそのまま転用させるため
    if (defined $res->headers->{etag}) {
        $response->{'If-None-Match'} = $res->headers->{etag}[0];
    }
    $response->{'If-Modified-Since'} = $res->headers->last_modified
        if $res->headers->last_modified;
    $response->{code} = $code;

# redirect needed status code is  $code =~ /^30[1237]$/;
# refer Furl::HTTP

    if ($code eq '200') {
        return {
            content => $res->content,
            headers => $response,
        };
    }elsif ($code =~ /^30[1237]$/) {
        my $location = $res->headers->{location}[0];
        if ($location !~ /^http/) {
            $location = URI->new_abs($location, $url)->as_string;
        }
        # ** Moved Permanently ** need update resource url
        # return location data.
        if ($code eq '301') {
            $response->{location} = $location;
            $response->{_code} = '301';
        }
        return agent($location, $response);
    }elsif ($code eq '304') {
        return {
            headers => $response,
        };
    }
    return {
        headers => $response,
    };
}

my $_verbose;
sub verbose {
    if (my $opt = shift) {
        $_verbose = $opt;
    }
    $_verbose;
}
1;

=encoding utf8

=head1 NAME

crawler - item crawler.

=cut
