package Gion::Authorizer::Api;

use strict;
use warnings;
use utf8;

use parent qw/Gion::Authorizer::Origin/;

use Cookie::Baker::XS qw(crush_cookie);
use Crypt::JWT qw(decode_jwt);
use File::Slurp;
use Try::Tiny;

use Gion::Config;

sub authorize {
    my ($self, $page) = @_;

    my $cookies_hashref = crush_cookie($page->req->header('Cookie'));

    my $jwt_config = config->param('jwt');
    my $decoded;
    if (my $raw_jwt = $cookies_hashref->{$jwt_config->{cookie_name}}) {
        $decoded = _decode_jwt($raw_jwt);
    }

    my $login = $decoded && $decoded->{user_id} ? $decoded->{user_id} : undef;
    my $xhr = lc ($page->req->header('X-Requested-With') || '') eq 'xmlhttprequest';
    my $origin = $self->check_origin_header($page);

    if ($login && $xhr && $origin) {
        $page->pad->param(user_id => $decoded->{user_id});
        $page->res->code(200);
    } else {
        $page->res->code(401);
        $page->finished(1);
    }
}

sub _decode_jwt {
    my $encoded = shift;

    my $jwt_config = config->param('jwt');
    my $decoded;
    try {
        $decoded = decode_jwt(
            token        => $encoded,
            key          => \$jwt_config->{private_key},
            accepted_alg => $jwt_config->{alg},
            accepted_enc => $jwt_config->{enc},
        );
    } catch {
        warn $_;
    };
    return $decoded;
}

1;

