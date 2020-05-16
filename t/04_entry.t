use strict;
use warnings;

use lib "t/";
use testenv;

use HTML::Parser;
use Plack::Test;
use Plack::Util;
use Test::More;
use Test::WWW::Mechanize::PSGI;
use Time::Piece;
use File::Slurp;
use LWP::Protocol::PSGI;
use LWP::UserAgent;
use HTTP::CookieJar::LWP;
use HTTP::Request::Common;
use JSON;
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

for my $stmt (split /;/, join('', <DATA>)) {
    next unless $stmt =~ /\S/;
    $dbh->do($stmt) or die $dbh->errstr;
}

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

subtest 'api - get/set numentry', sub {
    my $req1 = POST 'http://localhost/api/get_numentry',
        %headers;
    
    my $res1 = $ua->request($req1);
    my $object1 = decode_json $res1->content;

    $object1->{numentry} = 3;

    my $req2 = POST 'http://localhost/api/set_numentry',
        Content => [ %$object1 ],
        %headers;

    my $res2 = $ua->request($req2);
    my $mes = decode_json $res2->content;
    is $mes->{r}, 'OK';
};

subtest 'api - get_category', sub {
    my $req = POST 'http://localhost/api/get_category',
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    is ref($object), 'ARRAY';
    is scalar(@$object), 2;
    is @$object[0]->{name}, 'category1';
    is @$object[0]->{count}, 4;
    is @$object[0]->{id}, 1;
};

subtest 'api - get_entry / specify category', sub {
    my $req = POST 'http://localhost/api/get_entry',
        Content => [ category => 2 ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    my $expect = [
        {
            'date_epoch' => 1500944515,
            'description' => 'test11',
            'raw_url' => 'http://www.example.com/10011072971000.html',
            'readflag' => 0,
            'site_title' => 'test feed',
            'title' => 'title - test11',
            'url' => 'http://www.example.com/10011072971000.html',
            'feed_id' => 23,
            'serial' => 11,
        },
        {
            'date_epoch' => 1500944505,
            'description' => 'test10',
            'raw_url' => 'http://www.example.com/10011072961000.html',
            'readflag' => 0,
            'site_title' => 'test feed',
            'title' => 'title - test10',
            'url' => 'http://www.example.com/10011072961000.html',
            'feed_id' => 23,
            'serial' => 10,
        },
        {
            'date_epoch' => 1500944500,
            'description' => 'test09',
            'raw_url' => 'http://www.example.com/10011072911000.html',
            'readflag' => 0,
            'site_title' => 'test feed',
            'title' => 'title - test09',
            'url' => 'http://www.example.com/10011072911000.html',
            'feed_id' => 23,
            'serial' => 9,
        }
    ];
    is_deeply $object, $expect;
};

subtest 'api - get_entry / set_asread', sub {
    my $json = encode_json([
        {
            feed_id => 23,
            serial  => 9,
        },
        {
            feed_id => 23,
            serial => 10,
        },
        {
            feed_id => 23,
            serial => 11,
        },
    ]);

    my $req = POST 'http://localhost/api/set_asread',
        Content => $json,
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;
    is $object->{result}, JSON::true;
};

subtest 'api - get_entry / specify category after set_asread', sub {
    my $req = POST 'http://localhost/api/get_entry',
        Content => [ category => 2 ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    is scalar(@$object), 2;
    my @result = sort map {
        {
            subscription_id => $_->{subscription_id},
            serial => $_->{serial},
        }
    } @$object;

    my @payload = (
        {
            feed_id => 23,
            serial  => 7,
        },
        {
            feed_id => 23,
            serial  => 8,
        },
    );

    eq_set \@result, \@payload;

    my $json = encode_json(\@payload);
    my $req_read = POST 'http://localhost/api/set_asread',
        Content => $json,
        %headers;
    
    my $res_read = $ua->request($req_read);
    my $object = decode_json $res_read->content;
    is $object->{result}, JSON::true;
};

subtest 'api - get_entry / specify category nothing entries', sub {
    my $req = POST 'http://localhost/api/get_entry',
        Content => [ category => 2 ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    is scalar(@$object), 0;
};

subtest 'api - set_pin', sub {
    my $req = POST 'http://localhost/api/set_pin',
        Content => [
            feed_id => 22,
            serial  => 5,

            readflag => 1,
        ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    is $object->{readflag}, 2;
};

subtest 'api - get_pinlist', sub {
    my $req = POST 'http://localhost/api/get_pinlist',
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    my $time = delete @$object[0]->{update_at}; # XXX
    is_deeply $object, [{
        'feed_id' => 22,
        'serial' => 5,
        'title' => 'title - test05',
        'url' => 'http://www.example.com/10011072851000.html'
    }];
};

subtest 'api - remove_all_pin', sub {
    my $req = POST 'http://localhost/api/remove_all_pin',
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;
    is $object->{result}, JSON::true;
};

subtest 'api - get_subscription', sub {
    my $req = POST 'http://localhost/api/get_subscription',
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    is_deeply $object->{category}, [
        {
            'id' => 1,
            'name' => 'category1'
        },
        {
            'id' => 2,
            'name' => 'category2'
        }
    ];

    is_deeply $object->{subscription}, [
        {
            'category_id' => 1,
            'http_status' => '200',
            'id' => 22,
            'siteurl' => 'http://www.example.com/',
            'title' => 'test feed'
        },
        {
            'category_id' => 2,
            'http_status' => '200',
            'id' => 23,
            'siteurl' => 'http://www.example.com/',
            'title' => 'test feed'
        }
    ];

};

done_testing;

__DATA__

LOCK TABLES `category` WRITE;
INSERT INTO `category` VALUES
(1,1,'category1'),
(2,1,'category2')
;
UNLOCK TABLES;

LOCK TABLES `feed` WRITE;
INSERT INTO `feed` VALUES 
(22,'http://www.example.com/feed.xml','http://www.example.com/','test feed','2017-01-01 12:34:56','200','1','2017-07-30 00:00:00','1','{}', 0),
(23,'http://www.example.com/feed2.xml','http://www.example.com/','test feed','2017-01-01 12:34:56','200','1','2017-07-30 00:00:00','1','{}', 0)
;
UNLOCK TABLES;

LOCK TABLES `subscription` WRITE;
INSERT INTO `subscription` VALUES
(110,1,22,1),
(111,2,23,1)
;
UNLOCK TABLES;

LOCK TABLES `entry` WRITE;
INSERT INTO `entry` VALUES 
(1, '2017-07-24 22:22:22','2017-07-24 22:30:01',1,110,22,1),
(2, '2017-07-25 01:01:00','2017-07-25 01:15:01',0,110,22,1),
(3, '2017-07-25 01:01:10','2017-07-25 01:15:01',0,110,22,1),
(4, '2017-07-25 01:01:15','2017-07-25 01:15:01',0,110,22,1),
(5, '2017-07-25 01:01:20','2017-07-25 01:15:01',0,110,22,1),
(6, '2017-07-24 01:01:25','2017-07-25 01:15:01',1,111,23,1),
(7, '2017-07-25 01:01:30','2017-07-25 01:15:01',0,111,23,1),
(8, '2017-07-25 01:01:35','2017-07-25 01:15:01',0,111,23,1),
(9, '2017-07-25 01:01:40','2017-07-25 01:15:01',0,111,23,1),
(10,'2017-07-25 01:01:45','2017-07-25 01:15:01',0,111,23,1),
(11,'2017-07-25 01:01:55','2017-07-25 01:15:01',0,111,23,1)
;
UNLOCK TABLES;

LOCK TABLES `story` WRITE;
INSERT INTO `story` VALUES 
(22,1, 'title - test01','test01','http://www.example.com/10011072671000.html'),
(22,2, 'title - test02','test02','http://www.example.com/10011072731000.html'),
(22,3, 'title - test03','test03','http://www.example.com/10011072771000.html'),
(22,4, 'title - test04','test04','http://www.example.com/10011072821000.html'),
(22,5, 'title - test05','test05','http://www.example.com/10011072851000.html'),
(23,6, 'title - test06','test06','http://www.example.com/10011072871000.html'),
(23,7, 'title - test07','test07','http://www.example.com/10011072881000.html'),
(23,8, 'title - test08','test08','http://www.example.com/10011072901000.html'),
(23,9, 'title - test09','test09','http://www.example.com/10011072911000.html'),
(23,10,'title - test10','test10','http://www.example.com/10011072961000.html'),
(23,11,'title - test11','test11','http://www.example.com/10011072971000.html')
;
UNLOCK TABLES;

