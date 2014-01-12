package Gion::Web::Inf;
use Mojo::Base 'Mojolicious::Controller';
use HTML::Scrubber;
use FormValidator::Lite;
use Time::Piece;
use Encode;

sub get_categories {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $rs = $db->dbh->select_all(
        "SELECT COUNT(0) AS c, cc.id AS i, cc.name AS n
        FROM entries
        INNER JOIN target AS t ON entries._id_target = t.id
        INNER JOIN categories AS cc ON t._id_categories = cc.id 
        WHERE readflag != 1 AND cc.user = ?
        GROUP BY cc.id
        ORDER BY cc.name ASC",
        , $self->session('username')
    );
    $self->render( json => $rs );
}

sub get_entries {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $data = $self->req->params->to_hash;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check( cat => [ 'NOT_NULL', 'UINT' ], );
    return $self->render( json => [] ) if $validator->has_error;

    my $id = $data->{cat};
    my $cfg = $db->dbh->select_row("SELECT * FROM user WHERE id = ?",
        $self->session('username'));

    if ( $id == 0 ) {
        my $rs = $db->dbh->select_row( "SELECT c.id AS id FROM entries 
        INNER JOIN target AS t ON _id_target = t.id
        INNER JOIN categories AS c ON c.id = t._id_categories
        WHERE readflag != 1 AND c.user = ? 
        GROUP BY c.id ORDER BY c.name ASC LIMIT 1",
        $self->session('username'));

        return $self->render( json => [] ) unless defined $rs;
        $id = $rs->{id};
    }

    my $scrubber = HTML::Scrubber->new;
    my $hash     = [];
    my $count    = 0;

    $db->txn( sub {
        my $db = shift;
        my $rs = $db->select_all(
            "SELECT e.guid, s.title, description, 
            pubDate, readflag, s.url, _id_target FROM entries AS e
            INNER JOIN target AS t ON _id_target = t.id
            INNER JOIN categories AS c ON t._id_categories = c.id 
            INNER JOIN stories AS s ON s.guid = e.guid
            WHERE t._id_categories = ? AND readflag != 1 AND c.user = ?
            ORDER BY pubDate DESC", $id, $self->session('username'));

        for (@$rs) {
            my $rs2 = $db->select_row(
                "SELECT title FROM target WHERE id = ?", $_->{_id_target});
            my $url = $_->{url};

            if ( $cfg->{noreferrer} == 1 ) {
                my $str = encode( 'utf-8', $url );
                $str =~ s/([^0-9A-Za-z!'()*\-._~])/sprintf("%%%02X", ord($1))/eg;
                $url = $self->config->{redirector} . $str;
            }

            my $pd = Time::Piece->strptime($_->{pubDate}, '%Y-%m-%d %H:%M:%S')->strftime('%m/%d %H:%M');

            my $h = {
                g => $_->{guid},
                t => $_->{title},
                d => $scrubber->scrub( $_->{description} ),
                p => $pd . " - " . $rs2->{title},
                r => $_->{readflag},
                u => $url,
                s => $_->{url},
            };
            push( @$hash, $h );

            $db->query(
                "UPDATE entries
                SET readflag = 1, updatetime = CURRENT_TIMESTAMP
                WHERE readflag = 0 AND user = ? AND guid = ?",
                $self->session('username'), $_->{guid}) if 1 == 1;    # TODO COMMENT OUT

            if ( $cfg->{numentry} > 0 ) {
                $count++;
                last if $cfg->{numentry} == $count;
            }
        }
    });
    $self->render( json => $hash );
}

sub get_targetlist {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $cfg = $db->dbh->select_row("SELECT * FROM user WHERE id = ?",
        $self->session('username'));

    my $hash = $db->dbh->select_all(
        "SELECT id AS i, name AS n FROM categories WHERE user = ? ORDER BY name ASC;",
        $self->session('username'));

    my $rs = $db->dbh->select_all(
        "SELECT t.id, t.title, t._id_categories, t.http_status, t.siteurl 
        FROM target AS t INNER JOIN categories AS c ON _id_categories = c.id 
        WHERE c.user = ? ORDER BY title ASC", $self->session('username'));

    my $hash_c;
    for(@$rs){
        my $url = $_->{siteurl};
        if ( $cfg->{noreferrer} == 1 ) {
            my $str = encode( 'utf-8', $_->{siteurl} );
            $str =~ s/([^0-9A-Za-z!'()*\-._~])/sprintf("%%%02X", ord($1))/eg;
            $url = $self->config->{redirector} . $str;
        }
        my $h = {
            i => $_->{id},
            n => $_->{title},
            c => $_->{_id_categories},
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

    my $cfg = $db->dbh->select_row(
        "SELECT * FROM user WHERE id = ?", $self->session('username'));

    my $rs = $db->dbh->select_all(
        "SELECT s.title AS t, s.url AS u, e.guid AS g, e.updatetime AS m
            FROM entries AS e 
            INNER JOIN target AS tt ON e._id_target = tt.id
            INNER JOIN categories AS c ON tt._id_categories = c.id
            INNER JOIN stories AS s ON s.guid = e.guid
            WHERE e.readflag = 2 AND c.user = ?
            ORDER BY pubDate DESC", $self->session('username'));

    return $self->render( json => $rs ) if $cfg->{noreferrer} == 0;

    my $hash;
    for(@$rs) {
        my $url = $_->{u};
        my $str = encode( 'utf-8', $url );
        $str =~ s/([^0-9A-Za-z!'()*\-._~])/sprintf("%%%02X", ord($1))/eg;
        $url = $self->config->{redirector} . $str;
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

    my $data = $self->req->params->to_hash;
    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check(
        flag => [ 'NOT_NULL', 'UINT' ],
        pinid => [ 'NOT_NULL' ],
    );
    return $self->render(json => [] ) if $validator->has_error;

    my $flag = 1;
    $flag = 2 if $data->{flag} == 1;

    $db->dbh->query("UPDATE entries
        SET readflag = ?, updatetime = CURRENT_TIMESTAMP
        WHERE user = ? AND guid = ?", 
        $flag, $self->session('username'), $data->{pinid} );

    $self->render( text => "OK" );
}

sub remove_all_pin {
    my $self = shift;
    my $db   = $self->app->dbh;

    $db->dbh->query("UPDATE entries
        SET readflag = 1, updatetime = CURRENT_TIMESTAMP
        WHERE readflag = 2 AND user = ?",
        $self->session('username'));
    $self->render( text => "OK" );
}



1;
