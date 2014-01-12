DROP TABLE IF EXISTS categories;
CREATE TABLE categories (
  id INTEGER PRIMARY KEY,
  user INTEGER NOT NULL,
  name VARCHAR(60) NOT NULL,
  FOREIGN KEY (user) REFERENCES user(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX categories_index ON categories (user);

DROP TABLE IF EXISTS entries;
CREATE TABLE entries (
  guid VARCHAR(250) NOT NULL,
  pubDate DATETIME NOT NULL,
  updatetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  readflag VARCHAR(1) NOT NULL,
  _id_target INTEGER NOT NULL,
  user INTEGER NOT NULL,
  FOREIGN KEY (_id_target) REFERENCES target(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX entries_index1 ON entries (guid,_id_target);
CREATE INDEX entries_index2 ON entries (guid);
CREATE INDEX entries_index3 ON entries (_id_target);

DROP TABLE IF EXISTS target;
CREATE TABLE target (
  id INTEGER PRIMARY KEY,
  url VARCHAR(2400) NOT NULL,
  siteurl VARCHAR(2400) NOT NULL,
  title VARCHAR(200) NOT NULL,
  time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  http_status VARCHAR(3) NOT NULL,
  _id_categories INTEGER NOT NULL,
  parser VARCHAR(1) NOT NULL DEFAULT 0,
  user INTEGER NOT NULL,
  FOREIGN KEY (_id_categories) REFERENCES categories (id) ON DELETE CASCADE ON UPDATE CASCADE
) ;

CREATE INDEX target_index ON target (_id_categories);

DROP TABLE IF EXISTS user;
CREATE TABLE user (
  id INTEGER PRIMARY KEY,
  name VARCHAR(32) DEFAULT NULL,
  pw VARCHAR(200) NOT NULL,
  numentry INTEGER NOT NULL DEFAULT '0',
  noreferrer INTEGER NOT NULL DEFAULT '0',
  nopinlist INTEGER NOT NULL DEFAULT '0',
  last_login TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX user_index1 ON user (name);

DROP TABLE IF EXISTS stories;
CREATE TABLE stories (
  guid VARCHAR(250) PRIMARY KEY NOT NULL,
  title VARCHAR(80) NOT NULL,
  description TEXT NOT NULL,
  url VARCHAR(2400) NOT NULL
);

DROP TABLE IF EXISTS connection;
CREATE TABLE connection (
  user INTEGER NOT NULL,
  service VARCHAR(60) NOT NULL,
  username VARCHAR(60) NOT NULL,
  key VARCHAR(120) NOT NULL,
  FOREIGN KEY (user) REFERENCES user (id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX connection_index1 ON connection(user,service);

