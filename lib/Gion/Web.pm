package Gion::Web;
use Mojo::Base 'Mojolicious';
use Mojo::Util qw(encode);
use Gion::DB;
use Gion::Util::Auth;
use String::Random qw(random_string);

sub startup {
    my $self = shift;

    $self->plugin( 'Config', { file => 'gion.conf', default => {} } );
    $self->plugin('CSRFProtect');

    if ($self->config->{cookie}) {
        $self->sessions->cookie_domain( $self->config->{cookie}->{domain} );
        my $secret = $self->config->{cookie}->{secret};
        unless ($secret) {
            $secret = random_string("s" x 32);
        }
        $self->secret([$secret]);
    }
    $self->sessions->cookie_name('Gion');
    $self->attr( dbh => sub { Gion::DB->new; });

    # 1日はログインが有効
    $self->sessions->default_expiration(86400);

    # Router
    my $r = $self->routes;
    my $l = $r->bridge->to( cb => sub { &loginchk; } );

    $l->post('/inf/:action')->to( controller => 'inf' );
    $l->post('/pin/:action')->to( controller => 'pin' );
    $l->post('/manage/:action')->to( controller => 'subscription' );

    $l->route('/api/:controller/:action')->to( namespace => 'Gion::Api' );

    $l->get('/entries/')->to( controller => 'pages', action => 'normal' );
    $l->get('/add/')->to( controller => 'pages', action => 'add' );
    $l->get('/subscription/')
      ->to( controller => 'pages', action => 'subscription' );
    $l->get('/settings/')->to( controller => 'pages', action => 'settings' );

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

sub loginchk {
    my $self = shift;
    my $data = $self->req->params->to_hash;
    my $db = $self->app->dbh;
    $self->stash( active => $self->req->url );

    # ログアウト
    if ( defined $data->{logout} and $data->{logout} == 1 ) {
        $self->session( expires => 1 );
        $self->render( controller => 'pages', action => 'welcome', id => 1 );
        return undef;
    }

    #ログインのトライ
    if ( defined $data->{login} and $data->{login} == 1 ) {
        my $a = Gion::Util::Auth->new(
            strech => $self->config->{strech} || 500,
            salt   => $self->config->{salt}   || "Gion::Util::Auth",
            id     => encode( 'UTF-8', $data->{id} ),
            passwd => encode( 'UTF-8', $data->{pw} ),
        );

        my $c = $db->dbh->select_row('SELECT * FROM user WHERE pw = ?', $a->get_hash);
        if ( defined $c ) {
            $self->session(username => $c->{id});
            $db->dbh->query('UPDATE user SET last_login = CURRENT_TIMESTAMP WHERE id = ?', $c->{id});
            if ( $self->config->{url} ) {
                if ( $self->config->{url}->{login_ssl} eq 'on' ) {
                    $self->redirect_to( $self->config->{url}->{http} );
                }
            }
            return 1;
        }
    }

    #ログインしていたら
    if ( $self->session('username') ) {
        return 1;
    }

    #ログインフォーム
    if ( $self->config->{url} ) {
        if ( $self->config->{url}->{login_ssl} eq 'on' ) {
            my $sslheaders = $self->req->headers->header('X-Forwarded-HTTPS');
            if ( defined $sslheaders and $sslheaders eq 'on' ) {
                $self->render( controller => 'pages', action => 'welcome' );
                return undef;
            }
            else {
                $self->redirect_to( $self->config->{url}->{https} );
                return undef;
            }
        }
    }
    $self->render( controller => 'pages', action => 'welcome' );
    return undef;
}

1;
