package Gion::Pages::Login;

use strict;
use warnings;
use utf8;

use parent qw/Gion::Pages::Base/;

use Crypt::JWT qw(encode_jwt);
use Encode;
use JSON;
use JSON::XS;

use Gion::Config;
use Gion::Model::User;

sub dispatch_login {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    $validator->check(
        id => [ 'NOT_NULL' ],
        password => [ 'NOT_NULL' ],
    );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/id password/;

    my $user_model = Gion::Model::User->new;
    my $digest = $user_model->generate_password_digest_with_username(
        username => $values{id},
        password => $values{password},
    );

    my $c = $self->data->user_by_name(name => $values{id});
    if ($c && $c->{password} eq $digest) {
        my $jwt_config = config->param('jwt');
        $self->res->cookies->{ $jwt_config->{cookie_name} } = +{
            value => _encode_jwt($c->{id}),
            httponly => 1,
            expires => time + 24 * 60 * 60,
        };

        $self->data->update_user_last_login(id => $c->{id});

        $self->res->code(200);
        $self->res->body(encode_json({authorization => JSON::true}));
        return;
    }
    $self->res->code(401);
    $self->res->header("WWW-Authenticate" => "invalid_token");
}

sub dispatch_logout {
    my $self = shift;
    my $jwt_config = config->param('jwt');
    $self->res->cookies->{ $jwt_config->{cookie_name} } = +{
        value => "",
        expires => -1,
    };

    $self->res->code(202);
    $self->res->body(encode_json({authorization => JSON::false}));
    $self->finished(1);
}

sub _encode_jwt {
    my $user_id = shift;

    my $jwt_config = config->param('jwt');

    return encode_jwt(
        payload => { user_id => $user_id },
        key => \$jwt_config->{public_key},
        alg => $jwt_config->{alg},
        enc => $jwt_config->{enc},
    );
}

1;

