package Gion::Login;

use strict;
use warnings;
use utf8;

use parent qw/Gion::Base/;

use Gion::Config;
use Gion::Util;

use Crypt::JWT qw(encode_jwt);
use Encode;
use JSON;
use JSON::XS;

sub dispatch_login {
    my $self = shift;
    my $db = $self->dbh;

    my $auth = Gion::Util::auth(
        id => encode_utf8($self->req->param('id')),
        password => encode_utf8($self->req->param('password')),
    );

    if ( my $c = $db->select_row('SELECT * FROM user WHERE password = ?', $auth) ) {
        my $jwt_config = config->param('jwt');
        $self->res->cookies->{ $jwt_config->{cookie_name} } = +{
            value => _encode_jwt($c->{id}),
            httponly => 1,
        };

        $db->query('UPDATE user SET last_login = CURRENT_TIMESTAMP WHERE id = ?', $c->{id});
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

