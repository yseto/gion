package testenv;
use strict;
use warnings;
use utf8;

use File::Slurp;
use Test::TCP;
use Test::mysqld;

our $mysqld;

sub import {
    my $pkg = caller(0);

    $ENV{PLACK_ENV} = 'test';

    # boot mysqld
    $mysqld = Test::mysqld->new(
        my_cnf => {
            'skip-networking' => '', # no TCP socket
        },
    );
    my $dsn = $mysqld->dsn;

    # load schema.
    my $dbh = DBI->connect($dsn);
    my $source = read_file('sql/mysql.sql');
    for my $stmt (split /;/, $source) {
        next if $stmt =~ /use gion/;
        next unless $stmt =~ /\S/;
        $dbh->do($stmt) or die $dbh->errstr;
    }

    no strict 'refs';
    *{ $pkg . "::dbh" } = sub { $dbh };
    *{ $pkg . "::test_config" } = sub {
        return (
            db      => {
                dsn => $dsn
            },
        );
    };
}

1;
