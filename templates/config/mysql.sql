CREATE TABLE IF NOT EXISTS `user` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) DEFAULT NULL,
  `pw` varchar(200) NOT NULL,
  `numentry` int(11) NOT NULL DEFAULT '0',
  `noreferrer` int(11) NOT NULL DEFAULT '0',
  `nopinlist` int(11) NOT NULL DEFAULT '0',
  `numsubstr` int(11) NOT NULL DEFAULT '0',
  `last_login` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
/**/
CREATE TABLE IF NOT EXISTS `categories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user` int(11) NOT NULL,
  `name` varchar(60) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `user` (`user`),
  CONSTRAINT `categories_ibfk_1` FOREIGN KEY (`user`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
/**/
CREATE TABLE IF NOT EXISTS `target` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `url` varchar(2400) NOT NULL,
  `siteurl` varchar(2400) NOT NULL,
  `title` varchar(200) NOT NULL,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `http_status` varchar(3) NOT NULL,
  `_id_categories` int(11) NOT NULL,
  `parser` varchar(1) NOT NULL DEFAULT 0,
  `user` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `_id_categories` (`_id_categories`),
  CONSTRAINT `target_ibfk` FOREIGN KEY (`_id_categories`) REFERENCES `categories` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
/**/
CREATE TABLE IF NOT EXISTS `entries` (
  `guid` varchar(250) NOT NULL,
  `pubDate` datetime NOT NULL,
  `updatetime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `readflag` tinyint(4) NOT NULL,
  `_id_target` int(11) NOT NULL,
  `user` int(11) NOT NULL,
  UNIQUE KEY `guid_2` (`guid`,`_id_target`),
  KEY `_id_target` (`_id_target`),
  KEY `guid` (`guid`),
  CONSTRAINT `entries_ibfk` FOREIGN KEY (`_id_target`) REFERENCES `target` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/**/
CREATE TABLE IF NOT EXISTS `stories` (
  `guid` varchar(250) NOT NULL,
  `title` varchar(80) NOT NULL,
  `description` tinytext NOT NULL,
  `url` tinytext NOT NULL,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/**/
CREATE TABLE IF NOT EXISTS `connection` (
  `user` int(11) NOT NULL,
  `service` varchar(60) NOT NULL,
  `username` varchar(60) NOT NULL,
  `key` varchar(120) NOT NULL,
  UNIQUE KEY `userservice` (`user`,`service`),
  CONSTRAINT `connection_ibfk_1` FOREIGN KEY (`user`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/**/

