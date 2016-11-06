package Gion::Web::Inf;
use Mojo::Base 'Mojolicious::Controller';
use HTML::Scrubber;
use FormValidator::Lite;
use Time::Piece;
use Encode;
use Mojo::Util;

our $redirector = 'https://www.google.com/url?sa=D&q=';

sub get_category {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $rs = $db->dbh->select_all( "
        SELECT COUNT(0) AS c, cc.id AS i, cc.name AS n
        FROM entry
        INNER JOIN target AS t ON entry.target_id = t.id
        INNER JOIN category AS cc ON t.category_id = cc.id 
        WHERE readflag != 1 AND cc.user_id = ?
        GROUP BY cc.id
        ORDER BY cc.name ASC
        ", $self->session('username') );
    $self->render( json => $rs );
}

sub get_entry {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $data = $self->req->params->to_hash;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check( cat => [ 'NOT_NULL', 'UINT' ], );
    return $self->render( json => [] ) if $validator->has_error;

    my $id  = $data->{cat};
    my $cfg = $db->dbh->select_row( "SELECT * FROM user WHERE id = ?",
        $self->session('username') );

    if ( $id == 0 ) {
        my $rs = $db->dbh->select_row(
            "SELECT c.id AS id FROM entry 
        INNER JOIN target AS t ON target_id = t.id
        INNER JOIN category AS c ON c.id = t.category_id
        WHERE readflag != 1 AND c.user_id = ? 
        GROUP BY c.id ORDER BY c.name ASC LIMIT 1",
            $self->session('username')
        );

        return $self->render( json => [] ) unless defined $rs;
        $id = $rs->{id};
    }

    my $scrubber = HTML::Scrubber->new;
    my $hash     = [];
    my $count    = 0;

    my $rs = $db->dbh->select_all(
        "SELECT e.guid, s.title, description, 
        pubDate, readflag, s.url, target_id FROM entry AS e
        INNER JOIN target AS t ON target_id = t.id
        INNER JOIN story AS s ON s.guid = e.guid
        WHERE t.category_id = ? AND readflag != 1 AND e.user_id = ?
        ORDER BY pubDate DESC", $id, $self->session('username')
    );

    for (@$rs) {
        my $rs2 = $db->dbh->select_row(
"SELECT f.title FROM target AS t INNER JOIN feed AS f ON t.feed_id = f.id WHERE t.id = ?",
            $_->{target_id}
        );
        my $url = $_->{url};

        if ( $cfg->{noreferrer} == 1 ) {
            my $str = encode( 'utf-8', $url );
            $str =~ s/([^0-9A-Za-z!'()*\-._~])/sprintf("%%%02X", ord($1))/eg;
            my $_redirector = $redirector;
            if ( $self->config->{redirector} ) {
                $_redirector = $self->config->{redirector};
            }
            $url = $_redirector . $str;
        }

        my $pd = Time::Piece->strptime( $_->{pubDate}, '%Y-%m-%d %H:%M:%S' )
          ->strftime('%m/%d %H:%M');
        my $desc = $scrubber->scrub( $_->{description} );
        $desc = substr( $desc, 0, $cfg->{numsubstr} ) if $cfg->{numsubstr} > 0;

        my $h = {
            g => $_->{guid},
            t => $_->{title},
            d => $desc,
            p => $pd . " - " . $rs2->{title},
            r => $_->{readflag},
            u => $url,
            s => $_->{url},
        };
        push( @$hash, $h );

        if ( $cfg->{numentry} > 0 ) {
            $count++;
            last if $cfg->{numentry} == $count;
        }
    }
    $self->render( json => { c => $hash, id => $id } );
}

sub set_asread {
    my $self  = shift;
    my $db    = $self->app->dbh;
    my $data  = $self->req->params->to_hash;
    my $array = [];

    if ( ref( $data->{'g[]'} ) eq 'ARRAY' ) {
        for ( @{ $data->{'g[]'} } ) {
            push( @$array, $_ );
        }
    }
    else {
        push( @$array, $data->{'g[]'} );
    }

    for (@$array) {
        $self->app->log->info(
            sprintf( "ASREAD %s\t%s", $self->session('username'), $_ ) );
        $db->query(
            "UPDATE entry
            SET readflag = 1, updatetime = CURRENT_TIMESTAMP
            WHERE readflag = 0 AND user_id = ? AND guid = ?",
            $self->session('username'), $_
        ) if 0 == 1;    # TODO COMMENT OUT
    }
    $self->render( text => "OK" );
}

sub get_targetlist {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $cfg = $db->dbh->select_row( "SELECT * FROM user WHERE id = ?",
        $self->session('username') );

    my $hash = $db->dbh->select_all(
"SELECT id AS i, name AS n FROM category WHERE user_id = ? ORDER BY name ASC;",
        $self->session('username')
    );

    my $rs = $db->dbh->select_all(
        "SELECT f.id, f.title, t.category_id, f.http_status, f.siteurl 
        FROM target AS t 
        INNER JOIN feed AS f ON feed_id = f.id 
        WHERE t.user_id = ? ORDER BY title ASC",
        $self->session('username')
    );

    my $hash_c;
    for (@$rs) {
        my $url = $_->{siteurl};
        if ( $cfg->{noreferrer} == 1 ) {
            my $str = encode( 'utf-8', $_->{siteurl} );
            $str =~ s/([^0-9A-Za-z!'()*\-._~])/sprintf("%%%02X", ord($1))/eg;
            my $_redirector = $redirector;
            if ( $self->config->{redirector} ) {
                $_redirector = $self->config->{redirector};
            }
            $url = $_redirector . $str;
        }
        my $h = {
            i => $_->{id},
            n => $_->{title},
            c => $_->{category_id},
            r => $_->{http_status},
            h => $url,
        };
        push( @$hash_c, $h );
    }
    $self->render( json => { n => $hash, t => $hash_c } );
}

sub get_pinlist {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $cfg = $db->dbh->select_row( "SELECT * FROM user WHERE id = ?",
        $self->session('username') );

    my $rs = $db->dbh->select_all(
        "SELECT s.title AS t, s.url AS u, e.guid AS g, e.updatetime AS m
            FROM entry AS e 
            INNER JOIN target AS tt ON e.target_id = tt.id
            INNER JOIN story AS s ON s.guid = e.guid
            WHERE e.readflag = 2 AND tt.user_id = ?
            ORDER BY pubDate DESC", $self->session('username')
    );

    return $self->render( json => $rs ) if $cfg->{noreferrer} == 0;

    my $hash;
    for (@$rs) {
        my $url = $_->{u};
        my $str = encode( 'utf-8', $url );
        $str =~ s/([^0-9A-Za-z!'()*\-._~])/sprintf("%%%02X", ord($1))/eg;
        my $_redirector = $redirector;
        if ( $self->config->{redirector} ) {
            $_redirector = $self->config->{redirector};
        }
        $url = $_redirector . $str;
        my $h = {
            t => $_->{t},
            g => $_->{g},
            m => $_->{m},
            u => $url,
        };
        push( @$hash, $h );
    }
    return $self->render( json => $hash ) if defined $hash;
    return $self->render( json => {} );
}

sub set_pin {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $data      = $self->req->params->to_hash;
    my $validator = FormValidator::Lite->new( $self->req );
    my $res       = $validator->check(
        flag  => [ 'NOT_NULL', 'UINT' ],
        pinid => ['NOT_NULL'],
    );
    return $self->render( json => [] ) if $validator->has_error;

    my $flag = 1;
    $flag = 2 if $data->{flag} == 1;

    $self->app->log->info(
        sprintf( "PIN %s\t%s", $self->session('username'), $data->{pinid} ) );

    $db->dbh->query(
        "UPDATE entry
        SET readflag = ?, updatetime = CURRENT_TIMESTAMP
        WHERE user_id = ? AND guid = ?",
        $flag, $self->session('username'), $data->{pinid}
    );

    $self->render( text => "OK" );
}

sub remove_all_pin {
    my $self = shift;
    my $db   = $self->app->dbh;

    $db->dbh->query(
        "UPDATE entry
        SET readflag = 1, updatetime = CURRENT_TIMESTAMP
        WHERE readflag = 2 AND user_id = ?",
        $self->session('username')
    );
    $self->render( text => "OK" );
}

sub update_password {
    my $self  = shift;
    my $db    = $self->app->dbh;
    my $data  = $self->req->params->to_hash;
    my $valid = FormValidator::Lite->new( $self->req );
    my $res   = $valid->check(
        password_old => [ 'NOT_NULL', [qw/LENGTH 8 255/] ],
        { password => [qw/password passwordc/] } => ['DUPLICATION'],
        password => [ 'NOT_NULL', [qw/LENGTH 8 255/] ],
    );
    return $self->render( json => { e => 'error' } ) if $valid->has_error;

    my $strech = $self->config->{strech} || 500;
    my $salt   = $self->config->{salt}   || "Gion::Util::Auth";
    my $cfg = $db->dbh->select_row( "SELECT * FROM user_id WHERE id = ?",
        $self->session('username') );
    my $id = $cfg->{name};

    my $nowauth = Gion::Util::Auth->new(
        strech => $strech,
        salt   => $salt,
        id     => $id,
        password => Mojo::Util::encode( 'UTF-8', $data->{password_old} ),
    );
    return $self->render( json => { e => 'unmatch now password' } )
      if $cfg->{password} ne $nowauth->get_hash;

    my $auth = Gion::Util::Auth->new(
        strech => $strech,
        salt   => $salt,
        id     => $id,
        password => Mojo::Util::encode( 'UTF-8', $data->{password} ),
    );

    $self->app->log->info( "Update Passwd: "
          . $auth->get_hash . ","
          . $self->session('username') );
    $db->dbh->query( "UPDATE user SET password = ? WHERE id = ?",
        $auth->get_hash, $self->session('username') );
    $self->render( json => { e => 'update password' } );
}

sub create_user {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $data = $self->req->params->to_hash;

    unless ( $self->session('superuser') ) {
        return $self->render( 'json' => { e => 'you are not superuser.' } );
    }

    my $valid = FormValidator::Lite->new( $self->req );
    my $res   = $valid->check(
        username => ['NOT_NULL'],
        password => [ 'NOT_NULL', [qw/LENGTH 8 255/] ],
    );
    return $self->render( json => { e => 'error' } ) if $valid->has_error;

    my $auth = Gion::Util::Auth->new(
        strech => $self->config->{strech} || 500,
        salt   => $self->config->{salt}   || "Gion::Util::Auth",
        id     => encode( 'UTF-8', $data->{username} ),
        password => encode( 'UTF-8', $data->{password} ),
    );

    $db->dbh->query( 'INSERT INTO user (id,password,name) VALUES (null,?,?)',
        $auth->get_hash, encode( 'UTF-8', $data->{username} ) );
    $self->render( 'json' => { e => "User Added: " . $data->{username} } );
}

1;
