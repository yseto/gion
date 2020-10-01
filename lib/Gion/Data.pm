package Gion::Data;

use strict;
use warnings;
use utf8;

use parent qw/DBIx::Sunny::Schema/;
use Mouse::Util::TypeConstraints;

subtype 'Uint'
    => as 'Int'
    => where { $_ >= 0 };

subtype 'Natural'
    => as 'Int'
    => where { $_ > 0 };

subtype 'UrlLike'
    => as 'Str'
    => where { $_ =~ /^https?:/ };

#
# 0 - unseen, 1 - seen, 2 - set pin
#
enum 'ReadFlag' => qw/1 2/;

#
# 0 - error or undefined, 1 - RSS, 2 - ATOM
#
enum 'Parser' => qw/1 2/;

no Mouse::Util::TypeConstraints;

#
# category
#

__PACKAGE__->select_row(
    'category_by_id',
    user_id => 'Natural',
    id => 'Natural',
    "SELECT * FROM category WHERE user_id = ? AND id = ?",
);

__PACKAGE__->select_row(
    'category_by_name',
    user_id => 'Natural',
    name => 'Str',
    "SELECT * FROM category WHERE user_id = ? AND name = ?",
);

__PACKAGE__->select_all(
    'category',
    user_id => 'Natural',
    "SELECT * FROM category WHERE user_id = ? ORDER BY name ASC"
);

__PACKAGE__->select_all(
    'category_and_unread_entry_count',
    user_id => 'Natural',
    <<__SQL__
SELECT
    COUNT(0) AS count,
    category.id AS id,
    category.name AS name
FROM entry
INNER JOIN subscription ON entry.subscription_id = subscription.id
INNER JOIN category ON subscription.category_id = category.id
WHERE readflag <> 1
    AND category.user_id = ?
GROUP BY category.id
ORDER BY category.name ASC
__SQL__
);

__PACKAGE__->query(
    'delete_category',
    id => 'Natural',
    user_id => 'Natural',
    "DELETE FROM category WHERE id = ? AND user_id = ?",
);

__PACKAGE__->query(
    'insert_category',
    user_id => 'Natural',
    name => 'Str',
    "INSERT INTO category (id, user_id, name) VALUES (null, ?, ?)"
);

#
# entry
#

__PACKAGE__->select_all(
    'unread_entry_by_category',
    category_id => 'Natural',
    user_id => 'Natural',
    <<__SQL__
SELECT
    entry.serial,
    entry.feed_id,
    story.title,
    description,
    pubdate,
    readflag,
    story.url,
    subscription_id
FROM entry
INNER JOIN subscription ON subscription_id = subscription.id
INNER JOIN story ON story.serial = entry.serial AND story.feed_id = entry.feed_id
WHERE subscription.category_id = ?
    AND readflag <> 1
    AND entry.user_id = ?
ORDER BY pubdate DESC
__SQL__
);

__PACKAGE__->query(
    'update_entry_seen',
    user_id => 'Natural',
    feed_id => 'Natural',
    serial => 'Natural',
    <<__SQL__
UPDATE entry
SET
    readflag = 1,
    update_at = CURRENT_TIMESTAMP
WHERE readflag = 0
    AND user_id = ?
    AND feed_id = ?
    AND serial = ?
__SQL__
);

__PACKAGE__->query(
    'insert_entry',
    user_id => 'Natural',
    feed_id => 'Natural',
    serial => 'Natural',
    subscription_id => 'Natural',

    pubdate => 'Str',
    <<__SQL__
INSERT IGNORE INTO entry
(user_id, feed_id, serial, subscription_id, pubdate, readflag,  update_at)
VALUES (?, ?, ?, ?, ?, 0, CURRENT_TIMESTAMP)
__SQL__
);

__PACKAGE__->select_one(
    'latest_entry_pubdate_by_subscription',
    id => 'Natural',

    <<__SQL__
SELECT pubdate
FROM entry
WHERE subscription_id = ? AND readflag = 1
ORDER BY pubdate DESC
LIMIT 1
__SQL__
);

# pin

__PACKAGE__->select_all(
    'pin_list',
    user_id => 'Natural',
    <<__SQL__
SELECT
    story.title,
    story.url,
    entry.serial,
    entry.feed_id,
    entry.update_at
FROM entry
INNER JOIN
    story ON story.serial = entry.serial
AND
    story.feed_id = entry.feed_id
WHERE
    entry.readflag = 2
AND
    entry.user_id = ?
ORDER BY pubdate DESC
__SQL__
);

__PACKAGE__->query(
    'update_entry',
    readflag => { isa => 'ReadFlag' },
    user_id => 'Natural',
    serial => 'Natural',
    feed_id => 'Natural',
    <<__SQL__
UPDATE entry
SET
    readflag = ?,
    update_at = CURRENT_TIMESTAMP
WHERE user_id = ? AND serial = ? AND feed_id = ?
__SQL__
);

__PACKAGE__->query(
    'remove_all_pin',
    user_id => 'Natural',
    <<__SQL__
UPDATE entry
SET
    readflag = 1,
    update_at = CURRENT_TIMESTAMP
WHERE readflag = 2 AND user_id = ?
__SQL__
);

#
# feed
#

__PACKAGE__->select_row(
    'feed_by_id',
    id => 'Natural',
    "SELECT * FROM feed WHERE id = ?",
);

__PACKAGE__->select_all(
    'feed_by_id_range',
    id  => { isa => 'ArrayRef[Natural]' },
    "SELECT * FROM feed WHERE id IN (?)",
);

__PACKAGE__->select_all(
    'feed_by_term',
    term => 'Natural',
    "SELECT * FROM feed WHERE term = ?",
);

__PACKAGE__->select_all(
    'feed',
    "SELECT * FROM feed",
);

__PACKAGE__->select_row(
    'feed_by_urlset',
    url => 'UrlLike',
    siteurl => 'UrlLike',
    "SELECT * FROM feed WHERE url = ? AND siteurl = ?",
);

__PACKAGE__->select_one(
    'feed_title_by_subscription_id',
    id => 'Natural',
    <<__SQL__
SELECT feed.title
FROM subscription
INNER JOIN feed ON subscription.feed_id = feed.id
WHERE subscription.id = ?
__SQL__
);

__PACKAGE__->query(
    'insert_feed',
    url => 'UrlLike',
    siteurl => 'UrlLike',
    title => 'Str',
    "INSERT INTO feed (url, siteurl, title, http_status, pubdate, cache) VALUES (?, ?, ?, 0, NOW(), '{}')",
);

__PACKAGE__->select_one(
    'get_next_serial',
    id => 'Natural',
    "SELECT next_serial FROM feed WHERE id = ?",
);

__PACKAGE__->query(
    'update_next_serial',
    id => 'Natural',
    "UPDATE feed SET next_serial = next_serial + 1 WHERE id = ?",
);

__PACKAGE__->query(
    'update_feed',
    http_status => 'Uint',
    term => 'Uint',
    cache => 'Str',
    id => 'Natural',
    "UPDATE feed SET http_status = ?, term = ?, cache = ? WHERE id = ?",
);

__PACKAGE__->query(
    'update_feed_url',
    url => 'Str',
    id => 'Natural',
    "UPDATE feed SET url = ? WHERE id = ?",
);

__PACKAGE__->query(
    'update_feed_parser_error',
    http_status => 'Uint',
    cache => 'Str',
    id => 'Natural',
    <<__SQL__
UPDATE feed
SET
    http_status = ?, cache = ?, parser = 0, term = 1
WHERE
    id = ?
__SQL__
);

__PACKAGE__->query(
    'update_feed_parser',
    parser => { isa => 'Parser' },
    id => 'Natural',
    "UPDATE feed SET parser = ? WHERE id = ?",
);

__PACKAGE__->query(
    'update_feed_info',
    http_status => 'Uint',
    pubdate => 'Str',
    term => 'Uint',
    cache => 'Str',

    id => 'Natural',
    <<__SQL__
UPDATE feed
SET
    http_status = ?, pubdate = ?, term = ?, cache = ?
WHERE
    id = ?
__SQL__
);

#
# subscription
#

__PACKAGE__->select_all(
    'subscription',
    "SELECT * FROM subscription",
);

__PACKAGE__->select_row(
    'subscription_by_feed_id',
    user_id => 'Natural',
    feed_id => 'Natural',
    "SELECT * FROM subscription WHERE user_id = ? AND feed_id = ?",
);

__PACKAGE__->select_all(
    'subscription_by_feed_id_for_crawler',
    feed_id => 'Natural',
    "SELECT * FROM subscription WHERE feed_id = ?",
);

__PACKAGE__->select_all(
    'subscription_for_user',
    user_id => 'Natural',
    <<__SQL__
SELECT
    feed.id,
    feed.title,
    subscription.category_id,
    feed.http_status,
    feed.siteurl
FROM subscription
INNER JOIN feed ON feed_id = feed.id
WHERE subscription.user_id = ?
ORDER BY title ASC
__SQL__
);

__PACKAGE__->select_all(
    'subscription_feed_id_by_category',
    category_id => 'Natural',
    user_id => 'Natural',
    "SELECT feed_id FROM subscription WHERE category_id = ? AND user_id = ?"
);

__PACKAGE__->query(
    'delete_subscription',
    feed_id => 'Natural',
    user_id => 'Natural',
    "DELETE FROM subscription WHERE feed_id = ? AND user_id = ?"
);

__PACKAGE__->query(
    'insert_subscription',
    category_id => 'Natural',
    feed_id => 'Natural',
    user_id => 'Natural',
    "INSERT INTO subscription (category_id, feed_id, user_id) VALUES (?, ?, ?)"
);

__PACKAGE__->query(
    'update_subscription',
    category_id => 'Natural',
    feed_id => 'Natural',
    user_id => 'Natural',
    "UPDATE subscription SET category_id = ? WHERE feed_id = ? AND user_id = ?"
);

__PACKAGE__->query(
    'purge_old_entry_by_subscription',
    subscription_id => 'Natural',
    <<'__SQL__'
DELETE
FROM entry
WHERE subscription_id = :subscription_id
    AND readflag = 1
    AND update_at < DATE_ADD(CURRENT_TIMESTAMP, INTERVAL -1 DAY)
    AND
    pubdate NOT IN (SELECT pubdate FROM
        (SELECT pubdate FROM entry
            WHERE subscription_id = :subscription_id AND readflag = 1
            ORDER BY pubdate DESC LIMIT 1
        ) x )
__SQL__
);

#
# user
#

__PACKAGE__->select_row(
    'user_profile',
    id => 'Natural',
    "SELECT numentry, nopinlist, numsubstr FROM user WHERE id = ?",
);

__PACKAGE__->query(
    'update_user_profile',
    numentry => 'Uint',
    nopinlist => 'Uint',
    numsubstr => 'Uint',
    id => 'Natural',
    "UPDATE user SET numentry = ?, nopinlist = ?, numsubstr = ? WHERE id = ?"
);

__PACKAGE__->select_row(
    'user',
    id => 'Natural',
    "SELECT * FROM user WHERE id = ?",
);

__PACKAGE__->select_row(
    'user_by_name',
    name => 'Str',
    "SELECT * FROM user WHERE name = ?",
);

__PACKAGE__->query(
    'update_user_digest',
    digest => 'Str',
    id => 'Natural',
    "UPDATE user SET digest = ?  WHERE id = ?",
);

__PACKAGE__->query(
    'update_user_password',
    password => 'Str',
    id => 'Natural',
    "UPDATE user SET password = ?  WHERE id = ?",
);

__PACKAGE__->query(
    'update_user_last_login',
    id => 'Natural',
    "UPDATE user SET last_login = CURRENT_TIMESTAMP WHERE id = ?",
);

#
# story
#

__PACKAGE__->query(
    'insert_story',
    feed_id => 'Natural',
    serial => 'Natural',
    title => 'Str',
    description => 'Str',
    url => 'Str',
    <<__SQL__
INSERT IGNORE INTO story
(feed_id, serial, title, description, url)
VALUES
(?, ?, ?, ?, ?)
__SQL__
);

1;

