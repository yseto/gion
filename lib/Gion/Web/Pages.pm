package Gion::Web::Pages;
use Mojo::Base 'Mojolicious::Controller';

sub add {
    my $self = shift;
    $self->stash(jsfunc => 'register');
    $self->render();
}

sub settings {
    my $self = shift;
    $self->stash(jsfunc => 'settings');
    $self->render();
}

sub subscription {
    my $self = shift;
    $self->stash(jsfunc => 'subscription');
    $self->render();
}

sub normal {
    my $self = shift;
    $self->stash(jsfunc => 'reader');
    $self->render();
}

sub welcome {
    my $self = shift;
    $self->render();
}

sub entrance {
    my $self = shift;
    $self->stash(jsfunc => 'welcome');
    $self->render();
}

1;
