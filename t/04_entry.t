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

for my $stmt (split /;/, join('', <DATA>)) {
    next unless $stmt =~ /\S/;
    $dbh->do($stmt) or die $dbh->errstr;
}

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

subtest 'api - get_entry / default_category', sub {
    my $req = POST 'http://localhost/api/get_entry',
        Content => [ category => 0 ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    is_deeply $object, {
        'entry' => [
            {
                'date' => '07/25 01:01',
                'description' => 'test05',
                'guid' => 'http://www.example.com/10011072851000.html',
                'raw_url' => 'http://www.example.com/10011072851000.html',
                'readflag' => 0,
                'site_title' => 'test feed',
                'title' => 'title - test05',
                'url' => 'http://www.example.com/10011072851000.html'
            },
            {
                'date' => '07/25 01:01',
                'description' => 'test04',
                'guid' => 'http://www.example.com/10011072821000.html',
                'raw_url' => 'http://www.example.com/10011072821000.html',
                'readflag' => 0,
                'site_title' => 'test feed',
                'title' => 'title - test04',
                'url' => 'http://www.example.com/10011072821000.html'
            },
            {
                'date' => '07/25 01:01',
                'description' => 'test03',
                'guid' => 'http://www.example.com/10011072771000.html',
                'raw_url' => 'http://www.example.com/10011072771000.html',
                'readflag' => 0,
                'site_title' => 'test feed',
                'title' => 'title - test03',
                'url' => 'http://www.example.com/10011072771000.html'
            }
        ],
        'id' => 1
    };
};

subtest 'api - get_entry / specify category', sub {
    my $req = POST 'http://localhost/api/get_entry',
        Content => [ category => 2 ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    is_deeply $object, {
        'entry' => [
            {
                'date' => '07/25 01:01',
                'description' => 'test11',
                'guid' => 'http://www.example.com/10011072971000.html',
                'raw_url' => 'http://www.example.com/10011072971000.html',
                'readflag' => 0,
                'site_title' => 'test feed',
                'title' => 'title - test11',
                'url' => 'http://www.example.com/10011072971000.html'
            },
            {
                'date' => '07/25 01:01',
                'description' => 'test10',
                'guid' => 'http://www.example.com/10011072961000.html',
                'raw_url' => 'http://www.example.com/10011072961000.html',
                'readflag' => 0,
                'site_title' => 'test feed',
                'title' => 'title - test10',
                'url' => 'http://www.example.com/10011072961000.html'
            },
            {
                'date' => '07/25 01:01',
                'description' => 'test09',
                'guid' => 'http://www.example.com/10011072911000.html',
                'raw_url' => 'http://www.example.com/10011072911000.html',
                'readflag' => 0,
                'site_title' => 'test feed',
                'title' => 'title - test09',
                'url' => 'http://www.example.com/10011072911000.html'
            }
        ],
        'id' => '2'
    };
};

subtest 'api - get_entry / set_asread', sub {
    my $json = encode_json({
        'guid' => [
            'http://www.example.com/10011072971000.html',
            'http://www.example.com/10011072961000.html',
            'http://www.example.com/10011072911000.html',
        ]
    });

    my $req = POST 'http://localhost/api/set_asread',
        Content => $json,
        %headers;
    
    my $res = $ua->request($req);
    is $res->content, 'OK';
};

subtest 'api - get_entry / specify category after set_asread', sub {
    my $req = POST 'http://localhost/api/get_entry',
        Content => [ category => 2 ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    is scalar(@{$object->{entry}}), 2;
    my @result = sort map { $_->{guid} } @{$object->{entry}};

    my @guid = (
        'http://www.example.com/10011072881000.html',
        'http://www.example.com/10011072901000.html',
    );

    is_deeply \@result, \@guid;

    my $json = encode_json({guid => \@guid});
    my $req_read = POST 'http://localhost/api/set_asread',
        Content => $json,
        %headers;
    
    my $res_read = $ua->request($req_read);
    is $res_read->content, 'OK';
};

subtest 'api - get_entry / specify category nothing entries', sub {
    my $req = POST 'http://localhost/api/get_entry',
        Content => [ category => 2 ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    is scalar(@{$object->{entry}}), 0;
};

subtest 'api - set_pin', sub {
    my $req = POST 'http://localhost/api/set_pin',
        Content => [
            pinid => 'http://www.example.com/10011072851000.html',
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
        'guid' => 'http://www.example.com/10011072851000.html',
        'title' => 'title - test05',
        'url' => 'http://www.example.com/10011072851000.html'
    }];
};

subtest 'api - remove_all_pin', sub {
    my $req = POST 'http://localhost/api/remove_all_pin',
        %headers;
    
    my $res = $ua->request($req);
    is $res->content, 'OK';
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
(22,'http://www.example.com/feed.xml','http://www.example.com/','test feed','2017-01-01 12:34:56','200','1','2017-07-30 00:00:00','1','{}'),
(23,'http://www.example.com/feed2.xml','http://www.example.com/','test feed','2017-01-01 12:34:56','200','1','2017-07-30 00:00:00','1','{}')
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
('http://www.example.com/10011072671000.html','2017-07-24 22:22:22','2017-07-24 22:30:01',1,110,1),
('http://www.example.com/10011072731000.html','2017-07-25 01:01:00','2017-07-25 01:15:01',0,110,1),
('http://www.example.com/10011072771000.html','2017-07-25 01:01:10','2017-07-25 01:15:01',0,110,1),
('http://www.example.com/10011072821000.html','2017-07-25 01:01:15','2017-07-25 01:15:01',0,110,1),
('http://www.example.com/10011072851000.html','2017-07-25 01:01:20','2017-07-25 01:15:01',0,110,1),
('http://www.example.com/10011072871000.html','2017-07-24 01:01:25','2017-07-25 01:15:01',1,111,1),
('http://www.example.com/10011072881000.html','2017-07-25 01:01:30','2017-07-25 01:15:01',0,111,1),
('http://www.example.com/10011072901000.html','2017-07-25 01:01:35','2017-07-25 01:15:01',0,111,1),
('http://www.example.com/10011072911000.html','2017-07-25 01:01:40','2017-07-25 01:15:01',0,111,1),
('http://www.example.com/10011072961000.html','2017-07-25 01:01:45','2017-07-25 01:15:01',0,111,1),
('http://www.example.com/10011072971000.html','2017-07-25 01:01:55','2017-07-25 01:15:01',0,111,1)
;
UNLOCK TABLES;

LOCK TABLES `story` WRITE;
INSERT INTO `story` VALUES 
('http://www.example.com/10011072671000.html','title - test01','test01','http://www.example.com/10011072671000.html'),
('http://www.example.com/10011072731000.html','title - test02','test02','http://www.example.com/10011072731000.html'),
('http://www.example.com/10011072771000.html','title - test03','test03','http://www.example.com/10011072771000.html'),
('http://www.example.com/10011072821000.html','title - test04','test04','http://www.example.com/10011072821000.html'),
('http://www.example.com/10011072851000.html','title - test05','test05','http://www.example.com/10011072851000.html'),
('http://www.example.com/10011072871000.html','title - test06','test06','http://www.example.com/10011072871000.html'),
('http://www.example.com/10011072881000.html','title - test07','test07','http://www.example.com/10011072881000.html'),
('http://www.example.com/10011072901000.html','title - test08','test08','http://www.example.com/10011072901000.html'),
('http://www.example.com/10011072911000.html','title - test09','test09','http://www.example.com/10011072911000.html'),
('http://www.example.com/10011072961000.html','title - test10','test10','http://www.example.com/10011072961000.html'),
('http://www.example.com/10011072971000.html','title - test11','test11','http://www.example.com/10011072971000.html')
;
UNLOCK TABLES;

