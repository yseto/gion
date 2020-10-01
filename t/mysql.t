use strict;
use warnings;

use Test::Class;
use Test::Class::Load qw(t/lib);
use Test::mysqld;
use File::Slurp;

use lib "lib/";
use Gion::Config;

$ENV{PLACK_ENV} = 'test';
our $mysqld;
our $config;

BEGIN {
    # boot mysqld
    our $mysqld = Test::mysqld->new(
        my_cnf => {
            'skip-networking' => '', # no TCP socket
        },
    );
    
    # load schema.
    my $dbh = DBI->connect($mysqld->dsn);
    my $source = read_file('sql/mysql.sql');
    for my $stmt (split /;/, $source) {
        next if $stmt =~ /use gion/;
        next unless $stmt =~ /\S/;
        $dbh->do($stmt) or die $dbh->errstr;
    }
    $config = config->local(db => { dsn => $mysqld->dsn });
}

Test::Class->runtests;
