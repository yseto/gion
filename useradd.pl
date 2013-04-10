#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use v5.10;
use FindBin;
use File::Spec;
use DBIx::Simple;
use Getopt::Std;
use lib "$FindBin::Bin/lib";
use Gion::Plugin::Auth;

#起動オプション
my %opts = ();
getopts( "i:p:", \%opts );

#-i、-pが無ければヘルプを表示して終了する
unless ( defined $opts{i} || defined $opts{p} ) {
    say "-i ID -p Password";
    exit();
}

#設定ファイルを読み込む
my $cfg = eval slurp( File::Spec->catfile( $FindBin::Bin, "gion.conf" ) );

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

#認証のモジュールはWebと共通で使う（もう少し何とかならなかったのか...）
$Gion::Plugin::Auth::FIXEDSALT = $cfg->{salt};
my $pw = Gion::Plugin::Auth::get_password_hash( $opts{i}, $opts{p} );

#ユーザーを追加する
$db->query( 'INSERT INTO user (id,pw,name) VALUES (null,?,?);', $pw, $opts{i} );

say "User Added... " . $opts{i};

sub slurp {
    my $path = shift;
    open my $file, '<', $path;
    my $content = '';
    while ( $file->sysread( my $buffer, 131072, 0 ) ) { $content .= $buffer }
    return $content;
}

