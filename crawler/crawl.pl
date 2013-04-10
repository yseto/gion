#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Cache::File;
use URI::Fetch;
use URI;
use Try::Tiny;
use FindBin;
use File::Spec;
use Encode;
use DBIx::Simple;
use DateTime;
use DateTime::Format::MySQL;
use DateTime::Format::Mail;
use DateTime::Format::W3CDTF;
use DateTime::Format::ISO8601;
use Getopt::Std;
use Term::ProgressBar;
use Time::HiRes qw(sleep);
use LWP::UserAgent;
use XML::RSS::LibXML;
use XML::Atom::Feed;

#起動オプション
my %opts = ();
getopts( "e:h", \%opts );

#-hであればヘルプ？を表示して終了する
if ( defined $opts{h} ) {
    print "-e ID	Get specify entry\n";
    print "-h	This Help\n";
    exit();
}

#設定ファイルを読み込む
my $cfg = eval slurp( File::Spec->catfile( $FindBin::Bin, "..", "gion.conf" ) );

#データベース接続
my $db = DBIx::Simple->connect(
    'dbi:mysql:host='
      . $cfg->{db}->{hostname}
      . ';database='
      . $cfg->{db}->{database} . ';',
    $cfg->{db}->{username},
    $cfg->{db}->{password},
    { RaiseError => 1, mysql_enable_utf8 => 1 }
) or die DBIx::Simple->error;

#キャッシュ定義
my $cache = Cache::File->new( cache_root => $cfg->{crawler}->{cache} );

#クロールする情報を取得
my $rs;
if ( defined $opts{e} ) {
    $rs = $db->query( 'SELECT * FROM target WHERE id = ?', $opts{e} );
}
else {
    $rs = $db->query('SELECT * FROM target;');
}

#タイムアウトを定義
my $ua = new LWP::UserAgent;
$ua->timeout( $cfg->{crawler}->{timeout} );
$ua->agent( $cfg->{crawler}->{ua} );

#プログレスバーを定義
my $prog = Term::ProgressBar->new(
    {
        count => $rs->rows,
    }
);
$prog->max_update_rate(1);
my $progcount = 0;

foreach my $c ( $rs->hashes ) {

    #一定時間ごとに動作するためにスリープする
    sleep( $cfg->{crawler}->{sleep} );

    #プログレスバーの件数更新
    $progcount++;

    #取得する
    my $res = URI::Fetch->fetch( $c->{url}, Cache => $cache, UserAgent => $ua );

    #結果が得られない場合、次の対象を処理する
    unless ( defined $res ) {
        $db->query( 'UPDATE target SET http_status = ? WHERE id = ?;',
            404, $c->{id} );
        $prog->message( sprintf "404 %4d %s",
            $c->{id}, encode_utf8( $c->{title} ) );
        $prog->update($progcount);
        next;
    }

    #プログレスバー更新
    $prog->message( sprintf "%3d %4d %s",
        $res->http_status, $c->{id}, encode_utf8( $c->{title} ) );
    $prog->update($progcount);

    #取得できたので、リターンコードを更新する。
    $db->query( 'UPDATE target SET http_status = ? WHERE id = ?;',
        $res->http_status, $c->{id} );

    # 304 Not Modifiedの場合更新しない場合次の対象を処理する
    next if $cfg->{crawler}->{no304} == 0 and $res->http_status == 304;

    my $str = $res->content;
    my $id  = $c->{id};

 #クロール対象のエントリーの最新の情報の日付を取得する
    my $rspd = $db->query(
"SELECT pubDate FROM entries WHERE _id_target = ? ORDER BY pubDate DESC LIMIT 1;",
        $id
    );
    my $haspd = $rspd->hash;

    #最新の日付があれば、活用する。なければ2000年とする
    my $latest = DateTime->new( year => 2000, month => 1, day => 1 );
    $latest = DateTime::Format::MySQL->parse_datetime( $haspd->{pubdate} )
      if defined $haspd;

    my $errorcount = 0;

    #最初にRSSとして解析を行い、失敗したら
    #Atomとして認識する
    #（すごい汚い作り。作り直したい）
    try {
        #RSSの場合
        my $rss = new XML::RSS::LibXML;
        $rss->parse($str);
        foreach my $ref ( @{ $rss->{items} } ) {

            my $dt    = DateTime->now()->set_time_zone('Asia/Tokyo');
            my $ns_dc = "http://purl.org/dc/elements/1.1/";

            if ( defined $ref->{pubDate} ) {

              #時刻が定義されていたら、それを利用する RSS 2.0
                $dt = DateTime::Format::Mail->parse_datetime( $ref->{pubDate} );
                $dt->set_time_zone('Asia/Tokyo');
            }
            elsif ( defined $ref->{$ns_dc}->{date} ) {

              #時刻が定義されていたら、それを利用する RSS 1.0
                $dt = DateTime::Format::W3CDTF->parse_datetime(
                    $ref->{$ns_dc}->{date} );
            }

            #DBに格納されているエントリーより古い情報は
            #取り込まない設定の場合、次の情報を処理する
            next if $cfg->{crawler}->{pubDatecheck} == 0 and ( $dt < $latest );

            entry_insert_db( $ref->{guid}, $ref->{title},
                $ref->{description}, $dt, $ref->{link}, $id );
        }
    }
    catch {
        $errorcount++;
    };

    try {
        #RSSの場合は、$errorcountには0が入って
        #いるため、Atomの処理を試みない
        return 1 if $errorcount == 0;

        #Atomの場合
        my $atom    = XML::Atom::Feed->new( \$str );
        my @entries = $atom->entries;
        foreach my $item (@entries) {
            my $dt =
              DateTime::Format::ISO8601->parse_datetime( $item->updated );

            #DBに格納されているエントリーより古い情報は
            #取り込まない設定の場合、次の情報を処理する
            next if $cfg->{crawler}->{pubDatecheck} == 0 and ( $dt < $latest );

            entry_insert_db(
                $item->link->href,
                decode( 'utf-8', $item->title ),
                decode( 'utf-8', $item->summary ),
                $dt, '', $id
            );
        }
    }
    catch {
        $errorcount++;
    };

    #RSSおよびAtomの解析処理が失敗したら、
    #クロール対象レコードのhttp_statusに-1を入れる
    $db->query( 'UPDATE target SET http_status = ? WHERE id = ?;',
        -1, $c->{id} )
      if $errorcount == 2;
}

sub entry_insert_db {

    my ( $guid, $title, $description, $pubDate, $url, $id_target ) = @_;

    my $tf = DateTime::Format::MySQL->format_datetime($pubDate);

    my $r_guid;
    my $r_url;

    if ( not defined $guid ) {

        #guidがない場合は、URLを代用
        $r_guid = $url;
        $r_url  = $url;
    }
    elsif ( not defined $url ) {

        #URLがない場合は、GUIDを代用
        $r_guid = $guid;
        $r_url  = $guid;
    }
    else {

        #通常
        $r_guid = $guid;
        $r_url  = $url;
    }

    unless ( $r_url =~ /^http/ ) {
        my $rsuri =
          $db->query( 'SELECT url FROM target WHERE id = ?', $id_target )->hash;

        my $newurl = "" . URI->new_abs( $r_url, $rsuri->{url} );
        $r_url = $newurl;
    }

    $rs = $db->query(
        "INSERT IGNORE INTO `entries`
 (`guid`, `title`, `description`, `pubDate`, `url`, `readflag`, `_id_target`)
VALUES ( ?, ?, ?, ?, ?, 0, ? );",
        encode( 'utf-8', $r_guid ),
        encode( 'utf-8', $title ),
        encode( 'utf-8', $description ),
        $tf,
        encode( 'utf-8', $r_url ),
        $id_target
    );

}

sub slurp {
    my $path = shift;
    open my $file, '<', $path;
    my $content = '';
    while ( $file->sysread( my $buffer, 131072, 0 ) ) { $content .= $buffer }
    return $content;
}

