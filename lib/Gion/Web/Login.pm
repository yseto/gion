package Gion::Web::Login;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw/encode/;
use Gion::Util::Auth;

sub auth {
    my $self = shift;
    my $data = $self->req->params->to_hash;
    my $db   = $self->app->dbh->dbh;

    # ログアウト
    if ( defined $data->{logout} and $data->{logout} == 1 ) {
        $self->session( expires => 1 );
        $self->render( controller => 'pages', action => 'welcome', id => 1 );
        return undef;
    }

    #ログインのトライ
    if ( defined $data->{login} and $data->{login} == 1 ) {
        my $auth = Gion::Util::Auth->new(
            strech => $self->config->{strech} || 500,
            salt   => $self->config->{salt}   || "Gion::Util::Auth",
            id     => encode( 'UTF-8', $data->{id} ),
            passwd => encode( 'UTF-8', $data->{pw} ),
        );

        my $c = $db->select_row( 'SELECT * FROM user WHERE pw = ?',
            $auth->get_hash );
        if ( defined $c ) {
            $self->session( username => $c->{id} );
            $self->session( superuser => $data->{id} eq 'admin' ? 1 : 0 );
            $db->query(
                'UPDATE user SET last_login = CURRENT_TIMESTAMP WHERE id = ?',
                $c->{id} );
            return 1;
        }
    }

    #ログインしていたら
    if ( $self->session('username') ) {
        return 1;
    }

    #ログインフォーム
    if ( $self->req->url->path eq '/'){
        $self->render( controller => 'pages', action => 'welcome' );
    }else{
        $self->redirect_to('/');
    }
    return undef;
}

1;


