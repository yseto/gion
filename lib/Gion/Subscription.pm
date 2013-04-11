package Gion::Subscription;
use Mojo::Base 'Mojolicious::Controller';
use v5.12;

sub register_categories {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $data = $self->req->params->to_hash;
    exit() unless defined $data->{name};
    exit() if $data->{name} eq '';

    my $rs = $db->execute(
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
    exit() unless defined $data->{rss};
    exit() unless $data->{rss} =~ "^http://|^https://";

    exit() unless defined $data->{url};
    exit() unless $data->{url} =~ "^http://|^https://";

    exit() unless defined $data->{title};
    exit() if $data->{title} eq '';

    exit() unless defined $data->{cat};
    exit() unless $data->{cat} =~ /[0-9]+/;

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

    exit() if $rs->fetch_hash->{t} > 0;

    $rs = $db->execute(
"SELECT COUNT(id) AS t FROM categories WHERE user = :userid AND id = :cat",
        {
            cat    => $data->{cat},
            userid => $self->session('username'),
        }
    ) or die $db->error;

    exit() if $rs->fetch_hash->{t} == 0;

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
    exit() unless defined $data->{m};
    exit() unless $data->{m} =~ "^http://|^https://";

    use URI::Fetch;
    my $res = URI::Fetch->fetch( $data->{m} );

    use XML::LibXML;
    my $xml = XML::LibXML->new();
    $xml->recover_silently(1);
    my $doc = $xml->parse_html_string( $res->content );

    my $url    = "";
    my $title  = "";
    my $newurl = "";

    $title = $doc->findvalue('/html/head/title');

    use Encode;
    use Try::Tiny;
    my $enc = find_encoding("utf-8");

    try {
        $enc->decode($title);
        $enc->encode($title);
    } catch {};
    
    $title = decode_utf8($title);
    $title =~ s/\r|\n//g;

    # http://blog.livedoor.jp/dankogai/archives/51568463.html
    use LWP::UserAgent;
    use URI;

    # RSS の場合
    $url =
      $doc->findvalue('/html/head/link[@type="application/rss+xml"][1]/@href');
    $newurl = "" . URI->new_abs( $url, $data->{m} );
    unless ( $url eq "" ) {
        return $self->render( json => { t => $title, u => $newurl } );
        exit();
    }

    # Atom の場合
    $url =
      $doc->findvalue('/html/head/link[@type="application/atom+xml"][1]/@href');
    $newurl = "" . URI->new_abs( $url, $data->{m} );
    unless ( $url eq "" ) {
        return $self->render( json => { t => $title, u => $newurl } );
        exit();
    }

    #いかなる場合の失敗
    return $self->render( json => { t => $title, u => '' } );
}

sub delete_it {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $data = $self->req->params->to_hash;
    exit() unless defined $data->{target};
    if ( $data->{target} =~ /^c\_/ ) {
        my $target = $data->{target};
        $target =~ s/c\_//;
        my $rs = $db->execute(
            "DELETE FROM categories WHERE id = :id AND user = :userid;",
            {
                id     => $target,
                userid => $self->session('username'),
            }
        ) or die $db->error;
        return $self->render( json => { r => "OK" } );
    }

    if ( $data->{target} =~ /^e\_/ ) {
        my $target = $data->{target};
        $target =~ s/e\_//;
        my $rs = $db->execute(
"DELETE target FROM target INNER JOIN categories AS c ON _id_categories = c.id WHERE target.id = :id AND c.user = :userid;",
            {
                id     => $target,
                userid => $self->session('username'),
            }
        ) or die $db->error;
        return $self->render( json => { r => "OK" } );
    }
}

sub change_it {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $data = $self->req->params->to_hash;
    exit() unless defined $data->{target};
    exit() unless $data->{target} =~ /^ne\_/;
    my $target = $data->{target};
    $target =~ s/ne\_//;
    exit() unless defined $data->{cat};

    my $rs = $db->execute(
        "UPDATE target 
                INNER JOIN categories AS c ON _id_categories = c.id
        SET target._id_categories = :cat 
        WHERE target.id = :id AND c.user = :userid ;",
        {
            cat    => $data->{cat},
            id     => $target,
            userid => $self->session('username'),
        }
    ) or die $db->error;

    return $self->render( json => { r => "OK" } );
}

sub get_numentry {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $rs   = $db->execute(
        "SELECT numentry, noreferrer FROM user WHERE id = :userid;",
        {
            userid => $self->session('username'),
        }
      )->fetch_hash
      or die $db->error;
    return $self->render(
        json => { r => $rs->{numentry}, n => $rs->{noreferrer} } );
}

sub set_numentry {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $data = $self->req->params->to_hash;
    exit() unless defined $data->{val};
    exit() unless $data->{val} =~ /^[0-9]*$/;
    exit() unless $data->{val} >= 0;
    my $rs = $db->execute(
"UPDATE user SET numentry = :val, noreferrer = :noref WHERE id = :userid;",
        {
            userid => $self->session('username'),
            val    => $data->{val},
            noref  => $data->{noref},
        }
    ) or die $db->error;
    return $self->render( json => { r => "OK" } );
}

1;
