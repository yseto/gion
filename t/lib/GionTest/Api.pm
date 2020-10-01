package GionTest::Api;

use strict;
use warnings;
use utf8;
use parent qw(Test::Class);
use Test::More;

use Data::Section::Simple qw(get_data_section);
use Encode;
use HTML::Parser;
use Plack::Builder;
use Plack::Test;
use Plack::Util;
use Test::Mock::Guard qw/mock_guard/;
use Test::More;
use Test::TCP;
use Time::Piece;
use LWP::Protocol::PSGI;
use LWP::UserAgent;
use HTTP::CookieJar::LWP;
use HTTP::Request::Common;
use JSON::XS;

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
    for my $stmt (split /;/, join('', get_data_section('table'))) {
        next unless $stmt =~ /\S/;
        $dbh->do($stmt) or die $dbh->errstr;
    }

    LWP::Protocol::PSGI->register($app, host => 'localhost');

    my $jar = HTTP::CookieJar::LWP->new;
    my $ua = LWP::UserAgent->new(
        cookie_jar => $jar,
    );
    $self->{ua} = $ua;
    my %headers = (
        Origin             => 'http://localhost',
        'X-Requested-With' => 'XMLHttpRequest',
    );
    $self->{headers} = \%headers;
}

sub shutdown : Test(shutdown) {
    my $self = shift;
    my $dbh = $self->{dbh};

    foreach (qw/user category feed subscription entry story/) {
        diag("cleanup $_");
        $dbh->do("DELETE FROM `$_`");
    }
}

sub login : Test(setup => 1) {
    my $self = shift;
    my %headers = %{$self->{headers}};
    my $ua = $self->{ua};

    my $req = POST 'http://localhost/api/login',
        Content => [
            id => 'admin',
            password => 'password123456',
        ],
        %headers;

    my $res = $ua->request($req);
    is($res->code, 200);
}

sub examine_subscription : Test(3) {
    my $self = shift;
    my %headers = %{$self->{headers}};
    my $ua = $self->{ua};
    my $dbh = $self->{dbh};

    # sample web
    my $app = sub {
        my $env = shift;

        my $filename = $env->{PATH_INFO};
        $filename =~ s|/(.*)\.(.*)$|$1.$2|;
        my $doc = get_data_section($filename);
        unless ($doc) {
            return [ 404, [], []];
        }
        return [ 200, [
            'Content-Type' => 'text/html',
        ], [ encode_utf8($doc) ] ];
    };

    my $builder = Plack::Builder->new;
    my $server = Test::TCP->new(
        code => sub {
            my $port   = shift;
            my $server = Plack::Loader->auto(
                port => $port,
                host => '127.0.0.1',
            );
            $server->run($builder->to_app($app));
        },
    );

    my $port = $server->port;
    my $base = "http://127.0.0.1:$port/";

    subtest 'api - examine_subscription full', sub {
        my $guard = mock_guard "Net::DNS::Paranoid", +{
            resolve => sub { ["127.0.0.1"] },
        };

        my $req = POST 'http://localhost/api/examine_subscription',
            Content => [ url => "${base}index.html" ],
            %headers;

        my $res = $ua->request($req);
        my $object = decode_json $res->content;

        my $expected = [{
            'url' => 'http://example.com/0.html',
            'title' => 'title',
            'date' => '08/31 15:00'
        }];

        is $object->{title}, 'sample site';
        is_deeply $object->{preview_feed}, $expected;
        is $object->{url}, "${base}cat-live.xml";
    };

    subtest 'api - examine_subscription half', sub {
        my $guard = mock_guard "Net::DNS::Paranoid", +{
            resolve => sub { ["127.0.0.1"] },
        };

        my $req = POST 'http://localhost/api/examine_subscription',
            Content => [ url => "${base}index2.html" ],
            %headers;

        my $res = $ua->request($req);
        my $object = decode_json $res->content;

        is $object->{title}, 'alternative sample site';
        is_deeply $object->{preview_feed}, undef;
        is $object->{url}, undef;
    };

    subtest 'api - examine_subscription paranoid check', sub {
        my $req = POST 'http://localhost/api/examine_subscription',
            Content => [ url => "http://localhost/index.html" ],
            %headers;

        my $res = $ua->request($req);
        my $object = decode_json $res->content;

        is $object->{title}, '';
        is $object->{preview_feed}, undef;
        is $object->{url}, '';
    };
}

sub test_app : Test(12) {
    my $self = shift;
    my %headers = %{$self->{headers}};
    my $ua = $self->{ua};
    my $dbh = $self->{dbh};

    subtest 'api - register_category', sub {
        my $name = "category_" . time;
        my $req = POST 'http://localhost/api/register_category',
            Content => [ name => $name ],
            %headers;

        my $res1 = $ua->request($req);
        my $object1 = decode_json $res1->content;
        is $object1->{result}, 'OK';

        my $res2 = $ua->request($req);
        my $object2 = decode_json $res2->content;
        is $object2->{result}, 'ERROR_ALREADY_REGISTER';

        my ($name2) = $dbh->selectrow_array(
            "SELECT name FROM category WHERE name = '$name'"
        );
        is $name, $name2;

    };

    subtest 'api - register_subscription', sub {
        my ($id) = $dbh->selectrow_array(
            'SELECT id FROM category ORDER BY id DESC LIMIT 1'
        );

        my %site = (
            rss => 'http://www3.nhk.or.jp/rss/news/cat-live.xml',
            url => 'http://www.nhk.or.jp/news/',
            title => 'NHK NEWS',
            category => $id,
        );
        my $req = POST 'http://localhost/api/register_subscription',
            Content => [ %site ],
            %headers;

        my $res1 = $ua->request($req);
        my $object1 = decode_json $res1->content;
        is $object1->{result}, 'OK';

        my $res2 = $ua->request($req);
        my $object2 = decode_json $res2->content;
        is $object2->{result}, 'ERROR_ALREADY_REGISTER';

        my ($feed_id) = $dbh->selectrow_array(
            "SELECT feed_id FROM subscription WHERE category_id = $id ORDER BY id DESC LIMIT 1"
        );

        my ($rss, $url) = $dbh->selectrow_array(
            "SELECT url, siteurl FROM feed WHERE id = $feed_id"
        );

        is $rss, $site{rss};
        is $url, $site{url};
    };

    subtest 'api - delete_it entry', sub {
        my ($id) = $dbh->selectrow_array(
            'SELECT feed_id FROM subscription ORDER BY id DESC LIMIT 1'
        );

        my $req = POST 'http://localhost/api/delete_it',
            Content => [ subscription => 'entry', id => $id ],
            %headers;

        my $res = $ua->request($req);
        my $object = decode_json $res->content;
        is $object->{r}, 'OK';

        my ($count) = $dbh->selectrow_array(
            "SELECT COUNT(*) FROM subscription WHERE feed_id = $id"
        );

        is $count, 0;

    };

    subtest 'api - delete_it category', sub {
        my ($id) = $dbh->selectrow_array(
            'SELECT id FROM category ORDER BY id DESC LIMIT 1'
        );

        my $req = POST 'http://localhost/api/delete_it',
            Content => [ subscription => 'category', id => $id ],
            %headers;

        my $res = $ua->request($req);
        my $object = decode_json $res->content;
        is $object->{r}, 'OK';

        my ($count) = $dbh->selectrow_array(
            "SELECT COUNT(*) FROM category WHERE id = $id"
        );

        is $count, 0;

    };

    subtest 'api - change_it', sub {
        # prepare
        my $req1 = POST 'http://localhost/api/register_category',
            Content => [ name => 'category1' ],
            %headers;
        $ua->request($req1);

        my $req2 = POST 'http://localhost/api/register_category',
            Content => [ name => 'category2' ],
            %headers;
        $ua->request($req2);

        my ($category1) = $dbh->selectrow_array(
            "SELECT id FROM category WHERE name = 'category1'"
        );

        my ($category2) = $dbh->selectrow_array(
            "SELECT id FROM category WHERE name = 'category2'"
        );

        my %site = (
            rss => 'http://www3.nhk.or.jp/rss/news/cat-live.xml',
            url => 'http://www.nhk.or.jp/news/',
            title => 'NHK NEWS',
            category => $category1,
        );
        my $req3 = POST 'http://localhost/api/register_subscription',
            Content => [ %site ],
            %headers;
        $ua->request($req3);

        my ($feed_id) = $dbh->selectrow_array(
            "SELECT feed_id FROM subscription WHERE category_id = $category1"
        );

        my $req = POST 'http://localhost/api/change_it',
            Content => [ category => $category2, id => $feed_id, ],
            %headers;
        my $res = $ua->request($req);
        my $object = decode_json $res->content;
        is $object->{r}, 'OK';

        my ($category_id) = $dbh->selectrow_array(
            "SELECT category_id FROM subscription WHERE feed_id = $feed_id"
        );

        is $category_id, $category2;

    };

    subtest 'api - get/set numentry', sub {
        my $req1 = POST 'http://localhost/api/get_numentry',
            %headers;

        my $res1 = $ua->request($req1);
        my $object1 = decode_json $res1->content;

        $object1->{numentry} += 30;

        my $req2 = POST 'http://localhost/api/set_numentry',
            Content => [ %$object1 ],
            %headers;

        my $res2 = $ua->request($req2);
        my $mes = decode_json $res2->content;
        is $mes->{r}, 'OK';

        my $req3 = POST 'http://localhost/api/get_numentry',
            %headers;

        my $res3 = $ua->request($req3);
        my $object2 = decode_json $res3->content;

        is_deeply $object1, $object2;
    };

    subtest 'api - update_password - unmatch now', sub {
        my $req = POST 'http://localhost/api/update_password',
            Content => [
                password_old => 'password12345',
                password => 'password12345678',
                passwordc => 'password12345678',
            ],
            %headers;

        my $res = $ua->request($req);
        my $object = decode_json $res->content;
        is $object->{result}, 'unmatch now password';
    };

    subtest 'api - update_password - unmatch dup', sub {
        my $req = POST 'http://localhost/api/update_password',
            Content => [
                password_old => 'password123456',
                password => 'password1234567',
                passwordc => 'password12345678',
            ],
            %headers;

        my $res = $ua->request($req);
        my $object = decode_json $res->content;
        is $object->{result}, 'error';

    };

    subtest 'api - update_password - success', sub {
        my $req = POST 'http://localhost/api/update_password',
            Content => [
                password_old => 'password123456',
                password => 'password12345678',
                passwordc => 'password12345678',
            ],
            %headers;

        my $res = $ua->request($req);
        my $object = decode_json $res->content;
        is $object->{result}, 'update password';
    };

}

1;

__DATA__

@@ table
INSERT INTO user (id, digest, name) VALUES (1, '$2a$10$cpg9xi4e.kfxmcHlbBahEOcG.U18tuB4jGUXN8fQIaUcg./9T0jWu', 'admin');

@@ index.html
<html>
<head>
<meta charset="utf-8" />

<title>sample site</title>
<link rel="alternate" type="application/rss+xml" title="sample feed" href="/cat-live.xml" />
</head>
<body>
</body>
</html>

@@ index2.html
<html>
<head>
<meta charset="utf-8" />

<title>alternative sample site</title>
<link rel="alternate" type="application/rss+xml" title="alternative sample feed" href="/cat-live2.xml" />
</head>
<body>
</body>
</html>

@@ cat-live.xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
<channel>
<title>sample</title>
<item>
<link>http://example.com/0.html</link>
<title>title</title>
<pubDate>Tue, 01 Sep 2020 00:00:00 +0900</pubDate>
<description>sample</description>
<guid isPermaLink="false">http://example.com/0.html</guid>
</item>
</channel>
</rss>
