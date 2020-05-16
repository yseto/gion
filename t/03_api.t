use strict;
use warnings;

use lib "t/";
use testenv;

use HTML::Parser;
use Plack::Test;
use Plack::Util;
use Test::More;
use Time::Piece;
use File::Slurp;
use LWP::Protocol::PSGI;
use LWP::UserAgent;
use HTTP::CookieJar::LWP;
use HTTP::Request::Common;
use JSON::XS;

use lib "lib/";
use Gion::Util;
use Gion::Config;

my $dbh = dbh();
my $guard = config->local(test_config());

my $app = Plack::Util::load_psgi('app.psgi');

# generate user account.
my $auth = Gion::Util::auth(
    salt => config->param('salt'),
    strech => config->param('strech'),
    id => 'admin',
    password => 'password123456',
);

# register user.
$dbh->do("INSERT INTO user (id, password, name) VALUES (null, '$auth', 'admin')");

LWP::Protocol::PSGI->register($app, host => 'localhost');

my $jar = HTTP::CookieJar::LWP->new;
my $ua = LWP::UserAgent->new(
    cookie_jar => $jar,
);

my %headers = (
    Origin             => 'http://localhost',
    'X-Requested-With' => 'XMLHttpRequest',
);

subtest 'login', sub {
    my $req = POST 'http://localhost/api/login',
        Content => [
            id => 'admin',
            password => 'password123456',
        ],
        %headers;
    
    my $res = $ua->request($req);
    is($res->code, 200);
};

subtest 'api - examine_subscription', sub {
    my $req = POST 'http://localhost/api/examine_subscription',
        Content => [ url => 'http://www.nhk.or.jp/news/' ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;
    
    like $object->{title}, qr/NHK/;
    is $object->{url}, 'http://www3.nhk.or.jp/rss/news/cat-live.xml';
};

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

done_testing;

__END__

