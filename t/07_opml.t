use strict;
use warnings;

use lib "t/";
use testenv;

use Encode;
use Data::Section::Simple qw(get_data_section);
use Plack::Test;
use Plack::Util;
use Test::More;
use Test::WWW::Mechanize::PSGI;
use File::Slurp;
use LWP::Protocol::PSGI;
use LWP::UserAgent;
use HTTP::CookieJar::LWP;
use HTTP::Request::Common;
use JSON;
use JSON::XS;

use lib "lib/";
use Gion::Config;
use Gion::Model::User;

my $dbh = dbh();
my $guard = config->local(test_config());

my $app = Plack::Util::load_psgi('app.psgi');

# generate user account.
my $user_model = Gion::Model::User->new;
my $digest = $user_model->generate_password_digest_with_username(
    username => "admin",
    password => "password123456",
);

# register user.
$dbh->do("INSERT INTO user (id, password, name) VALUES (null, '$digest', 'admin')");

for my $stmt (split /;/, get_data_section('table')) {
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

subtest 'api - get opml', sub {
    my $req = POST 'http://localhost/api/opml_export',
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    is $object->{xml}, get_data_section('xml');
};

subtest 'api - get opml2', sub {
    my $req = POST 'http://localhost/api/delete_it',
        Content => [ subscription => 'entry', id => 23 ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;
    is $object->{r}, 'OK';

    my $req2 = POST 'http://localhost/api/opml_export',
        %headers;
    
    my $res2 = $ua->request($req2);
    my $object2 = decode_json $res2->content;

    is $object2->{xml}, get_data_section('xml2');
};

subtest 'api - import opml', sub {
    my $req = POST 'http://localhost/api/opml_import',
        Content => [ xml => get_data_section('xml') ],
        %headers;
    
    my $res = $ua->request($req);
    my $object = decode_json $res->content;

    is $object->{done}, 1;

    my $req2 = POST 'http://localhost/api/opml_export',
        %headers;
    
    my $res2 = $ua->request($req2);
    my $object2 = decode_json $res2->content;

    is $object2->{xml}, get_data_section('xml');

};


done_testing;

__DATA__

@@ table

LOCK TABLES `category` WRITE;
INSERT INTO `category`
(`id`, `user_id`, `name`)
VALUES
(1,1,'category1'),
(2,1,'category2')
;
UNLOCK TABLES;

LOCK TABLES `feed` WRITE;
INSERT INTO `feed`
(`id`, `url`, `siteurl`, `title`, `time`, `http_status`, `parser`, `pubdate`, `term`, `cache`, `next_serial`)
VALUES
(22,'http://www.example.com/feed.xml','http://www.example.com/','test feed','2017-01-01 12:34:56','200','1','2017-07-30 00:00:00','1','{}', 0),
(23,'http://www.example.com/feed2.xml','http://www.example.com/','test feed','2017-01-01 12:34:56','200','1','2017-07-30 00:00:00','1','{}', 0)
;
UNLOCK TABLES;

LOCK TABLES `subscription` WRITE;
INSERT INTO `subscription`
(`id`, `category_id`, `feed_id`, `user_id`)
VALUES
(110,1,22,1),
(111,2,23,1)
;
UNLOCK TABLES;

LOCK TABLES `entry` WRITE;
INSERT INTO `entry`
(`serial`, `pubdate`, `update_at`, `readflag`, `subscription_id`, `feed_id`, `user_id`)
VALUES
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
INSERT INTO `story`
(`feed_id`, `serial`, `title`, `description`, `url` )
VALUES
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

@@ xml
<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.0">
<head>
<title>export data</title>
</head>
<body>

<outline text="category1" title="category1">

<outline type="rss" text="test feed" title="test feed" xmlUrl="http://www.example.com/feed.xml" htmlUrl="http://www.example.com/"/>

</outline>

<outline text="category2" title="category2">

<outline type="rss" text="test feed" title="test feed" xmlUrl="http://www.example.com/feed2.xml" htmlUrl="http://www.example.com/"/>

</outline>

</body>
</opml>

@@ xml2
<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.0">
<head>
<title>export data</title>
</head>
<body>

<outline text="category1" title="category1">

<outline type="rss" text="test feed" title="test feed" xmlUrl="http://www.example.com/feed.xml" htmlUrl="http://www.example.com/"/>

</outline>

<outline text="category2" title="category2">

</outline>

</body>
</opml>

@@ data2

