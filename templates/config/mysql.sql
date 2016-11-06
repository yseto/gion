-- CREATE DATABASE ??? CHARACTER SET utf8mb4;

-- TODO guid column charset is utf8.

CREATE TABLE IF NOT EXISTS `user` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) DEFAULT NULL,
  `password` varchar(200) NOT NULL,
  `numentry` int(11) NOT NULL DEFAULT '0',
  `noreferrer` int(11) NOT NULL DEFAULT '0',
  `nopinlist` int(11) NOT NULL DEFAULT '0',
  `numsubstr` int(11) NOT NULL DEFAULT '0',
  `last_login` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `category` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `name` varchar(60) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `category_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `feed` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `url` varchar(2400) NOT NULL,
  `siteurl` varchar(2400) NOT NULL,
  `title` varchar(200) NOT NULL,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `http_status` varchar(3) NOT NULL,
  `parser` varchar(1) NOT NULL DEFAULT 0,
  `pubDate` timestamp NOT NULL DEFAULT 0,
  `term` varchar(1) NOT NULL DEFAULT 1,
  `cache` varchar(2400) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `target` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `category_id` int(11) NOT NULL,
  `feed_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `category_id` (`category_id`),
  CONSTRAINT `target_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `category` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  KEY `feed_id` (`feed_id`),
  CONSTRAINT `target_ibfk_2` FOREIGN KEY (`feed_id`) REFERENCES `feed` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `entry` (
  `guid` varchar(250) CHARACTER SET utf8 NOT NULL,
  `pubDate` datetime NOT NULL,
  `updatetime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `readflag` tinyint(4) NOT NULL,
  `target_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  UNIQUE KEY `guid_2` (`guid`,`target_id`),
  KEY `target_id` (`target_id`),
  KEY `guid` (`guid`),
  CONSTRAINT `entry_ibfk_1` FOREIGN KEY (`target_id`) REFERENCES `target` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `story` (
  `guid` varchar(250) CHARACTER SET utf8 NOT NULL,
  `title` varchar(80) NOT NULL,
  `description` tinytext NOT NULL,
  `url` tinytext NOT NULL,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `connection` (
  `user_id` int(11) NOT NULL,
  `service` varchar(60) NOT NULL,
  `username` varchar(60) NOT NULL,
  `key` varchar(120) NOT NULL,
  UNIQUE KEY `userservice` (`user_id`,`service`),
  CONSTRAINT `connection_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


