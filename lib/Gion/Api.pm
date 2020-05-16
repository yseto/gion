package Gion::Api;

use strict;
use warnings;
use utf8;

use parent qw/Gion::Base/;

use Encode;
use FormValidator::Lite;
use FormValidator::Lite::Constraint::URL;
use HTML::Scrubber;
use JSON;
use JSON::Types;
use JSON::XS;
use Text::Xslate;
use Time::Piece;
use XML::LibXML;

use Gion::Authorizer::Api;
use Gion::Config;
use Gion::Util;

sub create_authorizer { Gion::Authorizer::Api->new(shift) }

sub user_id { shift->pad->param('user_id') }

sub dispatch_register_category {
    my $self = shift;

    my $db = $self->dbh;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check( name => ['NOT_NULL'], );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/name/;

    my $rs = $db->select_one("SELECT COUNT(*) FROM category WHERE user_id = ? AND name = ?",
        $self->user_id,
        $values{name},
    );

    return $self->json({ result => "ERROR_ALREADY_REGISTER" }) if $rs > 0;

    $db->query("INSERT INTO category (id,user_id,name) VALUES (null,?,?)",
        $self->user_id,
        $values{name},
    );

    $self->json({ result => "OK" });
}

sub dispatch_register_subscription {
    my $self = shift;

    my $db = $self->dbh;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check(
        rss => [ 'HTTP_URL', 'NOT_NULL' ],
        url => [ 'HTTP_URL', 'NOT_NULL' ],
        title => ['NOT_NULL'],
        category => [ 'UINT', 'NOT_NULL' ],
    );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/rss url title category/;

    my $feed = $db->select_one("SELECT id FROM feed WHERE url = ? AND siteurl = ? ",
        $values{rss},
        $values{url},
    );

    unless ( defined $feed ) {
        $db->query("INSERT INTO feed (url,siteurl,title,http_status,pubdate,cache) VALUES (?,?,?,0,NOW(),'{}');",
            $values{rss},
            $values{url},
            $values{title},
        );
        $feed = $db->select_one("SELECT id FROM feed WHERE url = ? AND siteurl = ? ",
            $values{rss},
            $values{url},
        );
    }

    my $rs = $db->select_one("SELECT COUNT(*) FROM subscription WHERE user_id = ? AND feed_id = ?",
        $self->user_id,
        $feed
    );

    return $self->json({ result => "ERROR_ALREADY_REGISTER" }) if $rs > 0;

    $rs = $db->select_one("SELECT COUNT(*) FROM category WHERE user_id = ? AND id = ?",
        $self->user_id,
        $values{category},
    );

    return if $rs == 0;

    $db->query("INSERT INTO subscription (category_id,feed_id,user_id) VALUES (?,?,?);",
        $values{category},
        $feed,
        $self->user_id
    );

    $self->json({ result => "OK" });
}

sub dispatch_examine_subscription {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    $validator->check(
        url => [ 'HTTP_URL', 'NOT_NULL' ],
    );

    my ($success, $resource);
    if ($validator->is_valid) {
        ($success, $resource) = Gion::Util::examine_url($self->req->param('url'));
    }

    if ($success) {
        my ($parser_type, $result) = Gion::Util::preview_feed($resource->{url});
        if ($parser_type) {
            $resource->{parser_type}  = $parser_type;
            $resource->{preview_feed} = $result;
        }
    }

    $self->json($success ? $resource : { title => '', url => '', parser_type => 0, preview_feed => undef });
}

sub dispatch_delete_it {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check(
        subscription => [ 'NOT_NULL', [ CHOICE => qw/category entry/ ] ],
        id => [ 'UINT', 'NOT_NULL' ],
    );
    return $self->bad_request if $validator->has_error;

    my %sql = (
        category => "DELETE FROM category WHERE id = ? AND user_id = ?",
        entry => "DELETE FROM subscription WHERE feed_id = ? AND user_id = ?"
    );

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/id subscription/;

    my $db = $self->dbh;
    $db->query($sql{$values{subscription}}, $values{id}, $self->user_id);
    $self->json({ r => "OK" });
}

sub dispatch_change_it {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check(
        category => [ 'UINT', 'NOT_NULL' ],
        id => [ 'UINT', 'NOT_NULL' ],
    );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/id category/;

    my $db = $self->dbh;
    $db->query("UPDATE subscription SET category_id = ? WHERE feed_id = ? AND user_id = ?",
        $values{category},
        $values{id},
        $self->user_id
    );

    $self->json({ r => "OK" });
}

sub dispatch_get_numentry {
    my $self = shift;

    my $db = $self->dbh;
    my $rs = $db->select_row("SELECT numentry, noreferrer, nopinlist, numsubstr FROM user WHERE id = ?",
        $self->user_id
    );

    $self->json({
        numentry => number $rs->{numentry},
        noreferrer => bool $rs->{noreferrer},
        nopinlist => bool $rs->{nopinlist},
        numsubstr => number $rs->{numsubstr},
    });
}

sub dispatch_set_numentry {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check(
        numentry => [ 'UINT', 'NOT_NULL' ],
        noreferrer => [ 'UINT', 'NOT_NULL' ],
        nopinlist => [ 'UINT', 'NOT_NULL' ],
        numsubstr => [ 'UINT', 'NOT_NULL' ],
    );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) }
        qw/numentry noreferrer nopinlist numsubstr/;

    my $db = $self->dbh;
    $db->query("UPDATE user SET numentry = ?, noreferrer = ?, nopinlist = ?, numsubstr = ? WHERE id = ?",
        $values{numentry},
        $values{noreferrer},
        $values{nopinlist},
        $values{numsubstr},
        $self->user_id
    );

    $self->json({ r => "OK" });
}

sub dispatch_get_category {
    my $self = shift;

    my $db = $self->dbh;

    my $rs = $db->select_all("
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
        ", $self->user_id);

    my @response;
    foreach (@$rs) {
        push @response, {
            count   => number $_->{count},
            id      => number $_->{id},
            name    => string $_->{name},
        };
    }
    $self->json(\@response);
}

sub dispatch_get_entry {
    my $self = shift;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check(
        category => [ 'NOT_NULL', 'UINT' ],
    );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/category/;
    my $db = $self->dbh;

    my $scrubber = HTML::Scrubber->new;
    my @info;
    my $count = 0;

    my $rs = $db->select_all("
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
    ",
        $values{category},
        $self->user_id
    );

    my $user_config = $db->select_row("SELECT * FROM user WHERE id = ?", $self->user_id);

    my %site_title;
    for (@$rs) {
        unless ($site_title{$_->{subscription_id}}) {
            my $rs2 = $db->select_one("
                SELECT feed.title
                FROM subscription
                INNER JOIN feed ON subscription.feed_id = feed.id
                WHERE subscription.id = ?
            ", $_->{subscription_id});
            $site_title{$_->{subscription_id}} = $rs2 || "";
        }

        my $pubdate = Time::Piece->strptime($_->{pubdate}, '%Y-%m-%d %H:%M:%S')->epoch;
        my $description = $scrubber->scrub($_->{description});
        $description =~ s/\s+/ /mg;
        $description = substr($description, 0, $user_config->{numsubstr}) if $user_config->{numsubstr} > 0;

        my %row = (
            serial      => number $_->{serial},
            feed_id     => number $_->{feed_id},
            title       => $_->{title},
            description => $description,
            date_epoch  => $pubdate,
            site_title  => $site_title{$_->{subscription_id}},
            readflag    => number $_->{readflag},
            url         => $user_config->{noreferrer} ? Gion::Util::redirect_url($_->{url}) : $_->{url},
            raw_url     => $_->{url},
        );
        push @info, \%row;

        if ( $user_config->{numentry} > 0 ) {
            $count++;
            last if $user_config->{numentry} == $count;
        }
    }

    $self->json(\@info);
}

sub dispatch_set_asread {
    my $self = shift;

    my $db = $self->dbh;

    my $payload = JSON->new->decode($self->req->content);
    for (@$payload) {
        warn sprintf "ASREAD U:%s\t feed_id:%s\t serial:%s\n",
             $self->user_id,
             $_->{feed_id},
             $_->{serial};

        # XXX デバッグ時は以下SQLを抑止
        $db->query("
            UPDATE entry
            SET
                readflag = 1,
                update_at = CURRENT_TIMESTAMP
            WHERE readflag = 0
                AND user_id = ?
                AND feed_id = ?
                AND serial = ?
        ",
        $self->user_id,
        $_->{feed_id},
        $_->{serial}
        );
    }
    $self->json({ result => JSON::true() });
}

sub dispatch_get_subscription {
    my $self = shift;

    my $db = $self->dbh;

    my $user_config = $db->select_row("SELECT * FROM user WHERE id = ?", $self->user_id);

    my $category = $db->select_all("
        SELECT id, name
        FROM category
        WHERE user_id = ?
        ORDER BY name ASC
    ", $self->user_id
    );

    my @category;
    for my $row (@$category) {
        push @category, {
            id => number $row->{id},
            name => string $row->{name},
        };
    }

    my $rs = $db->select_all("
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
    ", $self->user_id
    );

    my @subscription;
    for my $row (@$rs) {
        push @subscription, {
            siteurl => $user_config->{noreferrer} ?
                Gion::Util::redirect_url($row->{siteurl}) :
                $row->{siteurl},
            id      => number $row->{id},
            title   => $row->{title},
            category_id => number $row->{category_id},
            http_status => number $row->{http_status},
        };
    }
    $self->json({
        category => \@category,
        subscription => \@subscription
    });
}

sub dispatch_get_pinlist {
    my $self = shift;

    my $db = $self->dbh;

    my $list = $db->select_all("
        SELECT
            story.title,
            story.url,
            entry.serial,
            entry.feed_id,
            entry.update_at
        FROM entry
        INNER JOIN story ON story.serial = entry.serial AND story.feed_id = entry.feed_id
        WHERE entry.readflag = 2
            AND entry.user_id = ?
        ORDER BY pubdate DESC
    ", $self->user_id);

    my $user_config = $db->select_row("SELECT * FROM user WHERE id = ?", $self->user_id);

    return $self->json($list)
        if $user_config->{noreferrer} == 0;

    my @list_r;
    for my $row (@$list) {
        $row->{url} = Gion::Util::redirect_url($row->{url});
        push @list_r, $row;
    }
    $self->json(\@list_r);
}

sub dispatch_set_pin {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check(
        readflag => [ 'NOT_NULL', 'UINT' ],
        serial => ['NOT_NULL'],
        feed_id => ['NOT_NULL'],
    );
    return $self->bad_request if $validator->has_error;

    my $readflag = $self->req->param('readflag') == 2 ? 1 : 2;

    warn sprintf "PIN U:%s\tfeed_id:%s\tserial:%s\n",
        $self->user_id,
        $self->req->param('feed_id'),
        $self->req->param('serial');

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/feed_id serial/;

    my $db = $self->dbh;
    $db->query("
        UPDATE entry
        SET
            readflag = ?,
            update_at = CURRENT_TIMESTAMP
        WHERE user_id = ?
            AND serial = ?
            AND feed_id = ?
    ",
        $readflag,
        $self->user_id,
        $values{serial},
        $values{feed_id},
    );
    $self->json({
        readflag => number $readflag,
    });
}

sub dispatch_remove_all_pin {
    my $self = shift;

    my $db = $self->dbh;
    $db->query("
        UPDATE entry
        SET
            readflag = 1,
            update_at = CURRENT_TIMESTAMP
        WHERE readflag = 2
            AND user_id = ?
    ", $self->user_id);

    $self->json({ result => JSON::true() });
}

sub dispatch_update_password {
    my $self = shift;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check(
        password_old => [ 'NOT_NULL', [qw/LENGTH 8 255/] ],
        { password => [qw/password passwordc/] } => ['DUPLICATION'],
        password => [ 'NOT_NULL', [qw/LENGTH 8 255/] ],
    );
    return $self->json({ result => 'error' }) if $validator->has_error;

    my $db = $self->dbh;
    my $user_config = $db->select_row("SELECT * FROM user WHERE id = ?", $self->user_id);

    my $current = Gion::Util::auth(
        id => $user_config->{name},
        password => encode_utf8($self->req->param('password_old')),
    );

    return $self->json({ result => 'unmatch now password' })
      if $user_config->{password} ne $current;

    my $renew = Gion::Util::auth(
        id => $user_config->{name},
        password => encode_utf8($self->req->param('password')),
    );

    warn sprintf "Update Passwd: %s, %s\n", $renew, $self->user_id;

    $db->query("
        UPDATE user
        SET password = ?
        WHERE id = ?
    ", $renew, $self->user_id);

    $self->json({ result => 'update password' });
}

# opml

sub dispatch_opml_export {
    my $self = shift;

    my $db = $self->dbh;
    my $category = $db->select_all("
        SELECT
            id,
            name
        FROM category
        WHERE user_id = ?
        ORDER BY name ASC
    ", $self->user_id);

    my @records;
    for (@$category) {
        my $rs = $db->select_all("
            SELECT feed_id
            FROM subscription
            WHERE category_id = ?
        ", $_->{id});
        my @items;
        for (@$rs) {
            my $row = $db->select_row("SELECT title, siteurl, url FROM feed WHERE id = ?", $_->{feed_id});
            push @items, $row;
        }
        push @records, {
            name => $_->{name},
            items => \@items,
        };
    }

    my $xslate = Text::Xslate->new(
        syntax => 'TTerse',
        path => [ File::Spec->catdir(config->root,'templates') ],
    );

    my $xml = $xslate->render("opml.xml", { records => \@records });
    $self->json({ xml => $xml });
}

sub dispatch_opml_import {
    my $self = shift;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/xml/;

    my $db = $self->dbh;
    my $xml = XML::LibXML->new;
    my $dom = $xml->load_xml(string => $values{xml});

    my $category = "Default Category";
    for my $e ( $dom->findnodes('//outline') ) {
        if ( ($e->getAttribute('type') or '') ne 'rss' ) {
            $category = $e->getAttribute('text') ?
                $e->getAttribute('text') :
                "Default Category";
            next;
        }

        unless  (defined $e->getAttribute('htmlUrl')
            and defined $e->getAttribute('xmlUrl')
            and defined $e->getAttribute('title') )
        {
            warn "required parameter missing";
            next;
        }

        my $xmlUrl = $e->getAttribute('xmlUrl');
        my $htmlUrl = $e->getAttribute('htmlUrl');

        # guess category id
        my $crs = $db->select_row("
            SELECT *
            FROM category
            WHERE user_id = ?
                AND name = ?
        ", $self->user_id, $category);

        my $cid;
        unless (defined $crs->{id}) {
            $db->query("INSERT INTO category (id,user_id,name) VALUES (null,?,?)",
                $self->user_id,
                $category
            );
            $crs = $db->select_row("
                SELECT *
                FROM category
                WHERE user_id = ?
                    AND name = ?
            ", $self->user_id, $category);
            $cid = $crs->{id};
        }
        $cid = $crs->{id};

        # guess feed id
        my $feedrs = $db->select_row("
            SELECT id
            FROM feed
            WHERE url = ?
                AND siteurl = ?
        ", $xmlUrl, $htmlUrl);

        unless (defined $feedrs->{id}) {
            my $dt = Time::Piece->new;
            $db->query("INSERT INTO feed (url,siteurl,title,http_status,pubdate) VALUES (?,?,?,0,?);",
                $xmlUrl,
                $htmlUrl,
                $e->getAttribute('title'),
                $dt->epoch
            );
            $feedrs = $db->select_row("
                SELECT id
                FROM feed
                WHERE url = ?
                    AND siteurl = ?
            ", $xmlUrl, $htmlUrl);
        }
        my $feedid = $feedrs->{id};

        # already register ?
        my $rs = $db->select_row("
            SELECT
                COUNT(*) AS t
            FROM subscription
            WHERE user_id = ?
                AND feed_id = ?
        ", $self->user_id, $feedid);

        # skip already registered.
        if ( $rs->{t} ) {
            warn encode_utf8(sprintf("already registered : %s", $e->getAttribute('title')));
            next;
        }

        # register.
        $db->query("INSERT INTO subscription (category_id,feed_id,user_id) VALUES (?,?,?);",
            $cid,
            $feedid,
            $self->user_id,
        );
    }
    $self->json({ done => JSON::true });
}

1;

