package Gion::Base;

use strict;
use warnings;
use utf8;

use parent qw/Pulltoy/;

use Gion::Config;

use DBIx::Handler::Sunny;
use JSON::XS;
use Pulltoy::Authorizer;

sub create_authorizer { Pulltoy::Authorizer->new(shift) }

sub dbh {
    $_[0]->{dbh} //= do {
        my $conf = config->param('db');
        DBIx::Handler::Sunny->new($conf->{dsn}, $conf->{username}, $conf->{password}, {
            mysql_enable_utf8mb4 => 1,
        });
    };
}

sub json {
    my ($self, $vars) = @_;
    $self->res->code(200);
    $self->res->content_type("application/json; charset=utf-8");
    $self->res->body(encode_json($vars));
    $self->finished(1);
}

sub bad_request {
    my ($self) = @_;
    $self->res->code(400);
    $self->res->content_type("application/json; charset=utf-8");
    $self->finished(1);
}

1;

