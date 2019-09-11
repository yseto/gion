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
ALTER TABLE `entry` DROP COLUMN `guid`;
ALTER TABLE `story` DROP COLUMN `guid`;
__EOT__

infof("Start ALTER TABLE");
$db->query($_) for @sql;
infof("End   ALTER TABLE");

__END__
diff --git a/sql/mysql.sql b/sql/mysql.sql
index c881118..fa4dd38 100644
--- a/sql/mysql.sql
+++ b/sql/mysql.sql
@@ -3,8 +3,6 @@ GRANT ALL PRIVILEGES ON gion.* TO 'gion'@'%' IDENTIFIED BY 'gion';
 
 use gion;
 
--- TODO guid column charset is utf8.
-
 CREATE TABLE IF NOT EXISTS `user` (
   `id` int(11) NOT NULL AUTO_INCREMENT,
   `name` varchar(32) DEFAULT NULL,
@@ -57,7 +55,6 @@ CREATE TABLE IF NOT EXISTS `subscription` (
 
 CREATE TABLE IF NOT EXISTS `entry` (
   `serial` int(11) NOT NULL,
-  `guid` varchar(250) CHARACTER SET utf8 NOT NULL,
   `pubdate` datetime NOT NULL,
   `update_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
   `readflag` tinyint(4) NOT NULL,
@@ -73,7 +70,6 @@ CREATE TABLE IF NOT EXISTS `entry` (
 CREATE TABLE IF NOT EXISTS `story` (
   `feed_id` int(11) NOT NULL,
   `serial` int(11) NOT NULL,
-  `guid` varchar(250) CHARACTER SET utf8 NOT NULL,
   `title` varchar(80) NOT NULL,
   `description` tinytext NOT NULL,
   `url` tinytext NOT NULL,
