#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use DBIx::Simple;

my $cfg = eval slurp( File::Spec->catfile( $FindBin::Bin, "..", "gion.conf" ) );

#データベース定義と接続
my $db = DBIx::Simple->connect(
    'dbi:mysql:host='
      . $cfg->{db}->{hostname}
      . ';database='
      . $cfg->{db}->{database} . ';',
    $cfg->{db}->{username},
    $cfg->{db}->{password},
    { RaiseError => 1 }
) or die DBIx::Simple->error;

#
# 既読のものを削除する。
# ただし、最新の既読エントリは残しておく必要がある
# （そこを目印に、RSSの読み取りが行われるため）
#

my $rs = $db->query('SELECT id FROM target;') or die $db->error;

#
#  http://stackoverflow.com/questions/8886026/mysql-delete-all-but-latest-x-records
#

foreach my $c ( $rs->hashes ) {
    my $id = $c->{id};
    $db->query( "
DELETE FROM entries
	WHERE _id_target = ? AND 
	readflag = 1 AND 
	pubdate NOT IN ( SELECT pubdate 
		FROM 
		(SELECT pubdate FROM entries
			WHERE _id_target = ? AND
			readflag = 1
			ORDER BY pubdate DESC LIMIT 1
		) x
	);"
        , $id, $id ) or die $db->error;

    print $id . "\n";
}

$db->query('OPTIMIZE TABLE entries;');


sub slurp {
    my $path = shift;
    open my $file, '<', $path;
    my $content = '';
    while ( $file->sysread( my $buffer, 131072, 0 ) ) { $content .= $buffer }
    return $content;
}

