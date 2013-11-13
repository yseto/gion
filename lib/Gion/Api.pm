package Gion::Api;
use Mojo::Base 'Mojolicious::Controller';
use v5.12;
use HTML::Scrubber;
use Encode;

sub get_categories {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $rs = $db->execute(
        "SELECT COUNT(0) AS c, cc.id AS i, cc.name AS n
        FROM entries
        INNER JOIN target AS t ON entries._id_target = t.id
        INNER JOIN categories AS cc ON t._id_categories = cc.id 
        WHERE readflag != 1 AND cc.user = :userid
        GROUP BY cc.id
        ORDER BY cc.name ASC;",
        { userid => $self->session('username') }
    ) or die $db->error;

    my $hash = [];
    foreach my $c ( @{ $rs->all } ) {
        my $h = {
            i => $c->{i},
            n => $c->{n},
            c => $c->{c},
        };
        push( @$hash, $h );
    }
    return $self->render( json => $hash );
}

sub get_entries {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $data = $self->req->params->to_hash;
    exit() unless defined $data->{cat};
    exit() unless $data->{cat} =~ /[0-9]*/;

    my $rs;
    my $id;
    $rs =
      $db->execute( "SELECT numentry,noreferrer FROM user WHERE id = :userid;",
        { userid => $self->session('username') } )->fetch_hash;
    my $numentry   = $rs->{numentry};
    my $noreferrer = $rs->{noreferrer};

    if ( $data->{cat} == 0 ) {
        $rs = $db->execute(
            "SELECT c.id AS id
        FROM entries
        INNER JOIN target AS t ON _id_target = t.id
        INNER JOIN categories AS c ON c.id = t._id_categories
        WHERE readflag != 1 AND c.user = :userid
        GROUP BY c.id
        ORDER BY c.name ASC
        LIMIT 1;",
            { userid => $self->session('username') }
        ) or die $db->error;
        my $tmp = $rs->fetch_hash;
        if ( defined $tmp ) {
            $id = $tmp->{id};
        }
        else {
            return $self->render( json => [] );
        }
    }
    else {
        $id = $data->{cat};
    }

    $rs = $db->execute(
        "SELECT 
        e.guid, s.title, description, 
        DATE_FORMAT(pubDate,'%m/%d %H:%i') AS pd,
        readflag, s.url, _id_target 
        FROM entries AS e
        INNER JOIN target AS t ON _id_target = t.id
        INNER JOIN categories AS c ON t._id_categories = c.id 
        INNER JOIN stories AS s ON s.guid = e.guid
        WHERE t._id_categories = :id AND readflag != 1 AND c.user = :userid
        ORDER BY pubDate DESC;",
        {
            id     => $id,
            userid => $self->session('username')
        }
    ) or die $db->error;

    my $scrubber = HTML::Scrubber->new;

    my $hash  = [];
    my $read  = [];
    my $count = 0;
    foreach my $c ( @{ $rs->all } ) {
        my $rs2 = $db->execute( "SELECT title FROM target WHERE id = :id;",
            { id => $c->{_id_target} } )
          or die $db->error;
        my $url = $c->{url};

        if ( $noreferrer == 1 ) {
            my $str = encode( 'utf-8', $url );
            $str =~ s/([^0-9A-Za-z!'()*\-._~])/sprintf("%%%02X", ord($1))/eg;
            $url = $self->config->{redirector} . $str;
        }

        my $h = {
            g => $c->{guid},
            t => $c->{title},
            d => $scrubber->scrub( $c->{description} ),
            p => $c->{pd} . " - " . $rs2->fetch_hash->{title},
            r => $c->{readflag},
            u => $url,
        };
        push( @$hash, $h );
        push( @$read, $c->{guid} );
        if ( $numentry > 0 ) {
            $count++;
            last if $numentry == $count;
        }
    }

    foreach my $g (@$read) {
        $rs = $db->execute(
            "UPDATE entries
            INNER JOIN target AS t ON _id_target = t.id
            INNER JOIN categories AS c ON t._id_categories = c.id
            SET 
            readflag = 1,
            updatetime = CURRENT_TIMESTAMP
            WHERE t._id_categories = :id AND readflag = 0 AND c.user = :userid
            AND guid = :guid;",
            {
                id     => $id,
                userid => $self->session('username'),
                guid   => $g,
            }
        ) or die $db->error;
    }

    return $self->render( json => $hash );
}

sub get_targetlist {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $rs;
    $rs = $db->execute(
        "SELECT noreferrer FROM user WHERE id = :userid;",
        { userid => $self->session('username') }
    )->fetch_hash;
    my $noreferrer = $rs->{noreferrer};

    $rs = $db->execute(
"SELECT id, name FROM categories WHERE user = :userid ORDER BY name ASC;",
        { userid => $self->session('username') }
    ) or die $db->error;

    my $hash = [];
    foreach my $c ( @{ $rs->all } ) {
        my $h = {
            i => $c->{id},
            n => $c->{name},
        };
        push( @$hash, $h );
    }

    $rs = $db->execute(
"SELECT target.id, target.title, target._id_categories, target.http_status, target.siteurl FROM target INNER JOIN categories AS c ON _id_categories = c.id 
WHERE c.user = :userid ORDER BY title ASC;",
        { userid => $self->session('username') }
    ) or die $db->error;

    my $hash_c = [];
    foreach my $c ( @{ $rs->all } ) {

        my $url = $c->{siteurl};
        if ( $noreferrer == 1 ) {
            my $str = encode( 'utf-8', $c->{siteurl} );
            $str =~ s/([^0-9A-Za-z!'()*\-._~])/sprintf("%%%02X", ord($1))/eg;
            $url = $self->config->{redirector} . $str;
        }

        my $h = {
            i => $c->{id},
            n => $c->{title},
            c => $c->{_id_categories},
            r => $c->{http_status},
            h => $url,
        };
        push( @$hash_c, $h );
    }

    return $self->render( json => { n => $hash, t => $hash_c } );
}

1;
