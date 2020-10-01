CREATE DATABASE `gion` CHARACTER SET utf8mb4;
GRANT ALL PRIVILEGES ON gion.* TO 'gion'@'%' IDENTIFIED BY 'gion';

use gion;

CREATE TABLE IF NOT EXISTS `user` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) DEFAULT NULL,
  `password` varchar(200) NOT NULL,
  `numentry` int(11) NOT NULL DEFAULT '0',
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
  `pubdate` timestamp NOT NULL DEFAULT 0,
  `term` varchar(1) NOT NULL DEFAULT 1,
  `cache` varchar(2400) NOT NULL,
  `next_serial` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `subscription` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `category_id` int(11) NOT NULL,
  `feed_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `category_id` (`category_id`),
  CONSTRAINT `subscription_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `category` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  KEY `feed_id` (`feed_id`),
  CONSTRAINT `subscription_ibfk_2` FOREIGN KEY (`feed_id`) REFERENCES `feed` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `subscription_ibfk_3` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `entry` (
  `serial` int(11) NOT NULL,
  `pubdate` datetime NOT NULL,
  `update_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `readflag` tinyint(4) NOT NULL,
  `subscription_id` int(11) NOT NULL,
  `feed_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  UNIQUE KEY `serial_2` (`serial`,`feed_id`, `user_id`),
  KEY `subscription_id` (`subscription_id`),
  CONSTRAINT `entry_ibfk_1` FOREIGN KEY (`subscription_id`) REFERENCES `subscription` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `entry_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `story` (
  `feed_id` int(11) NOT NULL,
  `serial` int(11) NOT NULL,
  `title` varchar(80) NOT NULL,
  `description` tinytext NOT NULL,
  `url` varchar(2400) NOT NULL,
  PRIMARY KEY (`feed_id`, `serial`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

