package Gion::Web;
use Mojo::Base 'Mojolicious';
use Gion::DB;
use String::Random qw(random_string);

sub startup {
    my $self = shift;

    $self->plugin( 'Config', { file => 'gion.conf', default => {} } );
    $self->plugin('CSRFProtect');
    $self->secrets( [ random_string( "s" x 32 ) ] );
    $self->sessions->cookie_name('Gion');
    $self->sessions->default_expiration(86400);
    $self->attr( dbh => sub { Gion::DB->new; } );

    # Router
    my $r = $self->routes;
    my $l = $r->bridge->to('login#auth');

    $l->post('/inf/:action')->to( controller => 'inf' );
    $l->post('/pin/:action')->to( controller => 'pin' );
    $l->post('/manage/:action')->to( controller => 'subscription' );

    $l->route('/api/:controller/:action')->to( namespace => 'Gion::Api' );

    $l->get('/entries/')->to( controller => 'pages', action => 'normal' );
    $l->get('/add/')->to( controller => 'pages', action => 'add' );
    $l->get('/subscription/')
      ->to( controller => 'pages', action => 'subscription' );
    $l->get('/settings/')->to( controller => 'pages', action => 'settings' );
    $l->route('/opml/:action')->to( controller => 'opml' );

    $l->route('/')->to( controller => 'pages', action => 'entrance' );
    $r->route('/')->to( controller => 'pages', action => 'welcome' );
    $r->route('/robots.txt')->to( controller => 'pages', action => 'robots' );

    $self->app->hook(
        after_dispatch => sub {
            my $s = shift;
            $s->res->headers->header( 'X-Content-Type-Options' => 'nosniff' );
            $s->res->headers->header( 'X-Frame-Options'        => 'deny' );
            $s->res->headers->header( 'Cache-Control'          => 'no-cache' );
        }
    );
}

1;

