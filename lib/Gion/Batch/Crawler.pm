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
use Time::HiRes qw(sleep);
use Term::ProgressBar;
use LWP::UserAgent;
use XML::RSS::LibXML;
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

sub run {
    my $self = shift;

    my $cfg = $self->config;

    # 指定取得かどうか
    my $eid;
    my $silent;
    my $fail;
    GetOptionsFromArray(\@_, "e=i{,}" => \@$eid, "silent" => \$silent, "fail" => \$fail );

    # DBへ接続
    my $db = Gion::DB->new;
    my $engine;
    if ($cfg->{db}->{dsn} =~ /^(?i:dbi):SQLite:/){
        $engine = "SQLite";
    }else{
        $engine = "mysql";
    }
    # キャッシュの設定
    my $ca = Cache::File->new(cache_root => $cfg->{crawler}->{cache});

    # 取得先を取得
    my $rs;
    my $count = 1;
    if (@$eid){
        $rs = $db->dbh->select_all('SELECT * FROM target WHERE id IN (?)', $eid);
        $count = @$eid;
    }elsif(defined $fail){
        $rs = $db->dbh->select_all('SELECT * FROM target WHERE http_status < 0');
        $count = $db->dbh->select_row('SELECT COUNT(*) AS t FROM target WHERE http_status < 0')->{t};
    }else{
        $rs = $db->dbh->select_all('SELECT * FROM target');
        $count = $db->dbh->select_row('SELECT COUNT(*) AS t FROM target')->{t};
    }

    my $ua = LWP::UserAgent->new;
    $ua->timeout($cfg->{crawler}->{timeout});
    $ua->agent($cfg->{crawler}->{ua});

    #プログレスバーを定義
    my $prog;
    my $progcount = 0;
    unless(defined $silent){
        $prog = Term::ProgressBar->new( { count => $count } );
        $prog->max_update_rate(1);
    }

    for my $c (@$rs) {

        #一定時間ごとに動作するためにスリープする
        sleep($cfg->{crawler}->{sleep});

        #プログレスバーの件数更新
        $progcount++;

        #取得する
        my $res = URI::Fetch->fetch($c->{url}, Cache => $ca, UserAgent => $ua);

        #結果が得られない場合、次の対象を処理する
        unless (defined $res) {
            $db->dbh->query('UPDATE target SET http_status = ? WHERE id = ?', 404, $c->{id});
            unless (defined $silent){
                $prog->message(sprintf "404 %4d %s", $c->{id}, encode_utf8($c->{title}));
                $prog->update($progcount);
            }
            next;
        }

        #301 Moved Permanentlyの場合
        if (defined $res->{http_response}->{_previous}) {
            my $preres = $res->{http_response}->{_previous};
            if ($preres->{_rc} == 301) {
                $db->dbh->query('UPDATE target SET url = ? WHERE id = ?', $preres->{_headers}->{location}, $c->{id});
                unless (defined $silent){
                    $prog->message(sprintf "301 %s -> %s", $c->{url}, $preres->{_headers}->{location});
                }
            }
        }

        #プログレスバー更新
        unless(defined $silent){
            $prog->message(sprintf "%3d %4d %s", $res->http_status, $c->{id}, encode_utf8($c->{title}));
            $prog->update($progcount);
        }

        #取得できたので、リターンコードを更新する。
        $db->dbh->query('UPDATE target SET http_status = ? WHERE id = ?', $res->http_status, $c->{id});

        # 304 Not Modifiedの場合更新しない場合次の対象を処理する
        next if $cfg->{crawler}->{no304} == 0 and $res->http_status == 304;

        #クロール対象のエントリーの最新の情報の日付を取得する
        my $pd = $db->dbh->select_row("SELECT pubDate FROM entries WHERE _id_target = ? ORDER BY pubDate DESC LIMIT 1", $c->{id});

        my $latest = Time::Piece->strptime( '2010-01-01', '%Y-%m-%d' );
        #最新の日付があれば、活用する。
        if (defined $pd) {
            $latest = from_mysql_datetime($pd->{pubDate});
        }

        my $errorcount = 0;
        my $data;

        try{
            if($c->{parser} == 0 or $c->{parser} == 1){
                $data = &parser_rss($res->content, $latest, $c->{id}, $cfg->{crawler}->{pubDatecheck}, $c->{user});
            }
        }catch{
            $errorcount++;
        };

        try{
            if( ($c->{parser} == 0 and $errorcount == 1) or $c->{parser} == 2 ){
                $data = &parser_atom($res->content, $latest, $c->{id}, $cfg->{crawler}->{pubDatecheck}, $c->{user});
            }
        }catch{
            unless(defined $silent){
                $prog->message(sprintf "ERR %4d %s", $c->{id}, encode_utf8($c->{title}));
            }
            my $errflg = $c->{http_status} < 0 ? $c->{http_status} - 1 : -1 ;
            $db->dbh->query('UPDATE target SET http_status = ?, parser = 0 WHERE id = ?', $errflg, $c->{id});
            next;
        };

        # パーサ種類を保存
        $db->dbh->query('UPDATE target SET parser = ? WHERE id = ?', ($errorcount+1), $c->{id});

        for (@$data) {

            if ( not defined $_->{guid} or $_->{guid} eq '' ) {
                $_->{guid} = $_->{url};   #guidがない場合は、URLを代用
            }
            elsif ( not defined $_->{url} or $_->{url} eq '' ) {
                $_->{url} = $_->{guid};   #URLがない場合は、GUIDを代用
            }

            # 相対パスだと修正する
            unless ( $_->{url} =~ /^http/ ) {
                my $rsuri = $db->dbh->select_row('SELECT url FROM target WHERE id = ?', $_->{id_target});
                $_->{url} = URI->new_abs($_->{url}, $rsuri->{url})->as_string;
            }

            my $engine_str = $engine eq "SQLite" ? "OR" : "";

            $db->dbh->query("INSERT $engine_str IGNORE INTO entries 
                (guid, pubDate, readflag, _id_target, updatetime, user)
                VALUES (?,?,0,?,CURRENT_TIMESTAMP,?)",
                $_->{guid},
                to_mysql_datetime( $_->{pubDate} ),
                $_->{id_target},
                $_->{user}
            );

            my $st_title = $_->{title} ? $_->{title} : '';
            my $st_description = $_->{description} ? $_->{description} : '';

            $db->dbh->query("INSERT $engine_str IGNORE INTO stories
                (guid, title, description, url)
                VALUES (?,?,?,?)",
                $_->{guid},
                $st_title,
                $st_description,
                $_->{url},
            );

        }

    }

}

sub to_mysql_datetime {
    shift->strftime('%Y-%m-%d %H:%M:%S');
}

sub from_mysql_datetime {
    my $t = shift;
#   warn $t;
    Time::Piece->strptime($t, '%Y-%m-%d %H:%M:%S');
}

# すごく汚い日付のパース
sub from_feed_datetime{
    my $t = shift;
    my $dt;

    eval {
        $dt = DateTime::Format::Mail->parse_datetime($t) unless defined $dt;
    };

    eval {
        $dt = DateTime::Format::W3CDTF->parse_datetime($t) unless defined $dt;
    };

    eval {
        $dt = DateTime::Format::ISO8601->parse_datetime($t) unless defined $dt;
    };

    eval {
        $dt = DateTime->from_epoch(epoch => HTTP::Date::str2time($t)) unless defined $dt;
    };

    eval {
        $dt = DateTime->from_epoch(epoch => Date::Parse::str2time($t)) unless defined $dt;
    };

    return Time::Piece->new( $dt->epoch() ) if defined $dt;

    croak("ERROR:Time Parse");
}

sub parser_rss {
    my $str    = shift;
    my $latest = shift;
    my $id     = shift;
    my $pcheck = shift;
    my $user   = shift;

    my $data;
    my $errorcheck = 0;

    my $lateststr = $latest->ymd('') . $latest->hms('');

    #RSSの場合
    my $rss = new XML::RSS::LibXML;
    $rss->parse($str);
    for my $ref (@{$rss->{items}}){

        my $dt    = localtime;
        my $ns_dc = "http://purl.org/dc/elements/1.1/";

        if(defined $ref->{pubDate}){
            $dt = from_feed_datetime( $ref->{pubDate} );
        }elsif(defined $ref->{$ns_dc}->{date}){
            $dt = from_feed_datetime( $ref->{$ns_dc}->{date} );
        }

        #DBに格納されているエントリーより古い情報は
        #取り込まない設定の場合、次の情報を処理する
        my $dtstr = $dt->ymd('') . $dt->hms('');
        $errorcheck++;
        next if $pcheck == 0 and ($dtstr <= $lateststr);

        my $h = {
            guid        => $ref->{guid},
            title       => $ref->{title},
            description => $ref->{description},
            pubDate     => $dt,
            url         => $ref->{link},
            id_target   => $id,
            user        => $user,
        };
        push(@$data, $h);
    }
    croak("error") if $errorcheck == 0;
    $data;
}

sub parser_atom {
    my $str    = shift;
    my $latest = shift;
    my $id     = shift;
    my $pcheck = shift;
    my $user   = shift;

    my $data;
    my $errorcheck = 0;

    my $lateststr = $latest->ymd('') . $latest->hms('');

    #Atomの場合
    my $atom    = XML::Atom::Feed->new(\$str);
    my @entries = $atom->entries;
    foreach my $item (@entries) {
        my $dt = from_feed_datetime($item->updated);

        #DBに格納されているエントリーより古い情報は
        #取り込まない設定の場合、次の情報を処理する
        my $dtstr = $dt->ymd('') . $dt->hms('');
        $errorcheck++;
        next if $pcheck == 0 and ($dtstr <= $lateststr);

        my $h = {
            guid        => $item->link->href,
            title       => decode('utf-8', $item->title),
            description => decode('utf-8', $item->summary),
            pubDate     => $dt,
            url         => $item->link->href,
            id_target   => $id,
            user        => $user,
        };
        push( @$data, $h );
    }
    croak("error") if $errorcheck == 0;
    $data;
}

1;
