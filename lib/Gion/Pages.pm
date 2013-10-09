package Gion::Pages;
use Mojo::Base 'Mojolicious::Controller';
use v5.12;

sub add {
    my $self = shift;
    $self->stash( jspath => 'add.js' );
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
