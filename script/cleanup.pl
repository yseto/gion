#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature q(say);

# 既読のものを削除する。
# ただし、最新の既読エントリは残しておく必要がある
# （そこを目印に、RSSの読み取りが行われるため）

#  http://stackoverflow.com/questions/8886026/mysql-delete-all-but-latest-x-records

use lib 'lib/';
use Gion;
use Gion::Config;

my $count;
my %cmp;

my $db = Gion->cli_dbh;

$count = $db->select_row('SELECT COUNT(guid) AS t FROM entry');
$cmp{olde} = $count->{t};
$count = $db->select_row('SELECT COUNT(guid) AS t FROM story');
$cmp{olds} = $count->{t};

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

my $entry = $db->select_all("SELECT * FROM entry;");
for (@$entry) {
    my $subscription = $db->select_row("
        SELECT COUNT(*) AS t FROM subscription WHERE id = ?
    ", $_->{subscription_id});

    unless ($subscription->{t} > 0) {
        $db->query("
            DELETE FROM entry WHERE subscription_id = ?
        ", $_->{subscription_id} );
    }
}

my $feed = $db->select_all("SELECT * FROM feed;");
for (@$feed) {
    my $subscription = $db->select_row("
        SELECT COUNT(*) AS t FROM subscription WHERE feed_id = ?
    ", $_->{id});
    unless ($subscription->{t} > 0) {
        printf "remove subscription: %s\n", $_->{siteurl};
        $db->query("
            DELETE FROM feed WHERE id = ?
        ", $_->{id});
    }
}

$db->query('OPTIMIZE TABLE entry');
$db->query('DELETE FROM story WHERE guid NOT IN (SELECT guid FROM entry)');
$db->query('OPTIMIZE TABLE story');

$count = $db->select_row('SELECT COUNT(guid) AS t FROM entry');
$cmp{e} = $count->{t};
$count = $db->select_row('SELECT COUNT(guid) AS t FROM story');
$cmp{s} = $count->{t};

printf "entry %d -> %d \n", $cmp{olde}, $cmp{e};
printf "story %d -> %d \n", $cmp{olds}, $cmp{s};

=encoding utf8

=head1 NAME

cleanup - item cleaner.

=cut

