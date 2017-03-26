package Gion::Opml;

use strict;
use warnings;
use utf8;

use Encode;
use Time::Piece;
use XML::LibXML;

sub opml_export {
    my ($class, $r) = @_;
    $r->require_login;
    my $db = $r->dbh->dbh;
    my $category = $db->select_all("
        SELECT
            id,
            name
        FROM category
        WHERE user_id = ?
        ORDER BY name ASC
    ", $r->session->get('username'));

    my @records;
    for (@$category) {
        my $rs = $db->select_all("
            SELECT feed_id
            FROM target
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

    $r->res->headers->header('Content-Disposition' => 'attachment; filename=opml.xml;');
    $r->res->content_type('application/xml; charset=utf-8');
    $r->res->content(encode_utf8 $r->render("opml.xml", {records => \@records}));
}

sub opml_import {
    my ($class, $r) = @_;
    $r->require_login;
    my $file = $r->req->uploads->{file};
    unless ($file) {
        return $r->res->redirect('/#settings'); # XXX
    }

    my $db = $r->dbh->dbh;
    my $xml = XML::LibXML->new;
    my $dom = $xml->parse_file($file->path);

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
        ", $r->session->get('username'), $category);

        my $cid;
        unless (defined $crs->{id}) {
            $db->query("INSERT INTO category (id,user_id,name) VALUES (null,?,?)",
                $r->session->get('username'),
                $category
            );
            $crs = $db->select_row("
                SELECT *
                FROM category
                WHERE user_id = ?
                    AND name = ?
            ", $r->session->get('username'), $category);
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
            FROM target
            WHERE user_id = ?
                AND feed_id = ?
        ", $r->session->get('username'), $feedid);

        # skip already registered.
        if ( $rs->{t} ) {
            warn "already registered.";
            next;
        }

        # register.
        $db->query("INSERT INTO target (category_id,feed_id,user_id) VALUES (?,?,?);",
            $cid,
            $feedid,
            $r->session->get('username'),
        );
    }
    $r->res->redirect('/#settings'); # XXX
}

1;
