use strict;
use warnings;

use lib "t/";
use testenv;

use Data::Section::Simple qw(get_data_section);
use Test::More;

use lib "lib/";
use Gion::Data;
use Gion::Config;

my $dbh = dbh();
my $guard = config->local(test_config());

for my $stmt (split /;/, get_data_section('table')) {
    next unless $stmt =~ /\S/;
    $dbh->do($stmt) or die $dbh->errstr;
}

subtest 'unseen all entry', sub {
    my $sql = "SELECT * FROM entry WHERE subscription_id = 110";
    my $before = $dbh->selectall_arrayref($sql);

    my $expected = [
        [ 1, '2017-07-24 22:22:22', '2017-07-24 22:30:01', 0, 110, 22, 1 ],
        [ 2, '2017-07-25 01:01:00', '2017-07-25 01:15:01', 0, 110, 22, 1 ],
        [ 3, '2017-07-25 01:01:10', '2017-07-25 01:15:01', 0, 110, 22, 1 ],
        [ 4, '2017-07-25 01:01:15', '2017-07-25 01:15:01', 0, 110, 22, 1 ],
        [ 5, '2017-07-25 01:01:20', '2017-07-25 01:15:01', 0, 110, 22, 1 ]
    ];

    is_deeply $before, $expected;

    my $data = Gion::Data->new(dbh => dbh());
    $data->purge_old_entry_by_subscription(subscription_id => 110);

    my $after = $dbh->selectall_arrayref($sql);

    is_deeply $after, $expected;
};

subtest 'seen some entry', sub {
    my $sql = "SELECT * FROM entry WHERE subscription_id = 111";
    my $before = $dbh->selectall_arrayref($sql);

    my $expected = [
        [6, '2017-07-24 01:01:25','2017-07-25 01:15:01',1,111,23,1],
        [7, '2017-07-25 01:01:30','2017-07-25 01:15:01',1,111,23,1],
        [8, '2017-07-25 01:01:35','2017-07-25 01:15:01',1,111,23,1],
        [9, '2017-07-25 01:01:40','2017-07-25 01:15:01',0,111,23,1],
        [10,'2017-07-25 01:01:45','2017-07-25 01:15:01',0,111,23,1],
        [11,'2017-07-25 01:01:55','2017-07-25 01:15:01',0,111,23,1]
    ];

    is_deeply $before, $expected;

    my $data = Gion::Data->new(dbh => dbh());
    $data->purge_old_entry_by_subscription(subscription_id => 111);

    my $after = $dbh->selectall_arrayref($sql);

    my $expected2 = [
        [8, '2017-07-25 01:01:35','2017-07-25 01:15:01',1,111,23,1],
        [9, '2017-07-25 01:01:40','2017-07-25 01:15:01',0,111,23,1],
        [10,'2017-07-25 01:01:45','2017-07-25 01:15:01',0,111,23,1],
        [11,'2017-07-25 01:01:55','2017-07-25 01:15:01',0,111,23,1]
    ];

    is_deeply $after, $expected2;
};

subtest 'seen some entry and pin 1', sub {
    my $sql = "SELECT * FROM entry WHERE subscription_id = 112";
    my $before = $dbh->selectall_arrayref($sql);

    my $expected = [
        [1, '2017-07-24 22:22:22','2017-07-24 22:30:01',1,112,22,2],
        [2, '2017-07-25 01:01:00','2017-07-25 01:15:01',1,112,22,2],
        [3, '2017-07-25 01:01:10','2017-07-25 01:15:01',2,112,22,2],
        [4, '2017-07-25 01:01:15','2017-07-25 01:15:01',1,112,22,2],
        [5, '2017-07-25 01:01:20','2017-07-25 01:15:01',0,112,22,2],
    ];

    is_deeply $before, $expected;

    my $data = Gion::Data->new(dbh => dbh());
    $data->purge_old_entry_by_subscription(subscription_id => 112);

    my $after = $dbh->selectall_arrayref($sql);

    my $expected2 = [
        [3, '2017-07-25 01:01:10','2017-07-25 01:15:01',2,112,22,2],
        [4, '2017-07-25 01:01:15','2017-07-25 01:15:01',1,112,22,2],
        [5, '2017-07-25 01:01:20','2017-07-25 01:15:01',0,112,22,2],
    ];

    is_deeply $after, $expected2;
};


subtest 'seen some entry and pin 2', sub {
    my $data = Gion::Data->new(dbh => dbh());

    my $sql = "SELECT * FROM entry WHERE subscription_id = 113";
    my $before = $dbh->selectall_arrayref($sql);
    $data->purge_old_entry_by_subscription(subscription_id => 113);
    my $after = $dbh->selectall_arrayref($sql);

    my ($h23) = $dbh->selectrow_array('SELECT @23H');
    my ($h24) = $dbh->selectrow_array('SELECT @24H');
    my ($h25) = $dbh->selectrow_array('SELECT @25H');

    my $expected = [
        [6, '2017-07-24 01:01:25',$h25,1,113,23,2],
        [7, '2017-07-25 01:01:30',$h24,1,113,23,2],
        [8, '2017-07-25 01:01:35',$h23,1,113,23,2],
        [9, '2017-07-25 01:01:40',$h23,1,113,23,2],
        [10,'2017-07-25 01:01:45',$h23,2,113,23,2],
        [11,'2017-07-25 01:01:55',$h23,0,113,23,2]
    ];

    is_deeply $before, $expected;

    my $expected2 = [
        [7, '2017-07-25 01:01:30',$h24,1,113,23,2],
        [8, '2017-07-25 01:01:35',$h23,1,113,23,2],
        [9, '2017-07-25 01:01:40',$h23,1,113,23,2],
        [10,'2017-07-25 01:01:45',$h23,2,113,23,2],
        [11,'2017-07-25 01:01:55',$h23,0,113,23,2]
    ];

    is_deeply $after, $expected2;
};

done_testing;

__DATA__

@@ table

INSERT INTO user (id, password, name) VALUES (1, 'xxxxx', '1');
INSERT INTO user (id, password, name) VALUES (2, 'xxxxx', '2');

LOCK TABLES `category` WRITE;
INSERT INTO `category`
(`id`, `user_id`, `name`)
VALUES
(1,1,'category_user_1'),
(2,2,'category_user_2')
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
(111,1,23,1),
(112,2,22,2),
(113,2,23,2)
;
UNLOCK TABLES;

-- 110 unseen all entry
-- 111 seen some entry
-- 112 seen some entry and pin
-- 113 seen some entry and pin CURRENT_TIMESTAMP

SET @23H = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL -23 HOUR);
SET @24H = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL -24 HOUR);
SET @25H = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL -25 HOUR);
LOCK TABLES `entry` WRITE;
INSERT INTO `entry`
(`serial`, `pubdate`, `update_at`, `readflag`, `subscription_id`, `feed_id`, `user_id`)
VALUES
(1, '2017-07-24 22:22:22','2017-07-24 22:30:01',0,110,22,1),
(2, '2017-07-25 01:01:00','2017-07-25 01:15:01',0,110,22,1),
(3, '2017-07-25 01:01:10','2017-07-25 01:15:01',0,110,22,1),
(4, '2017-07-25 01:01:15','2017-07-25 01:15:01',0,110,22,1),
(5, '2017-07-25 01:01:20','2017-07-25 01:15:01',0,110,22,1),
(6, '2017-07-24 01:01:25','2017-07-25 01:15:01',1,111,23,1),
(7, '2017-07-25 01:01:30','2017-07-25 01:15:01',1,111,23,1),
(8, '2017-07-25 01:01:35','2017-07-25 01:15:01',1,111,23,1),
(9, '2017-07-25 01:01:40','2017-07-25 01:15:01',0,111,23,1),
(10,'2017-07-25 01:01:45','2017-07-25 01:15:01',0,111,23,1),
(11,'2017-07-25 01:01:55','2017-07-25 01:15:01',0,111,23,1),

(1, '2017-07-24 22:22:22','2017-07-24 22:30:01',1,112,22,2),
(2, '2017-07-25 01:01:00','2017-07-25 01:15:01',1,112,22,2),
(3, '2017-07-25 01:01:10','2017-07-25 01:15:01',2,112,22,2),
(4, '2017-07-25 01:01:15','2017-07-25 01:15:01',1,112,22,2),
(5, '2017-07-25 01:01:20','2017-07-25 01:15:01',0,112,22,2),
(6, '2017-07-24 01:01:25',@25H,1,113,23,2),
(7, '2017-07-25 01:01:30',@24H,1,113,23,2),
(8, '2017-07-25 01:01:35',@23H,1,113,23,2),
(9, '2017-07-25 01:01:40',@23H,1,113,23,2),
(10,'2017-07-25 01:01:45',@23H,2,113,23,2),
(11,'2017-07-25 01:01:55',@23H,0,113,23,2)
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

