package Gion::Api;

use strict;
use warnings;
use utf8;

use Encode;
use Encode::Guess qw/sjis euc-jp 7bit-jis/;
use FormValidator::Lite;
use FormValidator::Lite::Constraint::URL;
use Furl;
use HTML::Scrubber;
use Time::Piece;
use Try::Tiny;
use URI;
use XML::LibXML;

use Gion::Config;
use Gion::Util;

sub register_category {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh->dbh;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check( name => ['NOT_NULL'], );
    return $r->json([]) if $validator->has_error;

    my $rs = $db->select_row("SELECT COUNT(*) AS t FROM category WHERE user_id = ? AND name = ?",
        $r->session->get('username'),
        $r->req->param('name')
    );

    return $r->json({ r => "ERROR_ALREADY_REGISTER" }) if $rs->{t} > 0;

    $db->query("INSERT INTO category (id,user_id,name) VALUES (null,?,?)",
        $r->session->get('username'),
        $r->req->param('name')
    );

    $r->json({ r => "OK" });
}

sub register_target {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh->dbh;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check(
        rss => [ 'HTTP_URL', 'NOT_NULL' ],
        url => [ 'HTTP_URL', 'NOT_NULL' ],
        title => ['NOT_NULL'],
        cat => [ 'UINT',     'NOT_NULL' ],
    );
    return $r->json([]) if $validator->has_error;

    my $feed = $db->select_row("SELECT id FROM feed WHERE url = ? AND siteurl = ? ",
        $r->req->param('rss'),
        $r->req->param('url')
    );

    unless ( defined $feed->{id} ) {
        my $dt = Time::Piece->new;
        $db->query("INSERT INTO feed (url,siteurl,title,http_status,pubDate) VALUES (?,?,?,0,?);",
            $r->req->param('rss'),
            $r->req->param('url'),
            $r->req->param('title'),
            $dt->epoch
        );
        $feed = $db->select_row("SELECT id FROM feed WHERE url = ? AND siteurl = ? ",
            $r->req->param('rss'),
            $r->req->param('url')
        );
    }

    my $rs = $db->select_row("SELECT COUNT(*) AS t FROM target WHERE user_id = ? AND feed_id = ?",
        $r->session->get('username'),
        $feed->{id}
    );

    return $r->json({ r => "ERROR_ALREADY_REGISTER" }) if $rs->{t} > 0;

    $rs = $db->select_row("SELECT COUNT(*) AS t FROM category WHERE user_id = ? AND id = ?",
        $r->session->get('username'),
        $r->req->param('cat')
    );

    return if $rs->{t} == 0;

    $db->query("INSERT INTO target (category_id,feed_id,user_id) VALUES (?,?,?);",
        $r->req->param('cat'),
        $feed->{id},
        $r->session->get('username')
    );

    $r->json({ r => "OK" });
}

sub examine_target {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new($r->req);
    $validator->check(
        m => [ 'HTTP_URL', 'NOT_NULL' ],
    );

    my ($success, $resource);
    if ($validator->is_valid) {
        ($success, $resource) = $class->examine_url($r->req->param('m'));
    }
    
    $r->json($success ? $resource : { t => '', u => '' });
}

sub examine_url {
    my $class = shift;
    my $page_url = shift;

    my $res = Furl->new->get($page_url);

    return 0 unless defined $res;

    my $xml = XML::LibXML->new;
    $xml->recover_silently(1);

    my $doc;

    try {
        $doc = $xml->parse_html_string( $res->content );
    } catch {
        return 0;
    };

    return 0 unless defined $doc;

    my $title = $doc->findvalue('//title');

    try {
        my $decoder = Encode::Guess->guess( $res->content );
        die $decoder unless ref $decoder;
        $title = $decoder->decode($title);
    } catch {
        return 0;
    };

    $title =~ s/\r|\n//g;

    # ref. http://blog.livedoor.jp/dankogai/archives/51568463.html
    my $tmp = $doc->findvalue('/html/head/link[@type="application/rss+xml"][1]/@href');
    my $resource = $tmp ? $tmp : $doc->findvalue('/html/head/link[@type="application/atom+xml"][1]/@href');

    return 0 unless $resource;
    return 1, {
        t => $title,
        u => URI->new_abs( $resource, $page_url )->as_string
    };
}

sub delete_it {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check(
        target => [ 'NOT_NULL', [ CHOICE => qw/category entry/ ] ],
        id => [ 'UINT', 'NOT_NULL' ],
    );
    return $r->json([]) if $validator->has_error;

    my %sql = (
        category => "DELETE FROM category WHERE id = ? AND user_id = ?",
        entry => "DELETE FROM target WHERE feed_id = ? AND user_id = ?"
    );
    
    my $db = $r->dbh->dbh;
    $db->query($sql{$r->req->param('target')}, $r->req->param('id'), $r->session->get('username'));
    $r->json({ r => "OK" });
}

sub change_it {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check(
        cat => [ 'UINT', 'NOT_NULL' ],
        id => [ 'UINT', 'NOT_NULL' ],
    );
    return $r->json([]) if $validator->has_error;

    my $db = $r->dbh->dbh;
    $db->query("UPDATE target SET category_id = ? WHERE feed_id = ? AND user_id = ?",
        $r->req->param('cat'),
        $r->req->param('id'),
        $r->session->get('username')
    );

    $r->json({ r => "OK" });
}

sub get_numentry {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh->dbh;
    my $rs = $db->select_row("SELECT numentry, noreferrer, nopinlist, numsubstr FROM user WHERE id = ?",
        $r->session->get('username')
    );

    $r->json({
        r => $rs->{numentry},
        n => $rs->{noreferrer} ? 1 : 0,
        p => $rs->{nopinlist} ? 1 : 0,
        s => $rs->{numsubstr},
    });
}

sub set_numentry {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check(
        val => [ 'UINT', 'NOT_NULL' ],
        noref => [ 'UINT', 'NOT_NULL' ],
        nopin => [ 'UINT', 'NOT_NULL' ],
        substr => [ 'UINT', 'NOT_NULL' ],
    );
    return $r->json([]) if $validator->has_error;

    my $db = $r->dbh->dbh;
    $db->query("UPDATE user SET numentry = ?, noreferrer = ?, nopinlist = ?, numsubstr = ? WHERE id = ?",
        $r->req->param('val'),
        $r->req->param('noref'),
        $r->req->param('nopin'),
        $r->req->param('substr'),
        $r->session->get('username')
    );

    $r->json({ r => "OK" });
}

sub get_connect {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh->dbh;
    my $rs = $db->select_all("SELECT username , service FROM connection WHERE user_id = ?",
        $r->session->get('username')
    );

    $r->json({ e => $rs });
}

sub set_connect {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check(
        service => [ 'NOT_NULL' ],
    );
    return $r->json([]) if $validator->has_error;

    my $db = $r->dbh->dbh;
    $db->query("DELETE FROM connection WHERE user_id = ? AND service = ?",
        $r->session->get('username'),
        $r->req->param('service'),
    );

    $r->json({ r => "ok" });
}

sub redirect_url {
    my $url = shift;
    $url = encode( 'utf-8', $url );
    $url =~ s/([^0-9A-Za-z!'()*\-._~])/sprintf("%%%02X", ord($1))/eg;
    return config->param('redirector') . $url;
}

sub get_category {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;

    my $rs = $db->dbh->select_all("
        SELECT
            COUNT(0) AS c,
            category.id AS i,
            category.name AS n
        FROM entry
        INNER JOIN target ON entry.target_id = target.id
        INNER JOIN category ON target.category_id = category.id 
        WHERE readflag <> 1
            AND category.user_id = ?
        GROUP BY category.id
        ORDER BY category.name ASC
        ", $r->session->get('username'));

    $r->json($rs);
}

sub get_entry {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $validator = FormValidator::Lite->new( $r->req );
    my $res = $validator->check(
        cat => [ 'NOT_NULL', 'UINT' ],
    );
    return $r->json([]) if $validator->has_error;

    my $id = $r->req->param('cat');
    my $db = $r->dbh;

    if ( $id == 0 ) {
        my $rs = $db->dbh->select_row("
            SELECT
                category.id AS id
            FROM entry 
            INNER JOIN target ON target_id = target.id
            INNER JOIN category ON category.id = target.category_id
            WHERE readflag <> 1
                AND category.user_id = ? 
            GROUP BY category.id
            ORDER BY category.name ASC
            LIMIT 1
        ", $r->session->get('username'));

        return $r->json([]) unless defined $rs;
        $id = $rs->{id};
    }

    my $scrubber = HTML::Scrubber->new;
    my @info;
    my $count = 0;

    my $rs = $db->dbh->select_all("
        SELECT
            entry.guid,
            story.title,
            description, 
            pubDate,
            readflag,
            story.url,
            target_id
        FROM entry
        INNER JOIN target ON target_id = target.id
        INNER JOIN story ON story.guid = entry.guid
        WHERE target.category_id = ?
            AND readflag <> 1
            AND entry.user_id = ?
        ORDER BY pubDate DESC
    ",
        $id,
        $r->session->get('username')
    );

    my $user_config = $db->dbh->select_row("SELECT * FROM user WHERE id = ?", $r->session->get('username'));

    for (@$rs) {
        my $rs2 = $db->dbh->select_row("
            SELECT feed.title
            FROM target
            INNER JOIN feed ON target.feed_id = feed.id
            WHERE target.id = ?
        ", $_->{target_id});

        my $pd = Time::Piece->strptime($_->{pubDate}, '%Y-%m-%d %H:%M:%S')->strftime('%m/%d %H:%M');
        my $desc = $scrubber->scrub($_->{description});
        $desc = substr($desc, 0, $user_config->{numsubstr}) if $user_config->{numsubstr} > 0;

        my %row = (
            g => $_->{guid},
            t => $_->{title},
            d => $desc,
            p => $pd . " - " . $rs2->{title},
            r => $_->{readflag},
            u => $user_config->{noreferrer} ? redirect_url($_->{url}) : $_->{url},
            s => $_->{url},
        );
        push @info, \%row;

        if ( $user_config->{numentry} > 0 ) {
            $count++;
            last if $user_config->{numentry} == $count;
        }
    }

    $r->json({
        c => \@info,
        id => $id
    });
}

sub set_asread {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;

    my $payload = JSON->new->decode($r->req->content);
    for (@{$payload->{g}}) {
        warn sprintf "ASREAD %s\t%s", $r->session->get('username'), $_ ;
        # XXX デバッグ時は以下SQLを抑止
        $db->query("
            UPDATE entry
            SET
                readflag = 1,
                updatetime = CURRENT_TIMESTAMP
            WHERE readflag = 0
                AND user_id = ?
                AND guid = ?
        ", $r->session->get('username'), $_
        );
    }
    $r->text("OK");
}

sub get_targetlist {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;

    my $user_config = $db->dbh->select_row("SELECT * FROM user WHERE id = ?", $r->session->get('username'));

    my $category = $db->dbh->select_all("
        SELECT
            id AS i,
            name AS n
        FROM category
        WHERE user_id = ?
        ORDER BY name ASC
    ", $r->session->get('username')
    );

    my $rs = $db->dbh->select_all("
        SELECT
            feed.id,
            feed.title,
            target.category_id,
            feed.http_status,
            feed.siteurl 
        FROM target
        INNER JOIN feed ON feed_id = feed.id 
        WHERE target.user_id = ?
        ORDER BY title ASC
    ", $r->session->get('username')
    );

    my @hash_c;
    for (@$rs) {
        my %row = (
            i => $_->{id},
            n => $_->{title},
            c => $_->{category_id},
            r => $_->{http_status},
            h => $user_config->{noreferrer} ? redirect_url($_->{siteurl}) : $_->{siteurl},
        );
        push @hash_c, \%row;
    }
    $r->json({
        n => $category,
        t => \@hash_c
    });
}

sub get_pinlist {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;

    my $list = $db->dbh->select_all("
        SELECT
            story.title AS t,
            story.url AS u,
            entry.guid AS g,
            entry.updatetime AS m
        FROM entry
        INNER JOIN target ON entry.target_id = target.id
        INNER JOIN story ON story.guid = entry.guid
        WHERE entry.readflag = 2
            AND target.user_id = ?
        ORDER BY pubDate DESC
    ", $r->session->get('username'));

    my $user_config = $db->dbh->select_row("SELECT * FROM user WHERE id = ?", $r->session->get('username'));

    return $r->json($list)
        if $user_config->{noreferrer} == 0;

    my @list_r;
    for (@$list) {
        my $row = $_;
        $row->{u} = redirect_url($row->{u});
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
        flag => [ 'NOT_NULL', 'UINT' ],
        pinid => ['NOT_NULL'],
    );
    return $r->json([]) if $validator->has_error;

    my $flag = $r->req->param('flag') == 1 ? 2 : 1;

    warn sprintf "PIN %s\t%s", $r->session->get('username'), $r->req->param('pinid');

    my $db = $r->dbh;
    $db->dbh->query("
        UPDATE entry
        SET
            readflag = ?,
            updatetime = CURRENT_TIMESTAMP
        WHERE user_id = ?
            AND guid = ?
    ",
        $flag,
        $r->session->get('username'),
        $r->req->param('pinid'),
    );
    $r->text('OK');
}

sub remove_all_pin {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    my $db = $r->dbh;
    $db->dbh->query("
        UPDATE entry
        SET
            readflag = 1,
            updatetime = CURRENT_TIMESTAMP
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
    return $r->json({ e => 'error' }) if $validator->has_error;

    my $db = $r->dbh;
    my $user_config = $db->dbh->select_row("SELECT * FROM user WHERE id = ?", $r->session->get('username'));

    my $current = Gion::Util->auth(
        strech => config->param('strech'),
        salt => config->param('salt'),
        id => $user_config->{name},
        password => encode_utf8($r->req->param('password_old')),
    );

    return $r->json({ e => 'unmatch now password' })
      if $user_config->{password} ne $current;

    my $renew = Gion::Util->auth(
        strech => config->param('strech'),
        salt => config->param('salt'),
        id => $user_config->{name},
        password => encode_utf8($r->req->param('password')),
    );

    warn "Update Passwd: " . $renew . "," . $r->session->get('username');

    $db->dbh->query("
        UPDATE user
        SET password = ?
        WHERE id = ?
    ", $renew, $r->session->get('username'));

    $r->json({ e => 'update password' });
}

sub create_user {
    my ($class, $r) = @_;
    $r->require_login;
    $r->require_xhr;

    unless ($r->is_admin) {
        return $r->json({ e => 'you are not superuser.' });
    }

    my $validator = FormValidator::Lite->new( $r->req );
    my $res = $validator->check(
        username => ['NOT_NULL'],
        password => [ 'NOT_NULL', [qw/LENGTH 8 255/] ],
    );
    return $r->json({ e => 'error' }) if $validator->has_error;

    my $username = encode_utf8($r->req->param('username'));
    my $auth = Gion::Util->auth(
        strech => config->param('strech'),
        salt => config->param('salt'),
        id => $username,
        password => encode_utf8($r->req->param('password')),
    );

    my $db = $r->dbh;
    $db->dbh->query('
        INSERT INTO user (id,password,name) VALUES (null,?,?)
    ',
        $auth,
        $username,
    );
    $r->json({ e => "User Added: " . $username });
}

1;
