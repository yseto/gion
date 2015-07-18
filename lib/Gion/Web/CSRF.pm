package Gion::Web::CSRF;
use Mojo::Base 'Mojolicious::Controller';

sub check {
    my $self = shift;

    if ($self->req->method eq 'POST') {
        if ( $self->validation->csrf_protect->has_error('csrf_token') ) {
            return $self->render(text => 'CSRF token error.', status => 403);
        }
    }
    return 1;
}

1;
