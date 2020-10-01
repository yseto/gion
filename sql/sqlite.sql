CREATE TABLE IF NOT EXISTS `user` (
  `id` INTEGER PRIMARY KEY AUTOINCREMENT,
  `name` varchar(32) DEFAULT NULL,
  `digest` varchar(200) NULL,
  `numentry` INTEGER NOT NULL DEFAULT '0',
  `nopinlist` INTEGER NOT NULL DEFAULT '0',
  `numsubstr` INTEGER NOT NULL DEFAULT '0',
  `last_login` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX user_name ON user(name);

CREATE TABLE IF NOT EXISTS `category` (
  `id` INTEGER PRIMARY KEY AUTOINCREMENT,
  `user_id` INTEGER NOT NULL,
  `name` varchar(60) NOT NULL,
  FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX category_user_id ON category(user_id);

CREATE TABLE IF NOT EXISTS `feed` (
  `id` INTEGER PRIMARY KEY AUTOINCREMENT,
  `url` varchar(2400) NOT NULL,
  `siteurl` varchar(2400) NOT NULL,
  `title` varchar(200) NOT NULL,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `http_status` varchar(3) NOT NULL,
  `parser` varchar(1) NOT NULL DEFAULT 0,
  `pubdate` timestamp NOT NULL DEFAULT 0,
  `term` varchar(1) NOT NULL DEFAULT 1,
  `cache` varchar(2400) NOT NULL,
  `next_serial` INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS `subscription` (
  `id` INTEGER PRIMARY KEY AUTOINCREMENT,
  `category_id` INTEGER NOT NULL,
  `feed_id` INTEGER NOT NULL,
  `user_id` INTEGER NOT NULL,
  FOREIGN KEY (`category_id`) REFERENCES `category` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (`feed_id`) REFERENCES `feed` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX subscription_category_id ON subscription(category_id);
CREATE INDEX subscription_feed_id ON subscription(feed_id);

CREATE TABLE IF NOT EXISTS `entry` (
  `serial` INTEGER NOT NULL,
  `pubdate` datetime NOT NULL,
  `update_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `readflag` tinyint(4) NOT NULL,
  `subscription_id` INTEGER NOT NULL,
  `feed_id` INTEGER NOT NULL,
  `user_id` INTEGER NOT NULL,
  FOREIGN KEY (`subscription_id`) REFERENCES `subscription` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX entry_subscription_id ON entry(subscription_id);
CREATE UNIQUE INDEX entry_serial_feed_id_user_id ON entry(`serial`,`feed_id`, `user_id`);

CREATE TABLE IF NOT EXISTS `story` (
  `feed_id` INTEGER NOT NULL,
  `serial` INTEGER NOT NULL,
  `title` varchar(80) NOT NULL,
  `description` tinytext NOT NULL,
  `url` varchar(2400) NOT NULL
);
CREATE UNIQUE INDEX story_feed_id_serial ON story(`feed_id`,`serial`);

