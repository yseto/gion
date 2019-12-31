package Gion::Scripts::Cleanup;

use strict;
use warnings;
use utf8;

# 既読のものを削除する。
# ただし、最新の既読エントリは残しておく必要がある
# （そこを目印に、RSSの読み取りが行われるため）

#  http://stackoverflow.com/questions/8886026/mysql-delete-all-but-latest-x-records

use Gion;
use Gion::Config;

*main_proclet = \&main_and_db;
*main_script = \&main_and_db;

sub main_api {
    my ($class, $db) = @_;
    main($db);
}

sub main_and_db {
    my $db = Gion->cli_dbh;
    main($db);
}

sub main {
my $db = shift;

my $count;
my %cmp;

$cmp{olde} = $db->select_one('SELECT COUNT(*) FROM entry');
$cmp{olds} = $db->select_one('SELECT COUNT(*) FROM story');

my $rs = $db->select_all('SELECT id FROM subscription');

for (@$rs) {
    my $id = $_->{id};
    $db->query("
        DELETE
        FROM entry
        WHERE subscription_id = ?
            AND readflag = 1
            AND update_at < DATE_ADD(CURRENT_TIMESTAMP, INTERVAL -1 DAY)
            AND
            pubdate NOT IN (SELECT pubdate FROM
                (SELECT pubdate FROM entry
                    WHERE subscription_id = ?  AND readflag = 1
                    ORDER BY pubdate DESC LIMIT 1
                ) x )
    ", $id, $id);
    # print $id . "\n";
}

my $entry = $db->select_all("SELECT subscription_id FROM entry;");
for (@$entry) {
    my $count = $db->select_one(
        "SELECT COUNT(*) FROM subscription WHERE id = ?",
        $_->{subscription_id},
    );

    unless ($count > 0) {
        $db->query(
            "DELETE FROM entry WHERE subscription_id = ?",
            $_->{subscription_id},
        );
    }
}

my $feed = $db->select_all("SELECT * FROM feed;");
for (@$feed) {
    my $count = $db->select_one(
        "SELECT COUNT(*) FROM subscription WHERE feed_id = ?",
        $_->{id},
    );
    unless ($count > 0) {
        printf "remove subscription: %s\n", $_->{siteurl};
        $db->query(
            "DELETE FROM feed WHERE id = ?",
            $_->{id},
        );
    }
}

my $story = $db->select_all("SELECT feed_id, serial, url FROM story");
for (@$story) {
    my $count = $db->select_one(
        "SELECT COUNT(*) FROM entry WHERE feed_id = ? AND serial = ?",
        $_->{feed_id},
        $_->{serial},
    );
    unless ($count > 0) {
        printf "remove story: %s\n", $_->{url};
        $db->query(
            "DELETE FROM story WHERE feed_id = ? AND serial = ?",
            $_->{feed_id},
            $_->{serial},
        );
    }
}

$cmp{e} = $db->select_one('SELECT COUNT(*) FROM entry');
$cmp{s} = $db->select_one('SELECT COUNT(*) FROM story');

printf "entry %d -> %d \n", $cmp{olde}, $cmp{e};
printf "story %d -> %d \n", $cmp{olds}, $cmp{s};

}

1;
