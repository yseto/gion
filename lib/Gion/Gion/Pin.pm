package Gion::Gion::Pin;
use Mojo::Base 'Mojolicious::Controller';
use Encode;

sub get_pinlist {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $rs;
    $rs   = $db->execute( 
        "SELECT noreferrer FROM user WHERE id = :userid;",
        { userid => $self->session('username') } )->fetch_hash;
    my $noreferrer = $rs->{noreferrer};

    $rs   = $db->execute(
        "SELECT s.title AS t, s.url AS u, e.guid AS g, e.updatetime AS m
            FROM entries AS e 
            INNER JOIN target AS tt ON e._id_target = tt.id
            INNER JOIN categories AS c ON tt._id_categories = c.id
            INNER JOIN stories AS s ON s.guid = e.guid
            WHERE c.user = :userid AND e.readflag = 2 
            ORDER BY pubDate DESC;",
        { userid => $self->session('username') }
    ) or die $db->error;

    return $self->render( json => $rs->all ) if $noreferrer == 0;

    my $hash;
    foreach my $c ( @{ $rs->all } ) {
        my $url = $c->{u};
        my $str = encode( 'utf-8', $url );
        $str =~ s/([^0-9A-Za-z!'()*\-._~])/sprintf("%%%02X", ord($1))/eg;
        $url = $self->config->{redirector} . $str;
   
        my $h = {
            t => $c->{t},
            g => $c->{g},
            m => $c->{m},
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
    return unless defined $data->{flag};
    return unless defined $data->{pinid};

    my $flag = $data->{flag};
    if ( $flag == 1 ) {
        $flag = 2;
    }
    else {
        $flag = 1;
    }

    $db->execute(
        "UPDATE entries AS e
                INNER JOIN target AS t ON e._id_target = t.id
                INNER JOIN categories AS c ON t._id_categories = c.id
        SET
                e.readflag = :flag,
                updatetime = CURRENT_TIMESTAMP
                WHERE c.user = :userid AND e.guid = :guid;
                ",
        {
            flag   => $flag,
            guid   => $data->{pinid},
            userid => $self->session('username'),
        }
    ) or die $db->error;

    return $self->render( text => "OK" );
}

sub remove_all_pin {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $rs = $db->execute(
        "UPDATE entries AS e
                INNER JOIN target AS t ON e._id_target = t.id
                INNER JOIN categories AS c ON t._id_categories = c.id
        SET
                e.readflag = 1,
                updatetime = CURRENT_TIMESTAMP
                WHERE c.user = :userid AND e.readflag = 2
                ",
        { userid => $self->session('username'), }
    ) or die $db->error;
    return $self->render( text => "OK" );
}

1;
