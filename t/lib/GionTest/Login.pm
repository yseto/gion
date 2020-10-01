package GionTest::Login;

use strict;
use warnings;
use utf8;
use parent qw(Test::Class);
use Test::More;

use HTTP::Request;
use HTTP::Request::Common;
use JSON;
use JSON::XS;
use LWP::Protocol::PSGI;
use Plack::Test;
use Plack::Util;
use Test::More;
use Test::WWW::Mechanize::PSGI;

use lib "lib/";
use Gion::DB;
use Gion::Config;
use Gion::Model::User;

sub setup : Test(startup) {
    my $self = shift;
    $self->{dbh} = Gion::DB->new;
    my $app = Plack::Util::load_psgi('app.psgi');
    $self->{app} = $app;

    my $dbh = $self->{dbh};

    for my $stmt (split /;/, join('', <DATA>)) {
        next unless $stmt =~ /\S/;
        $dbh->do($stmt) or die $dbh->errstr;
    }
    LWP::Protocol::PSGI->register($app, host => 'localhost');
    my $ua = LWP::UserAgent->new;
    $self->{ua} = $ua;
}

sub shutdown : Test(shutdown) {
    my $self = shift;
    my $dbh = $self->{dbh};

    foreach (qw/user category feed subscription entry story/) {
        diag("cleanup $_");
        $dbh->do("DELETE FROM `$_`");
    }
}

sub login : Test(5) {
    my $self = shift;
    my $app = $self->{app};
    my $ua = $self->{ua};

    my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

    $mech->get_ok('/');

    my %headers = (
        'X-Requested-With' => 'XMLHttpRequest',
    );
    
    my $req = POST 'http://localhost/api/login',
        Content => [
            id => 'admin',
            password => 'password123456',
        ],
        %headers;
    
    my $res = $ua->request($req);
    my $cookie = $res->header("Set-Cookie");
    ok(defined $cookie);
    my $object = decode_json $res->content;
    is $object->{authorization}, JSON::true;
    
    $mech->content_contains('/gion.js', 'check javascript');
    $mech->get_ok('/api/logout', 'logout ok');
}

1;

__DATA__
INSERT INTO user (id, digest, name) VALUES (1, '$2a$10$cpg9xi4e.kfxmcHlbBahEOcG.U18tuB4jGUXN8fQIaUcg./9T0jWu', 'admin');

