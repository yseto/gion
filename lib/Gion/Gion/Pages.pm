package Gion::Gion::Pages;
use Mojo::Base 'Mojolicious::Controller';

sub add {
    my $self = shift;
    $self->stash( jspath => 'add.js' );
    $self->render();
}

sub settings {
    my $self = shift;
    $self->stash( jspath => 'settings.js' );
    $self->render();
}

sub subscription {
    my $self = shift;
    $self->stash( jspath => 'subscription.js' );
    $self->render();
}

sub normal {
    my $self = shift;
    $self->stash( jspath => 'e.js' );
    $self->render();
}

sub welcome {
    my $self = shift;
    $self->render();
}

sub entrance {
    my $self = shift;
    $self->stash( jspath => 'entrance.js' );
    $self->render();
}

1;
