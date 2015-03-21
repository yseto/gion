package Gion::Batch::Crawler;
use base qw/Gion::Batch/;

use utf8;
use Try::Tiny;
use Carp;
use Cache::File;
use URI;
use URI::Fetch;
use Encode;
use Time::Piece;
use LWP::UserAgent;
use XML::RSS;
use XML::Atom::Feed;
use Gion::DB;
use Getopt::Long qw(GetOptionsFromArray);
use Data::Dumper;
use DateTime;
use DateTime::Format::Mail;
use DateTime::Format::W3CDTF;
use DateTime::Format::ISO8601;
use HTTP::Date;
use Date::Parse;
use File::Spec;

our $verbose;

sub run {
    my $self = shift;

    #指定取得かどうか
    my $eid;
    my $term;
    GetOptionsFromArray(
        \@_,
        "e=i{,}"  => \@$eid,
        "silent" =>  \(my $verbose_tmp),
        "term=i"  => \$term,
    );
    $verbose = $verbose_tmp ? 0 : 1;

    #DBへ接続
    my $db = Gion::DB->new;
    my $engine;
    if ( $self->config->{db}->{dsn} =~ /^(?i:dbi):SQLite:/ ) {
        $engine = "SQLite";
    }
    else {
        $engine = "mysql";
    }

    #取得先を取得
    my $rs;
    if (@$eid) {
        $rs =
          $db->dbh->select_all( 'SELECT * FROM feeds WHERE id IN (?)', $eid );
    }
    elsif ($term) {
        $rs =
          $db->dbh->select_all( 'SELECT * FROM feeds WHERE term = ?', $term );
    }
    else {
        $rs = $db->dbh->select_all('SELECT * FROM feeds');
    }

    #ユーザーエージェントを設定
    my $ua = LWP::UserAgent->new;
    if ( $self->config->{crawler}->{timeout} ) {
        $ua->timeout( $self->config->{crawler}->{timeout} );
    }
    if ( $self->config->{crawler}->{ua} ) {
        $ua->agent( $self->config->{crawler}->{ua} );
    }

    #キャッシュの設定
    my $dir = File::Spec->catdir( File::Spec->tmpdir(), 'gion' );
    my $cache = Cache::File->new( cache_root => $dir );

    my $engine_str = $engine eq "SQLite" ? "OR" : "";
    my $now = Time::Piece->new()->epoch;

    for my $c (@$rs) {

        #取得する
        my $res =
          URI::Fetch->fetch( $c->{url}, Cache => $cache, UserAgent => $ua );

        #結果が得られない場合、次の対象を処理する
        unless ( defined $res ) {
            $db->dbh->query(
                'UPDATE feeds SET http_status = ?, term = 4 WHERE id = ?',
                404, $c->{id} );
            $self->logger( sprintf "404 %4d %s",
                $c->{id}, encode_utf8( $c->{title} ) );
            next;
        }

        #301 Moved Permanentlyの場合
        if ( defined $res->{http_response}->{_previous} ) {
            my $preres = $res->{http_response}->{_previous};
            if ( $preres->{_rc} == 301 ) {
                $db->dbh->query(
                    'UPDATE feeds SET url = ? WHERE id = ?',
                    $preres->{_headers}->{location},
                    $c->{id}
                );
                $self->logger( sprintf "301 %s -> %s",
                    $c->{url}, $preres->{_headers}->{location} );
            }
        }

        $self->logger( sprintf "%3d %4d %s",
            $res->http_status, $c->{id}, encode_utf8( $c->{title} ) );

 #取得できたので、リターンコード、購読間隔を更新する。
        my $term =
          1;   # 1: half hour, 2: every hour, 3: half day, 4: 2days, 5: one week
        my $ans = $now - $c->{pubDate};

        #更新がない場合、クロールを疎遠にしていく。
        if ( $ans > 86400 * 14 )
        { # 14日以上に更新がない場合は、1週間に1回クロールする
            $term = 5;
        }
        elsif ( $ans > 86400 * 7 )
        { # 7日以上に更新がない場合は、2日に1回クロールする
            $term = 4;
        }
        elsif ( $ans > 86400 * 4 )
        { # 4日以上に更新がない場合は、半日に1回クロールする
            $term = 3;
        }
        elsif ( $ans > 3600 * 12 )
        { # 12時間以上に更新がない場合は、毎時に1回クロールする
            $term = 2;
        }

      #304 Not Modifiedの場合更新しない場合次の対象を処理する
        if ( $res->http_status == 304 ) {

            # 更新
            $db->dbh->query(
                'UPDATE feeds SET http_status = ?, term = ? WHERE id = ?',
                $res->http_status, $term, $c->{id} );
            next;
        }

        my $errorcount = 0;
        my $data;

        #パースする
        try {
            if ( $c->{parser} == 0 or $c->{parser} == 1 ) {
                $data = $self->parser_rss( $res->content, $c->{url} );
            }
        }
        catch {
            $errorcount++;
        };
        try {
            if ( ( $c->{parser} == 0 and $errorcount == 1 )
                or $c->{parser} == 2 )
            {
                $data = $self->parser_atom( $res->content, $c->{url} );
            }
        }
        catch {
            $self->logger( sprintf "ERR %4d %s",
                $c->{id}, encode_utf8( $c->{title} ) );

#パースにいずれも失敗した場合、パーサーの設定を初期化する。次回のクロール時にクロールする
            $db->dbh->query(
'UPDATE feeds SET http_status = ?, parser = 0, term = 1 WHERE id = ?',
                $res->http_status, $c->{id}
            );
            next;
        };

        #パーサ種類を保存
        $db->dbh->query(
            'UPDATE feeds SET parser = ? WHERE id = ?',
            ( $errorcount + 1 ),
            $c->{id}
        );

 #クロール対象のエントリーの最新の情報の日付を取得する
        my $pd = $db->dbh->select_row( "SELECT pubDate FROM feeds WHERE id = ?",
            $c->{id} );

        #最新の日付があれば、活用する。
        my $latest =
          defined $pd
          ? Time::Piece->new( $pd->{pubDate} )
          : Time::Piece->strptime( '2010-01-01', '%Y-%m-%d' );

        # term の判断基準となるlast-Modifiedを取得
        my $last_modified = HTTP::Date::str2time( $res->last_modified );

        my $import_counter = 0;
        for my $d (@$data) {

            #新しいもののみを取り込む
            next if $d->{pubDate}->epoch <= $latest->epoch;

#返さない場合があるので、エントリが新しい場合の更新日を利用する
            unless ($last_modified) {
                $last_modified = $d->{pubDate}->epoch;
            }

            # 取り込まれたら、カウンタを更新する
            $import_counter++;

            #購読リストを取得する
            my $target =
              $db->dbh->select_all( 'SELECT * FROM target WHERE _id_feeds = ?',
                $c->{id} );

            for (@$target) {

                # 既読管理から最終既読を参照
                my $entries = $db->dbh->select_row( 'SELECT pubDate FROM entries WHERE
                    _id_target = ? AND readflag = 1 ORDER BY pubDate DESC LIMIT 1', $_->{id} );

                my $d_pubDate = to_mysql_datetime( $d->{pubDate} );
                if ( from_mysql_datetime($entries->{pubDate}) < $d->{pubDate} ) {
                    #購読リストに基づいて、更新情報をユーザーごとへ挿入
                    $db->dbh->query(
                        "INSERT $engine_str IGNORE INTO entries 
                        (guid, pubDate, readflag, _id_target, updatetime, user)
                        VALUES (?,?,0,?,CURRENT_TIMESTAMP,?)",
                        $d->{guid},
                        $d_pubDate,
                        $_->{id},
                        $_->{user}
                    );
                    $self->logger(sprintf "INSERT user:%4d guid: %s", $_->{user}, $d->{guid} );
                }
            }

            #エントリに対するストーリーを挿入
            $db->dbh->query(
                "INSERT $engine_str IGNORE INTO stories
                (guid, title, description, url)
                VALUES (?,?,?,?)",
                $d->{guid},
                $d->{title}       ? $d->{title}       : '',
                $d->{description} ? $d->{description} : '',
                $d->{url},
            );
        }

        # 200で、取得物があれば1とする
        if ($import_counter) {
            $term = 1;
        }

#フィードがおかしい場合は、日付がないので元々の日付を利用する
        unless ($last_modified) {
            $last_modified = $latest->epoch;
        }
        $db->dbh->query(
'UPDATE feeds SET http_status = ?, pubDate = ?, term = ? WHERE id = ?',
            $res->http_status, 
            to_mysql_datetime(Time::Piece->new($last_modified)),
            $term,
            $c->{id} );
    }
}

sub to_mysql_datetime {
    shift->strftime('%Y-%m-%d %H:%M:%S');
}

sub from_mysql_datetime {
    my $t = shift;
    Time::Piece->strptime( $t, '%Y-%m-%d %H:%M:%S' );
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
    my $self  = shift;
    my $str   = shift;
    my $rsurl = shift;

    my $data;
    my $ns_dc = "http://purl.org/dc/elements/1.1/";
    my $rss   = new XML::RSS;
    $rss->parse($str);
    foreach ( @{ $rss->{items} } ) {
        my $dt;
        if ( defined $_->{pubDate} ) {
            $dt = from_feed_datetime( $_->{pubDate} );
        }
        elsif ( defined $_->{$ns_dc}->{date} ) {
            $dt = from_feed_datetime( $_->{$ns_dc}->{date} );
        }
        else {
            $dt = localtime;
        }

        my $guid = $_->{guid};
        my $url  = $_->{link};
        if ( !$guid or $guid eq '' ) {
            $guid = $url;    #guidがない場合は、URLを代用
        }
        elsif ( !$url or $url eq '' ) {
            $url = $guid;    #URLがない場合は、GUIDを代用
        }

        #相対パスだと修正する
        if ( $url !~ /^http/ ) {
            $url = URI->new_abs( $url, $rsurl )->as_string;
        }

        my $h = {
            guid        => $guid,
            title       => $_->{title},
            description => $_->{description},
            pubDate     => $dt,
            url         => $url,
        };
        push( @$data, $h );
    }
    croak("error") unless $data;
    $data;
}

#Atomの場合
sub parser_atom {
    my $self  = shift;
    my $str   = shift;
    my $rsurl = shift;

    my $data;
    my $atom    = XML::Atom::Feed->new( \$str );
    my @entries = $atom->entries;
    foreach (@entries) {
        my $dt = from_feed_datetime( $_->updated );

        my $url = $_->link->href;

        #相対パスだと修正する
        if ( $url !~ /^http/ ) {
            $url = URI->new_abs( $url, $rsurl )->as_string;
        }

        my $h = {
            guid        => $url,
            title       => decode( 'utf-8', $_->title ),
            description => decode( 'utf-8', $_->summary ),
            pubDate     => $dt,
            url         => $url,
        };
        push( @$data, $h );
    }
    croak("error") unless $data;
    $data;
}

sub logger {
    my $self = shift;
    my $str  = shift . "\n";
    if ($verbose) {
        print STDERR $str;
    }
}

1;
