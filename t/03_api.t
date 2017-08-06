use strict;
use warnings;

use HTML::Parser;
use Plack::Test;
use Plack::Util;
use Test::More;
use Test::mysqld;
use Test::WWW::Mechanize::PSGI;
use Time::Piece;
use File::Slurp;
use LWP::Protocol::PSGI;
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON::XS;

use Gion::Util;
use Gion::Config;

$ENV{PLACK_ENV} = 'test';

my $mysqld = Test::mysqld->new;
my $dsn = $mysqld->dsn;

my $guard = config->local(db => {dsn => $dsn}); 

my $app = Plack::Util::load_psgi('app.psgi');

# load schema.
my $dbh = DBI->connect($dsn);
my $source = read_file('config/mysql.sql');
for my $stmt (split /;/, $source) {
    next unless $stmt =~ /\S/;
    $dbh->do($stmt) or die $dbh->errstr;
}

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

my $page;
my $cookie;

subtest 'login', sub {
    my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);
    
    $mech->get_ok('/');
    $mech->content_contains('Please sign in');
    $mech->submit_form_ok({
        form_number => 1,
        fields => {
            id => 'admin',
            password => 'password123456',
        }
    }, 'login form');
    
    $mech->content_contains('/static/gion.js', 'check javascript');
    $cookie = $mech->cookie_jar;
    $page = $mech->content;
    isnt($page, ''); # XXX
};

my $csrf_token;

subtest 'get csrf_token', sub {
    HTML::Parser->new(start_h => [
        sub {
            my($self, $tag, $attr) = @_;
            if ($tag eq 'meta' and defined $attr->{name} and $attr->{name} eq 'csrf-token') {
                $csrf_token = $attr->{content};
            }
        },
        'self,tagname,attr'
    ])->parse($page);
    isnt($csrf_token, ''); # XXX
};

my $ua = LWP::UserAgent->new;
$ua->cookie_jar($cookie);

my %headers = (
    'X-Requested-With' => 'XMLHttpRequest',
    'X-CSRF-Token' => $csrf_token,
);

subtest 'api - examine_target', sub {
    my $req = POST 'http://localhost/api/examine_target',
        Content => [ url => 'http://www.nhk.or.jp/news/' ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;
    
    like $object->{t}, qr/NHK/;
    is $object->{u}, 'http://www3.nhk.or.jp/rss/news/cat-live.xml';
};

subtest 'api - register_category', sub {
    my $name = "category_" . time;
    my $req = POST 'http://localhost/api/register_category',
        Content => [ name => $name ],
        %headers;
    
    my $res1 = $ua->request($req);
    my $object1 = decode_json $res1->content;
    is $object1->{r}, 'OK';

    my $res2 = $ua->request($req);
    my $object2 = decode_json $res2->content;
    is $object2->{r}, 'ERROR_ALREADY_REGISTER';

    my ($name2) = $dbh->selectrow_array(
        "SELECT name FROM category WHERE name = '$name'"
    );
    is $name, $name2;
    
};

subtest 'api - register_target', sub {
    my ($id) = $dbh->selectrow_array(
        'SELECT id FROM category ORDER BY id DESC LIMIT 1'
    );

    my %site = (
        rss => 'http://www3.nhk.or.jp/rss/news/cat-live.xml',
        url => 'http://www.nhk.or.jp/news/',
        title => 'NHK NEWS',
        category => $id,
    );
    my $req = POST 'http://localhost/api/register_target',
        Content => [ %site ],
        %headers;
    
    my $res1 = $ua->request($req);
    my $object1 = decode_json $res1->content;
    is $object1->{r}, 'OK';

    my $res2 = $ua->request($req);
    my $object2 = decode_json $res2->content;
    is $object2->{r}, 'ERROR_ALREADY_REGISTER';

    my ($feed_id) = $dbh->selectrow_array(
        "SELECT feed_id FROM target WHERE category_id = $id ORDER BY id DESC LIMIT 1"
    );

    my ($rss, $url) = $dbh->selectrow_array(
        "SELECT url, siteurl FROM feed WHERE id = $feed_id"
    );

    is $rss, $site{rss};
    is $url, $site{url};
};

subtest 'api - delete_it entry', sub {
    my ($id) = $dbh->selectrow_array(
        'SELECT feed_id FROM target ORDER BY id DESC LIMIT 1'
    );

    my $req = POST 'http://localhost/api/delete_it',
        Content => [ target => 'entry', id => $id ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;
    is $object->{r}, 'OK';

    my ($count) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM target WHERE feed_id = $id"
    );

    is $count, 0;

};

subtest 'api - delete_it category', sub {
    my ($id) = $dbh->selectrow_array(
        'SELECT id FROM category ORDER BY id DESC LIMIT 1'
    );

    my $req = POST 'http://localhost/api/delete_it',
        Content => [ target => 'category', id => $id ],
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
    my $req3 = POST 'http://localhost/api/register_target',
        Content => [ %site ],
        %headers;
    $ua->request($req3);

    my ($feed_id) = $dbh->selectrow_array(
        "SELECT feed_id FROM target WHERE category_id = $category1"
    );

    my $req = POST 'http://localhost/api/change_it',
        Content => [ category => $category2, id => $feed_id, ],
        %headers;
    my $res = $ua->request($req);
    my $object = decode_json $res->content;
    is $object->{r}, 'OK';

    my ($category_id) = $dbh->selectrow_array(
        "SELECT category_id FROM target WHERE feed_id = $feed_id"
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

# TODO
# get_connect
# set_connect

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
    is $object->{e}, 'unmatch now password';
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
    is $object->{e}, 'error';

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
    is $object->{e}, 'update password';
};

subtest 'api - create_user', sub {
    my $req = POST 'http://localhost/api/create_user',
        Content => [
            username => 'user1',
            password => 'password',
        ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;
    is $object->{e}, 'User Added: user1';
};

# TODO
# get_category
# get_entry
# set_asread
# get_targetlist
# get_pinlist
# set_pin
# remove_all_pin

done_testing;

__END__

