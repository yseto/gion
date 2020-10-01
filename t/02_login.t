use strict;
use warnings;

use lib "t/";
use testenv;

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
use Gion::Config;
use Gion::Model::User;

my $dbh = dbh();
my $guard = config->local(test_config());

my $app = Plack::Util::load_psgi('app.psgi');
LWP::Protocol::PSGI->register($app, host => 'localhost');

for my $stmt (split /;/, join('', <DATA>)) {
    next unless $stmt =~ /\S/;
    $dbh->do($stmt) or die $dbh->errstr;
}

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

my $ua = LWP::UserAgent->new;
my $res = $ua->request($req);
my $cookie = $res->header("Set-Cookie");
ok(defined $cookie);
my $object = decode_json $res->content;
is $object->{authorization}, JSON::true;

$mech->content_contains('/gion.js', 'check javascript');
$mech->get_ok('/api/logout', 'logout ok');

done_testing;

__DATA__
INSERT INTO user (id, digest, name) VALUES (null, '$2a$10$cpg9xi4e.kfxmcHlbBahEOcG.U18tuB4jGUXN8fQIaUcg./9T0jWu', 'admin');

