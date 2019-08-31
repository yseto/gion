#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Data::Dumper;
use List::MoreUtils qw/uniq/;
use Log::Minimal;

use lib "lib/";
use Gion;
use Gion::Config;

#DBへ接続
my $db = Gion->cli_dbh;

# ALTER TABLE
my @sql = split /\n/, <<__EOT__;
ALTER TABLE `feed` ADD COLUMN `next_serial` int(11) NOT NULL DEFAULT 0;
ALTER TABLE `entry` ADD COLUMN `serial` int(11) NOT NULL FIRST;
ALTER TABLE `entry` ADD COLUMN `feed_id` int(11) NOT NULL AFTER `subscription_id`;
ALTER TABLE `entry` DROP INDEX `guid_2`;
ALTER TABLE `entry` DROP INDEX `guid`;
ALTER TABLE `story` ADD COLUMN `feed_id` int(11) NOT NULL FIRST;
ALTER TABLE `story` ADD COLUMN `serial` int(11) NOT NULL AFTER `feed_id`;
ALTER TABLE `story` DROP PRIMARY KEY;
__EOT__

infof("Start ALTER TABLE");
$db->query($_) for @sql;
infof("End   ALTER TABLE");

# データ用意
my %subscription_id__to_feed_id = map { 
    $_->{id} => $_->{feed_id}
} @{ $db->select_all('SELECT id, feed_id FROM subscription') };

my %next_serial = ();
sub get_next_serial {
    my $feed_id = shift;
    if (exists $next_serial{$feed_id}) {
        $next_serial{$feed_id}++;
    } else {
        $next_serial{$feed_id} = 0;
    }
    return $next_serial{$feed_id};
}

infof("Apply migration entry, story...");

# 処理
my $entries = $db->select_all('SELECT guid, subscription_id FROM entry');
foreach my $entry (@$entries) {
    my $feed_id = $subscription_id__to_feed_id{ $entry->{subscription_id} };
    my $serial = get_next_serial($feed_id);

    debugf(
        "UPDATE entry SET serial = %s, feed_id = %s WHERE guid = %s AND subscription_id = %s",
        $serial,
        $feed_id,
        $entry->{guid},
        $entry->{subscription_id},
    );

    $db->query(
        "UPDATE entry SET serial = ?, feed_id = ? WHERE guid = ? AND subscription_id = ?",
        $serial,
        $feed_id,
        $entry->{guid},
        $entry->{subscription_id},
    );

    debugf(
        "SELECT * FROM story WHERE guid = %s",
        $entry->{guid},
    );

    my $story_via_guid = $db->select_row(
        "SELECT * FROM story WHERE guid = ?",
        $entry->{guid},
    );

    debugf(
        "INSERT INTO story (feed_id, serial, guid, title, description, url) VALUES (%s,%s,%s,%s,%s,%s);",
        $feed_id,
        $serial,
        $story_via_guid->{guid},
        $story_via_guid->{title},
        $story_via_guid->{description},
        $story_via_guid->{url},
    );

    $db->query(
        "INSERT INTO story (feed_id, serial, guid, title, description, url) VALUES (?,?,?,?,?,?);",
        $feed_id,
        $serial,
        $story_via_guid->{guid},
        $story_via_guid->{title},
        $story_via_guid->{description},
        $story_via_guid->{url},
    );
}

infof("Update next_serial...");

my @feed_ids = uniq(values %subscription_id__to_feed_id);
foreach my $feed_id (@feed_ids) {
    my $serial = get_next_serial($feed_id);

    debugf(
        "UPDATE feed SET next_serial = %s WHERE id = %s", $serial, $feed_id,
    );

    $db->query("UPDATE feed SET next_serial = ? WHERE id = ?", $serial, $feed_id);
}

my $entry = $db->select_one('SELECT COUNT(*) FROM entry WHERE feed_id <> 0');
my $story = $db->select_one('SELECT COUNT(*) FROM story WHERE feed_id <> 0');

infof("entry: %d story:%s", $entry, $story);

if ($entry != $story) {
    critf("invalid story, entry count.");
    die;
}

infof("Delete old story record.");
$db->query("DELETE FROM story WHERE feed_id = 0");

# ALTER TABLE
my @finished_sql = split /\n/, <<__EOT__;
ALTER TABLE `entry` ADD UNIQUE KEY `serial_2` (`serial`,`feed_id`, `user_id`);
ALTER TABLE `story` ADD PRIMARY KEY (`feed_id`, `serial`);
__EOT__

infof("Start ALTER TABLE");
$db->query($_) for @finished_sql;
infof("End   ALTER TABLE");

__END__
diff --git a/sql/mysql.sql b/sql/mysql.sql
index b7721d5..2f39f24 100644
--- a/sql/mysql.sql
+++ b/sql/mysql.sql
@@ -38,6 +38,7 @@ CREATE TABLE IF NOT EXISTS `feed` (
   `pubdate` timestamp NOT NULL DEFAULT 0,
   `term` varchar(1) NOT NULL DEFAULT 1,
   `cache` varchar(2400) NOT NULL,
+  `next_serial` int(11) NOT NULL DEFAULT 0,
   PRIMARY KEY (`id`)
 ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;
 
@@ -55,25 +56,28 @@ CREATE TABLE IF NOT EXISTS `subscription` (
 ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;
 
 CREATE TABLE IF NOT EXISTS `entry` (
+  `serial` int(11) NOT NULL,
   `guid` varchar(250) CHARACTER SET utf8 NOT NULL,
   `pubdate` datetime NOT NULL,
   `update_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
   `readflag` tinyint(4) NOT NULL,
   `subscription_id` int(11) NOT NULL,
+  `feed_id` int(11) NOT NULL,
   `user_id` int(11) NOT NULL,
-  UNIQUE KEY `guid_2` (`guid`,`subscription_id`),
+  UNIQUE KEY `serial_2` (`serial`,`feed_id`, `user_id`),
   KEY `subscription_id` (`subscription_id`),
-  KEY `guid` (`guid`),
   CONSTRAINT `entry_ibfk_1` FOREIGN KEY (`subscription_id`) REFERENCES `subscription` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
   CONSTRAINT `entry_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
 ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
 
 CREATE TABLE IF NOT EXISTS `story` (
+  `feed_id` int(11) NOT NULL,
+  `serial` int(11) NOT NULL,
   `guid` varchar(250) CHARACTER SET utf8 NOT NULL,
   `title` varchar(80) NOT NULL,
   `description` tinytext NOT NULL,
   `url` tinytext NOT NULL,
-  PRIMARY KEY (`guid`)
+  PRIMARY KEY `feed_id_serial` (`feed_id`, `serial`)
 ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
 
 CREATE TABLE IF NOT EXISTS `social_service` (
