package Pulltoy::Dispatcher;

use strict;
use warnings;
use utf8;
use parent qw(Plack::Component);

use Plack::Util::Accessor qw/router/;
use Module::Load;
use Router::Simple;

sub prepare_app {
    my $self = shift;
    $self->router(Router::Simple->new);
    $self->prepare_router($self->router);
}

sub call {
    my ($self, $env) = @_;

    if (my $p = $self->router->match($env)) {
        my $action = delete $p->{action};
        my $controller = delete $p->{controller};
        $env->{'myweb.router'} = $p;

        load $controller;
        return $controller->new($env)->dispatch($action);
    } else {
        return [404, [], []];
    }
}

1;
