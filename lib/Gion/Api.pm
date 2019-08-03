package Gion::Api;

use strict;
use warnings;
use utf8;

use Encode;
use FormValidator::Lite;
use FormValidator::Lite::Constraint::URL;
use HTML::Scrubber;
use JSON::Types;
use Time::Piece;

use Gion::Util;

sub register_category {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check( name => ['NOT_NULL'], );
    return $r->json([]) if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($r->req->param($_))) } qw/name/;

    my $rs = $db->select_one("SELECT COUNT(*) FROM category WHERE user_id = ? AND name = ?",
        $r->session->get('username'),
        $values{name},
    );

    return $r->json({ result => "ERROR_ALREADY_REGISTER" }) if $rs > 0;

    $db->query("INSERT INTO category (id,user_id,name) VALUES (null,?,?)",
        $r->session->get('username'),
        $values{name},
    );

    $r->json({ result => "OK" });
}

sub register_subscription {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check(
        rss => [ 'HTTP_URL', 'NOT_NULL' ],
        url => [ 'HTTP_URL', 'NOT_NULL' ],
        title => ['NOT_NULL'],
        category => [ 'UINT', 'NOT_NULL' ],
    );
    return $r->json([]) if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($r->req->param($_))) } qw/rss url title category/;

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
        $r->session->get('username'),
        $feed
    );

    return $r->json({ result => "ERROR_ALREADY_REGISTER" }) if $rs > 0;

    $rs = $db->select_one("SELECT COUNT(*) FROM category WHERE user_id = ? AND id = ?",
        $r->session->get('username'),
        $values{category},
    );

    return if $rs == 0;

    $db->query("INSERT INTO subscription (category_id,feed_id,user_id) VALUES (?,?,?);",
        $values{category},
        $feed,
        $r->session->get('username')
    );

    $r->json({ result => "OK" });
}

sub examine_subscription {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new($r->req);
    $validator->check(
        url => [ 'HTTP_URL', 'NOT_NULL' ],
    );

    my ($success, $resource);
    if ($validator->is_valid) {
        ($success, $resource) = Gion::Util::examine_url($r->req->param('url'));
    }

    if ($success) {
        my ($parser_type, $result) = Gion::Util::preview_feed($resource->{url});
        if ($parser_type) {
            $resource->{parser_type}  = $parser_type;
            $resource->{preview_feed} = $result;
        }
    }

    $r->json($success ? $resource : { title => '', url => '', parser_type => 0, preview_feed => undef });
}

sub delete_it {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check(
        subscription => [ 'NOT_NULL', [ CHOICE => qw/category entry/ ] ],
        id => [ 'UINT', 'NOT_NULL' ],
    );
    return $r->json([]) if $validator->has_error;

    my %sql = (
        category => "DELETE FROM category WHERE id = ? AND user_id = ?",
        entry => "DELETE FROM subscription WHERE feed_id = ? AND user_id = ?"
    );

    my %values = map { $_ => decode_utf8(scalar($r->req->param($_))) } qw/id subscription/;

    my $db = $r->dbh;
    $db->query($sql{$values{subscription}}, $values{id}, $r->session->get('username'));
    $r->json({ r => "OK" });
}

sub change_it {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check(
        category => [ 'UINT', 'NOT_NULL' ],
        id => [ 'UINT', 'NOT_NULL' ],
    );
    return $r->json([]) if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($r->req->param($_))) } qw/id category/;

    my $db = $r->dbh;
    $db->query("UPDATE subscription SET category_id = ? WHERE feed_id = ? AND user_id = ?",
        $values{category},
        $values{id},
        $r->session->get('username')
    );

    $r->json({ r => "OK" });
}

sub get_numentry {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;
    my $rs = $db->select_row("SELECT numentry, noreferrer, nopinlist, numsubstr FROM user WHERE id = ?",
        $r->session->get('username')
    );

    $r->json({
        numentry => number $rs->{numentry},
        noreferrer => bool $rs->{noreferrer},
        nopinlist => bool $rs->{nopinlist},
        numsubstr => number $rs->{numsubstr},
    });
}

sub set_numentry {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check(
        numentry => [ 'UINT', 'NOT_NULL' ],
        noreferrer => [ 'UINT', 'NOT_NULL' ],
        nopinlist => [ 'UINT', 'NOT_NULL' ],
        numsubstr => [ 'UINT', 'NOT_NULL' ],
    );
    return $r->json([]) if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($r->req->param($_))) }
        qw/numentry noreferrer nopinlist numsubstr/;

    my $db = $r->dbh;
    $db->query("UPDATE user SET numentry = ?, noreferrer = ?, nopinlist = ?, numsubstr = ? WHERE id = ?",
        $values{numentry},
        $values{noreferrer},
        $values{nopinlist},
        $values{numsubstr},
        $r->session->get('username')
    );

    $r->json({ r => "OK" });
}

sub get_social_service {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;
    my $rs = $db->select_all("SELECT username , service FROM social_service WHERE user_id = ?",
        $r->session->get('username')
    );

    $r->json({ resource => $rs });
}

sub delete_social_service {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check(
        service => [ 'NOT_NULL' ],
    );
    return $r->json([]) if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($r->req->param($_))) } qw/service/;
    my $db = $r->dbh;
    $db->query("DELETE FROM social_service WHERE user_id = ? AND service = ?",
        $r->session->get('username'),
        $values{service},
    );

    $r->json({ r => "ok" });
}

sub get_category {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;

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
        ", $r->session->get('username'));

    my @response;
    foreach (@$rs) {
        push @response, {
            count   => number $_->{count},
            id      => number $_->{id},
            name    => string $_->{name},
        };
    }
    $r->json(\@response);
}

sub get_entry {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new( $r->req );
    my $res = $validator->check(
        category => [ 'NOT_NULL', 'UINT' ],
    );
    return $r->json([]) if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($r->req->param($_))) } qw/category/;
    my $id = $values{category};
    my $db = $r->dbh;

    if ( $id == 0 ) {
        my $rs = $db->select_one("
            SELECT
                category.id
            FROM entry
            INNER JOIN subscription ON subscription_id = subscription.id
            INNER JOIN category ON category.id = subscription.category_id
            WHERE readflag <> 1
                AND category.user_id = ?
            GROUP BY category.id
            ORDER BY category.name ASC
            LIMIT 1
        ", $r->session->get('username'));

        return $r->json([]) unless defined $rs;
        $id = $rs;
    }

    my $scrubber = HTML::Scrubber->new;
    my @info;
    my $count = 0;

    my $rs = $db->select_all("
        SELECT
            entry.guid,
            story.title,
            description,
            pubdate,
            readflag,
            story.url,
            subscription_id
        FROM entry
        INNER JOIN subscription ON subscription_id = subscription.id
        INNER JOIN story ON story.guid = entry.guid
        WHERE subscription.category_id = ?
            AND readflag <> 1
            AND entry.user_id = ?
        ORDER BY pubdate DESC
    ",
        $id,
        $r->session->get('username')
    );

    my $user_config = $db->select_row("SELECT * FROM user WHERE id = ?", $r->session->get('username'));

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
        $description = substr($description, 0, $user_config->{numsubstr}) if $user_config->{numsubstr} > 0;

        my %row = (
            guid        => $_->{guid},
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

    $r->json({
        entry => \@info,
        id => number $id,
    });
}

sub set_asread {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;

    my $payload = JSON->new->decode($r->req->content);
    for (@{$payload->{guid}}) {
        warn sprintf "ASREAD %s\t%s", $r->session->get('username'), $_ ;
        # XXX デバッグ時は以下SQLを抑止
        $db->query("
            UPDATE entry
            SET
                readflag = 1,
                update_at = CURRENT_TIMESTAMP
            WHERE readflag = 0
                AND user_id = ?
                AND guid = ?
        ", $r->session->get('username'), decode_utf8($_)
        );
    }
    $r->text("OK");
}

sub get_subscription {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;

    my $user_config = $db->select_row("SELECT * FROM user WHERE id = ?", $r->session->get('username'));

    my $category = $db->select_all("
        SELECT id, name
        FROM category
        WHERE user_id = ?
        ORDER BY name ASC
    ", $r->session->get('username')
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
    ", $r->session->get('username')
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
    $r->json({
        category => \@category,
        subscription => \@subscription
    });
}

sub get_pinlist {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;

    my $list = $db->select_all("
        SELECT
            story.title,
            story.url,
            entry.guid,
            entry.update_at
        FROM entry
        INNER JOIN subscription ON entry.subscription_id = subscription.id
        INNER JOIN story ON story.guid = entry.guid
        WHERE entry.readflag = 2
            AND subscription.user_id = ?
        ORDER BY pubdate DESC
    ", $r->session->get('username'));

    my $user_config = $db->select_row("SELECT * FROM user WHERE id = ?", $r->session->get('username'));

    return $r->json($list)
        if $user_config->{noreferrer} == 0;

    my @list_r;
    for my $row (@$list) {
        $row->{url} = Gion::Util::redirect_url($row->{url});
        push @list_r, $row;
    }
    $r->json(\@list_r);
}

sub set_pin {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check(
        readflag => [ 'NOT_NULL', 'UINT' ],
        pinid => ['NOT_NULL'],
    );
    return $r->json([]) if $validator->has_error;

    my $readflag = $r->req->param('readflag') == 2 ? 1 : 2;

    warn sprintf "PIN %s\t%s", $r->session->get('username'), $r->req->param('pinid');

    my %values = map { $_ => decode_utf8(scalar($r->req->param($_))) } qw/pinid/;

    my $db = $r->dbh;
    $db->query("
        UPDATE entry
        SET
            readflag = ?,
            update_at = CURRENT_TIMESTAMP
        WHERE user_id = ?
            AND guid = ?
    ",
        $readflag,
        $r->session->get('username'),
        $values{pinid},
    );
    $r->json({
        readflag => number $readflag,
    });
}

sub remove_all_pin {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;
    $db->query("
        UPDATE entry
        SET
            readflag = 1,
            update_at = CURRENT_TIMESTAMP
        WHERE readflag = 2
            AND user_id = ?
    ", $r->session->get('username'));

    $r->text('OK');
}

sub update_password {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new( $r->req );
    my $res = $validator->check(
        password_old => [ 'NOT_NULL', [qw/LENGTH 8 255/] ],
        { password => [qw/password passwordc/] } => ['DUPLICATION'],
        password => [ 'NOT_NULL', [qw/LENGTH 8 255/] ],
    );
    return $r->json({ result => 'error' }) if $validator->has_error;

    my $db = $r->dbh;
    my $user_config = $db->select_row("SELECT * FROM user WHERE id = ?", $r->session->get('username'));

    my $current = Gion::Util::auth(
        id => $user_config->{name},
        password => encode_utf8($r->req->param('password_old')),
    );

    return $r->json({ result => 'unmatch now password' })
      if $user_config->{password} ne $current;

    my $renew = Gion::Util::auth(
        id => $user_config->{name},
        password => encode_utf8($r->req->param('password')),
    );

    warn "Update Passwd: " . $renew . "," . $r->session->get('username');

    $db->query("
        UPDATE user
        SET password = ?
        WHERE id = ?
    ", $renew, $r->session->get('username'));

    $r->json({ result => 'update password' });
}

sub create_user {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_admin;
    $r->require_xhr;

    unless ($r->is_admin) {
        return $r->json({ result => 'you are not superuser.' });
    }

    my $validator = FormValidator::Lite->new( $r->req );
    my $res = $validator->check(
        username => ['NOT_NULL'],
        password => [ 'NOT_NULL', [qw/LENGTH 8 255/] ],
    );
    return $r->json({ result => 'error' }) if $validator->has_error;

    my $username = encode_utf8($r->req->param('username'));
    my $auth = Gion::Util::auth(
        id => $username,
        password => encode_utf8($r->req->param('password')),
    );

    my $db = $r->dbh;
    $db->query('
        INSERT INTO user (id,password,name) VALUES (null,?,?)
    ',
        $auth,
        $username,
    );
    $r->json({ result => "User Added: " . $username });
}

1;

