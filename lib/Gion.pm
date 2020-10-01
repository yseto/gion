package Gion;

use strict;
use warnings;
use utf8;

use parent qw/Pulltoy::Dispatcher/;

sub prepare_router {
    my ($self, $router) = @_;
    $router->connect('/',                   { controller => 'Gion::Pages::Index', action => 'index' });
    $router->connect('/api/login',          { controller => 'Gion::Pages::Login', action => 'login' });
    $router->connect('/api/logout',         { controller => 'Gion::Pages::Login', action => 'logout' });
    $router->connect('/api/batch/:action',  { controller => 'Gion::Pages::BatchApi' });
    $router->connect('/api/:action',        { controller => 'Gion::Pages::Api' });
# TODO js routing
#   $router->connect('/*',                  { controller => 'Gion::Pages::Index', action => 'index' });
}

1;

