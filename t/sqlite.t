use strict;
use warnings;

use DBI;
use File::Temp qw/tempfile/;
use Test::Class;
use Test::Class::Load qw(t/lib);
use File::Slurp;

use lib "lib/";
use Gion::Config;

$ENV{PLACK_ENV} = 'test';
our $config;

BEGIN {
    my (undef, $filename) = tempfile(UNLINK => 1);
    my $dsn = "dbi:SQLite:dbname=$filename";

    # load schema.
    my $dbh = DBI->connect($dsn);
    $dbh->do("PRAGMA foreign_keys = ON");
    my $source = read_file('sql/sqlite.sql');
    for my $stmt (split /;/, $source) {
        next unless $stmt =~ /\S/;
        $dbh->do($stmt) or die $dbh->errstr;
    }
    $config = config->local(db => { dsn => $dsn });
}

Test::Class->runtests;
