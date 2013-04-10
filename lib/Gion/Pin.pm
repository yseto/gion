package Gion::Pin;
use Mojo::Base 'Mojolicious::Controller';
use v5.12;

sub get_pinlist {
    my $self = shift;
    my $db   = $self->app->dbh;
    my $rs   = $db->execute(
        "SELECT e.title AS t, e.url AS u 
            FROM entries AS e 
            INNER JOIN target AS tt ON e._id_target = tt.id
            INNER JOIN categories AS c ON tt._id_categories = c.id
            WHERE c.user = :userid AND e.readflag = 2 
            ORDER BY pubDate DESC;",
        { userid => $self->session('username') }
    ) or die $db->error;
    return $self->render( json => $rs->all );
}

sub set_pin {
    my $self = shift;
    my $db   = $self->app->dbh;

    my $data = $self->req->params->to_hash;
    exit() unless defined $data->{flag};
    exit() unless defined $data->{pinid};

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
        SET e.readflag = :flag
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
                SET e.readflag = 1 
                WHERE c.user = :userid AND e.readflag = 2
                ",
        { userid => $self->session('username'), }
    ) or die $db->error;
    return $self->render( text => "OK" );
}

1;
