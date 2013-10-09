package Gion;
use Mojo::Base 'Mojolicious';
use v5.12;
use DBIx::Custom;
use DBIx::Connector;
use Mojo::Util qw(encode);

$ENV{MOJO_MODE}          = 'production';
$ENV{MOJO_REVERSE_PROXY} = 1;

# This method will run once at server start
sub startup {
    my $self = shift;

    $self->plugin('Config');
    $self->plugin('CSRFProtect');

    $self->sessions->cookie_domain( $self->config->{cookie}->{domain} );
    $self->sessions->cookie_name('Gion');

    # 認証
    push @{ $self->app->plugins->namespaces }, 'Gion::Plugin';
    $self->plugin('Auth');

    $self->secret($self->config->{cookie}->{secret});

    # 1日はログインが有効
    $self->sessions->default_expiration(86400);

    # Router
    my $r = $self->routes;
    my $l = $r->bridge->to( cb => sub { &loginchk; } );

    $l->post('/api/:action')->to( controller => 'api' );
    $l->post('/pin/:action')->to( controller => 'pin' );
    $l->post('/manage/:action')->to( controller => 'subscription' );
    $l->get('/add')->to( controller => 'pages', action => 'add' );
    $l->get('/subscription')
      ->to( controller => 'pages', action => 'subscription' );

    $l->route('/entries/')->to( controller => 'pages', action => 'normal' );
    $l->route('/')->to( controller => 'pages', action => 'entrance' );
    $r->route('/')->to( controller => 'pages', action => 'welcome' );

    $self->app->hook(
        after_dispatch => sub {
            my $s = shift;
            $s->res->headers->header( 'X-Content-Type-Options' => 'nosniff' );
            $s->res->headers->header( 'X-Frame-Options'        => 'deny' );
            $s->res->headers->header( 'Cache-Control'          => 'no-cache' );
        }
    );

}

sub loginchk {
    my $self = shift;
    my $data = $self->req->params->to_hash;

    $self->stash( active => $self->req->url );

    # ログアウト
    if ( defined $data->{logout} and $data->{logout} == 1 ) {
        $self->session( expires => 1 );
        $self->render( controller => 'pages', action => 'welcome', id => 1 );
        return undef;
    }

    #ログインのトライ
    if ( defined $data->{login} and $data->{login} == 1 ) {
        my $did = encode 'UTF-8', $data->{id};
        my $dpw = encode 'UTF-8', $data->{pw};
        my $c = $self->app->authenticate( $did, $dpw );
        if ( defined $c ) {
            $self->session( username => $c->{id} );
            if ( $self->config->{url}->{login_ssl} eq 'on' ) {
                $self->redirect_to( $self->config->{url}->{http} );
            }
            return 1;
        }
    }

    #ログインしていたら
    if ( $self->session('username') ) {
        return 1;
    }

    #ログインフォーム
    if ( $self->config->{url}->{login_ssl} eq 'on' ) {
	my $sslheaders =
            $self->req->headers->header('X-Forwarded-HTTPS');
        if ( defined $sslheaders and $sslheaders eq 'on' ) {
            $self->render( controller => 'pages', action => 'welcome' );
            return undef;
        }
        else {
            $self->redirect_to( $self->config->{url}->{https} );
            return undef;
        }
    }
    $self->render( controller => 'pages', action => 'welcome' );
    return undef;
}

has dbh => sub {
    my $self = shift;

    my $connector = DBIx::Connector->new(
        'dbi:mysql:host='
          . $self->config->{db}->{hostname}
          . ';database='
          . $self->config->{db}->{database},
        $self->config->{db}->{username},
        $self->config->{db}->{password},
        { %{ DBIx::Custom->new->default_option }, mysql_enable_utf8 => 1 }
    );
    my $db = DBIx::Custom->connect( connector => $connector );
    return $db;
};

1;
