package Gion::Web::Subscription;
use Mojo::Base 'Mojolicious::Controller';
use FormValidator::Lite;
use FormValidator::Lite::Constraint::URL;
use URI;
use Encode;
use Encode::Guess qw/sjis euc-jp 7bit-jis/;
use XML::LibXML;
use Try::Tiny;
use Time::Piece;
use HTTP::Request;
use Furl;

sub register_category {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check( name => ['NOT_NULL'], );
    return $self->render( json => [] ) if $validator->has_error;

    my $data = $self->req->params->to_hash;
    my $rs   = $db->select_row(
        "SELECT COUNT(*) AS t FROM category 
        WHERE user_id = ? AND name = ?",
        $self->session('username'),
        $data->{name}
    );

    return $self->render( json => { r => "ERROR_ALREADY_REGISTER" } )
      if $rs->{t} > 0;

    $db->query(
        "INSERT INTO category (id,user_id,name) VALUES (null,?,?)",
        $self->session('username'),
        $data->{name}
    );

    $self->render( json => { r => "OK" } );
}

sub register_target {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res       = $validator->check(
        rss   => [ 'HTTP_URL', 'NOT_NULL' ],
        url   => [ 'HTTP_URL', 'NOT_NULL' ],
        title => ['NOT_NULL'],
        cat   => [ 'UINT',     'NOT_NULL' ],
    );
    return $self->render( json => [] ) if $validator->has_error;
    my $data = $self->req->params->to_hash;

    my $feed =
      $db->select_row( "SELECT id FROM feed WHERE url = ? AND siteurl = ? ",
        $data->{rss}, $data->{url} );

    unless ( defined $feed->{id} ) {
        my $dt = Time::Piece->new;
        $db->query(
"INSERT INTO feed (url,siteurl,title,http_status,pubDate) VALUES (?,?,?,0,?);",
            $data->{rss}, $data->{url}, $data->{title}, $dt->epoch );

        $feed = $db->select_row(
            "SELECT id FROM feed WHERE url = ? AND siteurl = ? ",
            $data->{rss}, $data->{url} );
    }

    my $rs = $db->select_row(
        "SELECT COUNT(*) AS t FROM target WHERE user_id = ? AND feed_id = ?",
        $self->session('username'),
        $feed->{id}
    );

    return $self->render( json => { r => "ERROR_ALREADY_REGISTER" } )
      if $rs->{t} > 0;

    $rs = $db->select_row(
        "SELECT COUNT(*) AS t FROM category WHERE user_id = ? AND id = ?",
        $self->session('username'),
        $data->{cat}
    );

    return if $rs->{t} == 0;

    $db->query(
        "INSERT INTO target (category_id,feed_id,user_id) VALUES (?,?,?);",
        $data->{cat}, $feed->{id}, $self->session('username') );

    $self->render( json => { r => "OK" } );
}

sub examine_target {
    my $self = shift;

    my $validator = FormValidator::Lite->new( $self->req );
    $validator->check( m => [ 'HTTP_URL', 'NOT_NULL' ], );
    return $self->render( json => { t => '', u => '' } )
      if $validator->has_error;

    my $data = $self->req->params->to_hash;
    my $res = Furl->new->get( $data->{m} );

    return $self->render( json => { t => '', u => '' } )
      unless defined $res;

    my $xml = XML::LibXML->new();
    $xml->recover_silently(1);

    my $url = "";
    my $doc;

    try {
        $doc = $xml->parse_html_string( $res->content );
    }
    catch {
        return $self->render( json => { t => '', u => '' } );
    };

    return $self->render( json => { t => '', u => '' } )
      unless defined $doc;

    my $title = $doc->findvalue('//title');

    try {
        my $decoder = Encode::Guess->guess( $res->content );
        die $decoder unless ref $decoder;

        #warn $decoder->name;
        $title = $decoder->decode($title);
    }
    catch {
        return $self->render( json => { t => '', u => '' } );
    };

#   $title = decode_utf8($title);
    $title =~ s/\r|\n//g;

    #warn $title;

    # http://blog.livedoor.jp/dankogai/archives/51568463.html

    # RSS の場合
    $url = $doc->findvalue('/html/head/link[@type="application/rss+xml"][1]/@href');
    unless ( $url eq "" ) {
        return $self->render(
            json => {
                t => $title,
                u => URI->new_abs( $url, $data->{m} )->as_string
            }
        );
    }

    # Atom の場合
    $url = $doc->findvalue('/html/head/link[@type="application/atom+xml"][1]/@href');
    unless ( $url eq "" ) {
        return $self->render(
            json => {
                t => $title,
                u => URI->new_abs( $url, $data->{m} )->as_string
            }
        );
    }

    #いかなる場合の失敗
    $self->render( json => { t => $title, u => '' } );
}

sub delete_it {
    my $self = shift;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res       = $validator->check(
        target => [ 'NOT_NULL', [ CHOICE => qw/category entry/ ] ],
        id => [ 'UINT', 'NOT_NULL' ],
    );
    return $self->render( json => [] ) if $validator->has_error;

    my $db   = $self->app->dbh->dbh;
    my $data = $self->req->params->to_hash;

    if ( $data->{target} eq 'category' ) {
        $db->query( "DELETE FROM category WHERE id = ? AND user_id = ?",
            $data->{id}, $self->session('username') );
    }
    elsif ( $data->{target} eq 'entry' ) {
        $db->query( "DELETE FROM target WHERE feed_id = ? AND user_id = ?;",
            $data->{id}, $self->session('username') );
    }
    $self->render( json => { r => "OK" } );
}

sub change_it {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res       = $validator->check(
        cat => [ 'UINT', 'NOT_NULL' ],
        id  => [ 'UINT', 'NOT_NULL' ],
    );
    return $self->render( json => [] ) if $validator->has_error;

    my $data = $self->req->params->to_hash;

    $db->query(
        "UPDATE target SET category_id = ? WHERE feed_id = ? AND user_id = ?",
        $data->{cat}, $data->{id}, $self->session('username') );

    return $self->render( json => { r => "OK" } );
}

sub get_numentry {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;
    my $rs   = $db->select_row(
"SELECT numentry, noreferrer, nopinlist, numsubstr FROM user WHERE id = ?",
        $self->session('username')
    );

    $self->render(
        json => {
            r => $rs->{numentry},
            n => $rs->{noreferrer} ? 1 : 0,
            p => $rs->{nopinlist} ? 1 : 0,
            s => $rs->{numsubstr},
        }
    );
}

sub set_numentry {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;
    my $data = $self->req->params->to_hash;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res       = $validator->check(
        val    => [ 'UINT', 'NOT_NULL' ],
        noref  => [ 'UINT', 'NOT_NULL' ],
        nopin  => [ 'UINT', 'NOT_NULL' ],
        substr => [ 'UINT', 'NOT_NULL' ],
    );
    return $self->render( json => [] ) if $validator->has_error;

    $db->query(
"UPDATE user SET numentry = ?, noreferrer = ?, nopinlist = ?, numsubstr = ? WHERE id = ?",
        $data->{val}, $data->{noref}, $data->{nopin}, $data->{substr},
        $self->session('username') );

    $self->render( json => { r => "OK" } );
}

sub get_connect {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;
    my $rs   = $db->select_all(
        "SELECT username , service FROM connection WHERE user_id = ?",
        $self->session('username') );

    $self->render( json => { e => $rs } );
}

sub set_connect {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;
    my $data = $self->req->params->to_hash;
    $db->query(
        "DELETE FROM connection WHERE user_id = ? AND service = ?",
        $self->session('username'),
        $data->{service}
    );

    $self->render( json => "ok" );
}

1;
