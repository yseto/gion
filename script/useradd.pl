#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature q(say);

use Getopt::Long qw(GetOptionsFromArray :config posix_default no_ignore_case gnu_compat);

use lib 'lib/';
use Gion::DB;
use Gion::Model::User;

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

my $model = Gion::Model::User->new;
my $digest = $model->generate_secret_digest($data{password});

my %sql = (
    force => 'UPDATE user SET digest = ? WHERE name = ?',
    normal => 'INSERT INTO user (id, digest, name) VALUES (null, ?, ?)',
);

my $mode = defined $data{force} ? 'force' : 'normal';
my $db = Gion::DB->new;
$db->query($sql{$mode}, $digest, $data{user} );

my $user_id = $db->last_insert_id;

$db->query("INSERT INTO category (id,user_id,name) VALUES (null,?,?)",
    $user_id,
    'default',
);

say "Apply: " . $data{user};

=encoding utf8

=head1 NAME

useradd - add user script.

=cut

