package Gion::Web::Opml;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::DOM;
use Encode;

sub export {
    my $self       = shift;
    my $db         = $self->app->dbh->dbh;
    my $categories = $db->select_all(
        "SELECT id, name FROM categories WHERE user = ? ORDER BY name ASC;",
        $self->session('username') );

    my $records;
    for (@$categories) {
        my $rs = $db->select_all(
            "SELECT _id_feeds FROM target WHERE _id_categories = ?",
            $_->{id}, );
        my $items;
        for (@$rs) {
            my $one = $db->select_row( "SELECT * FROM feeds WHERE id = ? ",
                $_->{_id_feeds} );
            my $h = {
                title   => $one->{title},
                siteurl => $one->{siteurl},
                url     => $one->{url},
            };
            push( @$items, $h );
        }
        push( @$records, { name => $_->{name}, items => $items } );
    }

    $self->stash( records => $records );

    $self->res->headers->content_disposition('attachment; filename=opml.xml;');
    $self->render;
}

sub import {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;
    my $file = $self->param('file');
    unless ($file) {
        return $self->redirect_to('settings');
    }
    my $dom = Mojo::DOM->new( $file->slurp );
    my $category;
    my $cid;
    my $feedid;
    for my $e ( $dom->find('outline')->each ) {
        unless ( $e->attr('type') ) {
            $category = decode_utf8( $e->attr('text') )
              if defined $e->attr('text');
        }
        if ( $e->attr('type') eq 'rss' ) {
            unless (defined $e->attr('htmlUrl')
                and defined $e->attr('xmlUrl')
                and defined $e->attr('title') )
            {
                warn "required parameter missing";
                next;
            }

            my $xmlUrl  = decode_utf8( $e->attr('xmlUrl') );
            my $htmlUrl = decode_utf8( $e->attr('htmlUrl') );

            $category = "Default Category" unless $category;

            # guess category id
            my $crs = $db->select_row(
                "SELECT * FROM categories WHERE user = ? AND name = ?",
                $self->session('username'), $category );
            unless ( defined $crs->{id} ) {
                $db->query(
                    "INSERT INTO categories (id,user,name) VALUES (null,?,?)",
                    $self->session('username'), $category );
                $crs = $db->select_row(
                    "SELECT * FROM categories WHERE user = ? AND name = ?",
                    $self->session('username'), $category );
                $cid = $crs->{id};
            }
            $cid = $crs->{id};

            # guess feed id
            my $feedrs = $db->select_row(
                "SELECT id FROM feeds WHERE url = ? AND siteurl = ? ",
                $xmlUrl, $htmlUrl );

            unless ( defined $feedrs->{id} ) {
                my $dt = Time::Piece->new;
                $db->query(
"INSERT INTO feeds (url,siteurl,title,http_status,pubDate) VALUES (?,?,?,0,?);",
                    $xmlUrl,
                    $htmlUrl,
                    decode_utf8( $e->attr('title') ),
                    $dt->epoch
                );
                $feedrs = $db->select_row(
                    "SELECT id FROM feeds WHERE url = ? AND siteurl = ? ",
                    $xmlUrl, $htmlUrl );
            }
            $feedid = $feedrs->{id};

            # already register ?
            my $rs = $db->select_row(
"SELECT COUNT(*) AS t FROM target WHERE user = ? AND _id_feeds = ?",
                $self->session('username'), $feedid
            );

            # skip already registered.
            if ( $rs->{t} ) {
                warn "already registered.";
                next;
            }

            # register.
            $db->query(
"INSERT INTO target (_id_categories,_id_feeds,user) VALUES (?,?,?);",
                $cid, $feedid, $self->session('username') );
        }
    }
    $self->redirect_to('settings');
}

1;
