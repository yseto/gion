package Gion::Gion::Subscription;
use Mojo::Base 'Mojolicious::Controller';
use LWP::UserAgent;
use URI;
use Encode;
use XML::LibXML;
use URI::Fetch;
use Try::Tiny;

sub register_categories {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $data = $self->req->params->to_hash;
    return unless defined $data->{name};
    return if $data->{name} eq '';

    my $rs = $db->execute(
"SELECT COUNT(*) AS t FROM categories WHERE user = :userid AND name = :name;",
        {
            name   => $data->{name},
            userid => $self->session('username'),
        }
    ) or die $db->error;

    return $self->render( json => { r => "ERROR_ALREADY_REGISTER" } )
      if $rs->fetch_hash->{t} > 0;

    $rs = $db->execute(
        "INSERT INTO categories (id,user,name) VALUES (null,:userid,:name);",
        {
            name   => $data->{name},
            userid => $self->session('username'),
        }
    ) or die $db->error;

    return $self->render( json => { r => "OK" } );
}

sub register_target {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $data = $self->req->params->to_hash;
    return unless defined $data->{rss};
    return unless $data->{rss} =~ "^http://|^https://";

    return unless defined $data->{url};
    return unless $data->{url} =~ "^http://|^https://";

    return unless defined $data->{title};
    return if $data->{title} eq '';

    return unless defined $data->{cat};
    return unless $data->{cat} =~ /[0-9]+/;

    my $rs = $db->execute(
        "SELECT COUNT(tt.id) AS t FROM target AS tt
INNER JOIN categories AS c ON _id_categories = c.id
WHERE c.user = :userid AND (url = :url OR siteurl = :siteurl);",
        {
            url     => $data->{rss},
            siteurl => $data->{url},
            userid  => $self->session('username'),
        }
    ) or die $db->error;

    return $self->render( json => { r => "ERROR_ALREADY_REGISTER" } )
      if $rs->fetch_hash->{t} > 0;

    $rs = $db->execute(
"SELECT COUNT(id) AS t FROM categories WHERE user = :userid AND id = :cat",
        {
            cat    => $data->{cat},
            userid => $self->session('username'),
        }
    ) or die $db->error;

    return if $rs->fetch_hash->{t} == 0;

    $rs = $db->execute(
"INSERT INTO target (url,siteurl,title,_id_categories) VALUES (:u,:s,:t,:i);",
        {
            u => $data->{rss},
            s => $data->{url},
            t => $data->{title},
            i => $data->{cat},

        }
    ) or die $db->error;

    return $self->render( json => { r => "OK" } );
}

sub examine_target {
    my $self = shift;
    my $data = $self->req->params->to_hash;
    return unless defined $data->{m};
    return unless $data->{m} =~ "^http://|^https://";

    my $res = URI::Fetch->fetch( $data->{m} );

    return $self->render( json => { t => '', u => '' } ) unless defined $res;

    my $xml = XML::LibXML->new();
    $xml->recover_silently(1);
    my $doc = $xml->parse_html_string( $res->content );

    my $url    = "";
    my $title  = "";
    my $newurl = "";

    $title = $doc->findvalue('/html/head/title');

    my $enc = find_encoding("utf-8");

    try {
        $enc->decode($title);
        $enc->encode($title);
    }
    catch {};

    $title = decode_utf8($title);
    $title =~ s/\r|\n//g;

    # http://blog.livedoor.jp/dankogai/archives/51568463.html

    # RSS の場合
    $url =
      $doc->findvalue('/html/head/link[@type="application/rss+xml"][1]/@href');
    $newurl = "" . URI->new_abs( $url, $data->{m} );
    unless ( $url eq "" ) {
        return $self->render( json => { t => $title, u => $newurl } );
    }

    # Atom の場合
    $url =
      $doc->findvalue('/html/head/link[@type="application/atom+xml"][1]/@href');
    $newurl = "" . URI->new_abs( $url, $data->{m} );
    unless ( $url eq "" ) {
        return $self->render( json => { t => $title, u => $newurl } );
    }

    #いかなる場合の失敗
    return $self->render( json => { t => $title, u => '' } );
}

sub delete_it {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $data = $self->req->params->to_hash;
    return unless defined $data->{target};
    return unless defined $data->{id};

    if ( $data->{target} eq 'category' ) {
        my $rs = $db->execute(
            "DELETE FROM categories WHERE id = :id AND user = :userid;",
            {
                id     => $data->{id},
                userid => $self->session('username'),
            }
        ) or die $db->error;
    }
    elsif ( $data->{target} eq 'entry' ) {
        my $rs = $db->execute(
"DELETE target FROM target INNER JOIN categories AS c ON _id_categories = c.id WHERE target.id = :id AND c.user = :userid;",
            {
                id     => $data->{id},
                userid => $self->session('username'),
            }
        ) or die $db->error;
    }
    return $self->render( json => { r => "OK" } );
}

sub change_it {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $data = $self->req->params->to_hash;
    return unless defined $data->{id};
    return unless defined $data->{cat};

    my $rs = $db->execute(
        "UPDATE target 
                INNER JOIN categories AS c ON _id_categories = c.id
        SET target._id_categories = :cat 
        WHERE target.id = :id AND c.user = :userid ;",
        {
            cat    => $data->{cat},
            id     => $data->{id},
            userid => $self->session('username'),
        }
    ) or die $db->error;

    return $self->render( json => { r => "OK" } );
}

sub get_numentry {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $rs   = $db->execute(
        "SELECT 
        numentry,
        noreferrer,
        nopinlist
        FROM user WHERE id = :userid;",
        {
            userid => $self->session('username'),
        }
      )->fetch_hash
      or die $db->error;
    return $self->render(
        json => {
            r => $rs->{numentry},
            n => $rs->{noreferrer},
            p => $rs->{nopinlist},
        }
    );
}

sub set_numentry {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $data = $self->req->params->to_hash;
    return unless defined $data->{val};
    return unless $data->{val} =~ /^[0-9]*$/;
    return unless $data->{val} >= 0;
    my $rs = $db->execute(
        "UPDATE user SET 
        numentry = :val,
        noreferrer = :noref,
        nopinlist = :nopin
        WHERE id = :userid;",
        {
            userid => $self->session('username'),
            val    => $data->{val},
            noref  => $data->{noref},
            nopin  => $data->{nopin},
        }
    ) or die $db->error;
    return $self->render( json => { r => "OK" } );
}

sub get_connect {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $rs   = $db->execute(
        "SELECT username , service FROM connection WHERE user = :userid;",
        { userid => $self->session('username'), } );
    my $hash;
    for(@{ $rs->all }){ push(@$hash,{username => $_->{username}, service => $_->{service}});}
    $self->render(json => {e => $hash} );
}

sub set_connect {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $data = $self->req->params->to_hash;
    my $rs   = $db->execute(
        "DELETE FROM connection WHERE user = :userid AND service = :service;",
        { userid => $self->session('username'), service => $data->{service} } );
    return $self->render( json => "ok" );
}


1;
