package Gion;

use strict;
use warnings;
use utf8;

use parent qw/Pulltoy::Dispatcher/;

sub prepare_router {
    my ($self, $router) = @_;
    $router->connect('/',                   { controller => 'Gion::Index', action => 'index' });
    $router->connect('/api/login',          { controller => 'Gion::Login', action => 'login' });
    $router->connect('/api/logout',         { controller => 'Gion::Login', action => 'logout' });
    $router->connect('/api/batch/:action',  { controller => 'Gion::BatchApi' });
    $router->connect('/api/:action',        { controller => 'Gion::Api' });
    $router->connect('/*',                  { controller => 'Gion::Index', action => 'index' });
}

1;

