use strict;
use warnings;
use utf8;

use Data::Section::Simple qw(get_data_section);
use HTTP::Date;
use JSON::XS;
use Test::More;
use Test::mysqld;
use Time::Piece;
use File::Slurp;

use Gion::Config;
use Gion;
use Gion::Crawler::Feed;

$ENV{PLACK_ENV} = 'test';

my $mysqld = Test::mysqld->new;
my $dsn = $mysqld->dsn;

my $guard = config->local(db => {dsn => $dsn}); 

# load schema.
my $dbh = DBI->connect($dsn);
my $source = read_file('config/mysql.sql');
for my $stmt (split /;/, $source) {
    next unless $stmt =~ /\S/;
    $dbh->do($stmt) or die $dbh->errstr;
}

for my $stmt (split /;/, get_data_section('table')) {
    next unless $stmt =~ /\S/;
    $dbh->do($stmt) or die $dbh->errstr;
}

my $db = Gion->cli_dbh;

my $feed_model = Gion::Crawler::Feed->new(
    db => $db,
    verbose => 1,
);

subtest 'load', sub {
    my $feed = $db->select_row('SELECT * FROM feed WHERE id = 22');
    $feed_model->load(%$feed);
    for (keys %$feed) {
        is $feed_model->$_, $feed->{$_}, $_;
    }
};

subtest 'catch_error', sub {
    my $feed = $db->select_row('SELECT * FROM feed WHERE id = 22');
    $feed_model->load(%$feed);
    $feed_model->catch_error(response => {});

    my $check = $db->select_row('SELECT * FROM feed WHERE id = 22');

    is $check->{http_status}, 404;
    is $check->{term}, 4;
    is $check->{cache}, '{}';

    for (keys %$feed) {
        is $feed_model->$_, $check->{$_}, $_;
    }
};

subtest 'catch_redirect', sub {
    my $feed = $db->select_row('SELECT * FROM feed WHERE id = 22');
    $feed_model->load(%$feed);

    is $feed_model->url, 'http://www.example.com/feed.xml';

    my $new_location = 'http://www.example.com/feed/feed.xml';

    $feed_model->catch_redirect(
        location => $new_location,
    );

    my $check = $db->select_row('SELECT * FROM feed WHERE id = 22');
    is $check->{url}, $new_location;

    for (keys %$feed) {
        is $feed_model->$_, $check->{$_}, $_;
    }
};

subtest 'catch_notmodified', sub {
    my $feed = $db->select_row('SELECT * FROM feed WHERE id = 22');
    $feed_model->load(%$feed);

    my $t = Time::Piece->new->strftime('%Y-%m-%d %H:%M:%S');
    $feed_model->pubdate($t);

    my %header = (
        'If-Modified-Since' => time2str(),
    );
    $feed_model->catch_notmodified(response => \%header);

    my $check = $db->select_row('SELECT * FROM feed WHERE id = 22');

    is $check->{http_status}, 304;
    is $check->{term}, 1;
    is $check->{cache}, encode_json(\%header);

    for (grep { $_ ne 'pubdate' } keys %$feed) {
        is $feed_model->$_, $check->{$_}, $_;
    }

};

subtest 'catch_parse_error', sub {
    my $feed = $db->select_row('SELECT * FROM feed WHERE id = 22');
    $feed_model->load(%$feed);

    my %header = (
        'If-Modified-Since' => time2str(),
    );
    $feed_model->catch_parse_error(
        response => \%header,
        code => 500,
    );

    my $check = $db->select_row('SELECT * FROM feed WHERE id = 22');

    is $check->{http_status}, 500;
    is $check->{parser}, 0;
    is $check->{term}, 1;
    is $check->{cache}, encode_json(\%header);

    for (keys %$feed) {
        is $feed_model->$_, $check->{$_}, $_;
    }
};

subtest 'update_feed_info defined term', sub {
    my $feed = $db->select_row('SELECT * FROM feed WHERE id = 22');
    $feed_model->load(%$feed);

    my %header = (
        'If-Modified-Since' => time2str(),
    );

    my $t = Time::Piece->new;

    $feed_model->update_feed_info(
        response => \%header,
        code => 200,
        last_modified => $t->epoch,
        term => 2,
    );

    my $check = $db->select_row('SELECT * FROM feed WHERE id = 22');

    is $check->{http_status}, 200;
    is $check->{pubdate}, $t->strftime('%Y-%m-%d %H:%M:%S');
    is $check->{term}, 2;
    is $check->{cache}, encode_json(\%header);

    for (keys %$feed) {
        is $feed_model->$_, $check->{$_}, $_;
    }
};

subtest 'update_feed_info undefined term', sub {
    my $feed = $db->select_row('SELECT * FROM feed WHERE id = 22');
    $feed_model->load(%$feed);

    my %header = (
        'If-Modified-Since' => time2str(),
    );

    my $t = Time::Piece->new;

    $feed_model->update_feed_info(
        response => \%header,
        code => 202,
        last_modified => $t->epoch,
    );

    my $check = $db->select_row('SELECT * FROM feed WHERE id = 22');

    is $check->{http_status}, 202;
    is $check->{pubdate}, $t->strftime('%Y-%m-%d %H:%M:%S');
    is $check->{term}, 1;
    is $check->{cache}, encode_json(\%header);

    for (keys %$feed) {
        is $feed_model->$_, $check->{$_}, $_;
    }
};


subtest 'update_parser', sub {
    my $feed = $db->select_row('SELECT * FROM feed WHERE id = 22');
    $feed_model->load(%$feed);

    $feed_model->update_parser(parser => 2);

    my $check = $db->select_row('SELECT * FROM feed WHERE id = 22');

    is $check->{parser}, 2;

    for (keys %$feed) {
        is $feed_model->$_, $check->{$_}, $_;
    }
};

subtest 'get_cache/set_cache', sub {
    my $feed = $db->select_row('SELECT * FROM feed WHERE id = 22');
    $feed_model->load(%$feed);

    $feed_model->set_cache({});
    is_deeply $feed_model->get_cache, {};

    $feed_model->cache(undef);
    my $t = $feed_model->get_cache;

    ok(not defined $t);

    my %header = (
        'If-Modified-Since' => time2str(),
    );
    $feed_model->set_cache(\%header);
    is_deeply $feed_model->get_cache, \%header;
};

subtest 'update_term', sub {
    my $t = time;
    is Gion::Crawler::Feed::update_term(), 1;
    is Gion::Crawler::Feed::update_term($t - 12*3600), 1;
    is Gion::Crawler::Feed::update_term($t - 13*3600), 2;
    is Gion::Crawler::Feed::update_term($t - 4*86400), 2;
    is Gion::Crawler::Feed::update_term($t - 5*86400), 3;
    is Gion::Crawler::Feed::update_term($t - 7*86400), 3;
    is Gion::Crawler::Feed::update_term($t - 8*86400), 4;
    is Gion::Crawler::Feed::update_term($t - 14*86400), 4;
    is Gion::Crawler::Feed::update_term($t - 15*86400), 5;
};

use Data::Dumper;

subtest 'parse_rss 1', sub {
    my $text = get_data_section('rss');
    my @entries = $feed_model->parse_rss($text);

    is scalar(@entries), 1;
    is $entries[0]->title, 'あいうえお';
    is $entries[0]->url, 'http://www.example.com/452275619.html';
    is $entries[0]->description, 'blah...';
    is $entries[0]->guid, 'http://www.example.com/452275619.html';
    is $entries[0]->pubdate_epoch, 1501381353;

    $entries[0]->insert_entry(
        target_id => 110,
        user_id => 1,
    );

    my $entry = $db->select_row('SELECT * FROM entry');

    delete $entry->{update_at};
    is_deeply $entry, {
      'guid' => 'http://www.example.com/452275619.html',
      'pubdate' => '2017-07-30 11:22:33',
      'readflag' => 0,
      'target_id' => 110,
      'user_id' => 1,
    };
};

subtest 'parse_rss 2', sub {
    my $text = get_data_section('rss2');
    my @entries = $feed_model->parse_rss($text);

    is scalar(@entries), 1;
    is $entries[0]->title, 'あいうえおあいうえお';
    is $entries[0]->url, 'http://www.example.com/452275619.html';
    is $entries[0]->description, 'blah...';
    is $entries[0]->guid, 'blog:example/452275619';
    is $entries[0]->pubdate_epoch, 1501381353;
};

subtest 'parse_atom', sub {
    my $text = get_data_section('atom');
    my @entries = $feed_model->parse_atom($text);

    is scalar(@entries), 1;
    is $entries[0]->title, 'たいとる';
    is $entries[0]->url, 'http://example.com/1.html';
    is $entries[0]->description, 'blah.....';
    is $entries[0]->guid, 'http://example.com/1.html';
    is $entries[0]->pubdate_epoch, 1501456320;
};

done_testing;

__DATA__

@@ table

INSERT INTO user (id, password, name) VALUES (null, 'xxxxx', 'admin');

LOCK TABLES `category` WRITE;
INSERT INTO `category` VALUES
(1,1,'category1'),
(2,1,'category2')
;
UNLOCK TABLES;

LOCK TABLES `feed` WRITE;
INSERT INTO `feed` VALUES 
(22,'http://www.example.com/feed.xml','http://www.example.com/','test feed','2017-01-01 12:34:56','200','1','2017-07-30 00:00:00','1','{}'),
(23,'http://www.example.com/feed2.xml','http://www.example.com/','test feed','2017-01-01 12:34:56','200','1','2017-07-30 00:00:00','1','{}')
;
UNLOCK TABLES;

LOCK TABLES `target` WRITE;
INSERT INTO `target` VALUES
(110,1,22,1),
(111,2,23,1)
;
UNLOCK TABLES;

@@ rss
<?xml version="1.0" encoding="UTF-8"?>

<rdf:RDF
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:content="http://purl.org/rss/1.0/modules/content/"
  xmlns="http://purl.org/rss/1.0/"
>

<channel rdf:about="http://www.example.com/">
<title>feed</title>
<link>http://www.example.com/</link>
<description>feed description</description>
<dc:language>ja</dc:language>
<items>
<rdf:Seq>
<rdf:li rdf:resource="http://www.example.com/452275619.html" />
</rdf:Seq>
</items>
</channel>

<item rdf:about="http://www.example.com/452275619.html">
<link>http://www.example.com/452275619.html</link>
<title>あいうえお</title>
<description>blah...</description>
<dc:subject>title</dc:subject>
<dc:creator>hogehoge</dc:creator>
<dc:date>2017-07-30T11:22:33+09:00</dc:date>
<content:encoded><![CDATA[
blah blah blah.
]]></content:encoded>
</item>
</rdf:RDF>

@@ rss2
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>feed</title>
    <link>http://www.example.com/</link>
    <description>feed description</description>
    <language>ja</language>
    <item>
      <link>http://www.example.com/452275619.html</link>
      <title>あいうえおあいうえお</title>
      <pubDate>Sun, 30 Jul 2017 11:22:33 +0900</pubDate>
      <description>blah...</description>
      <content:encoded><![CDATA[
blah blah blah blah ....
]]></content:encoded>
      <category>カテゴリ</category>
      <author>writer</author>
      <guid isPermaLink="false">blog:example/452275619</guid>
    </item>
  </channel>
</rss>

@@ atom
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
	<title>はははは</title>
	<link href="http://example.com/" />
	<link href="http://example.com/atom.xml" rel="self" />
	<updated>2017-07-31T11:22:33+09:00</updated>
	<author>
		<name>WHOAMI</name>
	</author>
	<id>http://example.com/</id>
	<entry>
		<title>たいとる</title>
		<link href="http://example.com/1.html" />
		<updated>2017-07-31T08:12:00+09:00</updated>
		<summary>blah.....</summary>
		<id>https://example.com/1.html</id>
		<content type="html">
&lt;h3&gt;あいうえお&lt;/h3&gt;
</content>
	</entry>
</feed>

