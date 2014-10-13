package Gion::Web::Subscription;
use Mojo::Base 'Mojolicious::Controller';
use LWP::UserAgent;
use FormValidator::Lite;
use FormValidator::Lite::Constraint::URL;
use URI;
use Encode;
use Encode::Guess qw/sjis euc-jp 7bit-jis/;
use XML::LibXML;
use URI::Fetch;
use Try::Tiny;

sub register_categories {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check(
        name => [ 'NOT_NULL' ],
    ); 
    return $self->render(json => [] ) if $validator->has_error;

    my $data = $self->req->params->to_hash;
    my $rs = $db->select_row(
        "SELECT COUNT(*) AS t FROM categories 
        WHERE user = ? AND name = ?",
        $self->session('username'),
        $data->{name});

    return $self->render( json => { r => "ERROR_ALREADY_REGISTER" } )
      if $rs->{t} > 0;

    $db->query(
        "INSERT INTO categories (id,user,name) VALUES (null,?,?)",
        $self->session('username'), $data->{name});

    $self->render( json => { r => "OK" } );
}

sub register_target {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check(
        rss => [ 'HTTP_URL', 'NOT_NULL' ],
        url => [ 'HTTP_URL', 'NOT_NULL' ],
        title => [ 'NOT_NULL' ],
        cat => [ 'UINT', 'NOT_NULL' ],
    ); 
    return $self->render(json => [] ) if $validator->has_error;
    my $data = $self->req->params->to_hash;

    my $rs = $db->select_row(
        "SELECT COUNT(tt.id) AS t FROM target AS tt
        INNER JOIN categories AS c ON _id_categories = c.id
        WHERE c.user = ? AND (url = ? OR siteurl = ?)",
        $self->session('username'), $data->{rss}, $data->{url});

    return $self->render( json => { r => "ERROR_ALREADY_REGISTER" } )
      if $rs->{t} > 0;

    $rs = $db->select_row(
        "SELECT COUNT(*) AS t FROM categories WHERE user = ? AND id = ?",
        $self->session('username'), $data->{cat});

    return if $rs->{t} == 0;

    $db->query(
        "INSERT INTO target (url,siteurl,title,_id_categories,http_status,user) VALUES (?,?,?,?,0,?);",
         $data->{rss}, $data->{url}, $data->{title}, $data->{cat}, $self->session('username'));

    $self->render( json => { r => "OK" } );
}

sub examine_target {
    my $self = shift;

    my $validator = FormValidator::Lite->new( $self->req );
    $validator->check(
        m => [ 'HTTP_URL', 'NOT_NULL' ],
    ); 
    return $self->render( json => { t => '', u => '' } )
        if $validator->has_error;

    my $data = $self->req->params->to_hash;

    my $res = URI::Fetch->fetch( $data->{m} );

    return $self->render( json => { t => '', u => '' } )
        unless defined $res;

    my $xml = XML::LibXML->new();
    $xml->recover_silently(1);

    my $url = "";
    my $doc;

    try {
        $doc = $xml->parse_html_string($res->content);
    }
    catch {
        return $self->render( json => { t => '', u => '' } );
    };

    return $self->render( json => { t => '', u => '' } )
        unless defined $doc;

    my $title = $doc->findvalue('//title');

    try {
        my $decoder = Encode::Guess->guess($res->content);
        die $decoder unless ref $decoder;
        warn $decoder->name;
        $title = $decoder->decode($title);
    }
    catch {
        return $self->render( json => { t => '', u => '' } );
    };

    $title = decode_utf8($title);
    $title =~ s/\r|\n//g;
    warn $title;

    # http://blog.livedoor.jp/dankogai/archives/51568463.html

    # RSS の場合
    $url =
      $doc->findvalue('/html/head/link[@type="application/rss+xml"][1]/@href');
    unless ( $url eq "" ) {
        return $self->render( json => { t => $title, 
            u => URI->new_abs( $url, $data->{m} )->as_string } );
    }

    # Atom の場合
    $url =
      $doc->findvalue('/html/head/link[@type="application/atom+xml"][1]/@href');
    unless ( $url eq "" ) {
        return $self->render( json => { t => $title,
            u => URI->new_abs( $url, $data->{m} )->as_string } );
    }

    #いかなる場合の失敗
    $self->render( json => { t => $title, u => '' } );
}

sub delete_it {
    my $self = shift;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check(
        target => [ 'NOT_NULL', [CHOICE => qw/category entry/] ],
        id => [ 'UINT', 'NOT_NULL' ],
    ); 
    return $self->render(json => [] ) if $validator->has_error;
 
    my $db   = $self->app->dbh->dbh;
    my $data = $self->req->params->to_hash;

    if ( $data->{target} eq 'category' ) {
        $db->query("DELETE FROM categories WHERE id = ? AND user = ?",
        $data->{id}, $self->session('username'));
    }
    elsif ( $data->{target} eq 'entry' ) {
        $db->query("DELETE FROM target WHERE id = ? AND user = ?;",
        $data->{id}, $self->session('username'));
    }
    $self->render( json => { r => "OK" } );
}

sub change_it {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check(
        cat => [ 'UINT', 'NOT_NULL' ],
        id  => [ 'UINT', 'NOT_NULL' ],
    ); 
    return $self->render(json => [] ) if $validator->has_error;
 
    my $data = $self->req->params->to_hash;

    $db->query("UPDATE target SET _id_categories = ? WHERE target.id = ? AND user = ?",
    $data->{cat}, $self->session('username'), $data->{id});

    return $self->render( json => { r => "OK" } );
}

sub get_numentry {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;
    my $rs   = $db->select_row(
    "SELECT numentry, noreferrer, nopinlist, numsubstr FROM user WHERE id = ?",
    $self->session('username'));

    $self->render(
        json => {
            r => $rs->{numentry},
            n => $rs->{noreferrer},
            p => $rs->{nopinlist},
            s => $rs->{numsubstr},
        }
    );
}

sub set_numentry {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;
    my $data = $self->req->params->to_hash;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check(
        val   => [ 'UINT', 'NOT_NULL' ],
        noref => [ 'UINT', 'NOT_NULL' ],
        nopin => [ 'UINT', 'NOT_NULL' ],
        substr => [ 'UINT', 'NOT_NULL' ],
    ); 
    return $self->render(json => [] ) if $validator->has_error;
 
    $db->query("UPDATE user SET numentry = ?, noreferrer = ?, nopinlist = ?, numsubstr = ? WHERE id = ?",
        $data->{val}, $data->{noref}, $data->{nopin}, $data->{substr}, $self->session('username'));

    $self->render( json => { r => "OK" } );
}

sub get_connect {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;
    my $rs   = $db->select_all(
        "SELECT username , service FROM connection WHERE user = ?",
        $self->session('username'));

    $self->render(json => { e => $rs } );
}

sub set_connect {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;
    my $data = $self->req->params->to_hash;
    $db->query("DELETE FROM connection WHERE user = ? AND service = ?",
    $self->session('username'), $data->{service});

    $self->render( json => "ok" );
}

sub opml {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;
    my $categories = $db->select_all(
        "SELECT id, name FROM categories WHERE user = ? ORDER BY name ASC;",
        $self->session('username'));

    my $records;
    for(@$categories){
        my $rs = $db->select_all(
            "SELECT title, siteurl, url FROM target WHERE _id_categories = ? ORDER BY title ASC",
            $_->{id},
        );
        my $items;
        for(@$rs){
            my $h = {
                title   => $_->{title},
                siteurl => $_->{siteurl},
                url     => $_->{url},
            };
            push( @$items, $h );
        }
        push( @$records, { name => $_->{name}, items => $items });
    }

    $self->stash(records => $records);

    $self->res->headers->content_disposition('attachment; filename=opml.xml;');
    $self->render;
}

1;
