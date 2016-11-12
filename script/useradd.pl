#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature q(say);

use Getopt::Long qw(GetOptionsFromArray :config posix_default no_ignore_case gnu_compat);

use lib 'lib/';
use Gion;
use Gion::Config;
use Gion::Util;

my %data;
GetOptionsFromArray(\@ARGV,
    "user=s" => \$data{user},
    "password=s" => \$data{password},
    "overwrite" => \$data{force},
);

unless (defined $data{user} || defined $data{password}) {
    say "need parameter: --user ID --password Password";
    exit();
}

my $auth = Gion::Util->auth(
    salt => config->param('salt'),
    strech => config->param('strech'),
    id => $data{user},
    password => $data{password},
);

my %sql = (
    force => 'UPDATE user SET password = ? WHERE name = ?',
    normal => 'INSERT INTO user (id,password,name) VALUES (null,?,?)',
);

my $mode = defined $data{force} ? 'force' : 'normal';
my $db = Gion->cli_dbh;
$db->dbh->query($sql{$mode}, $auth, $data{user} );

say "Apply: " . $data{user};

=encoding utf8

=head1 NAME

useradd - add user script.

=cut

