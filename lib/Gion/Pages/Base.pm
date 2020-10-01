package Gion::Pages::Base;

use strict;
use warnings;
use utf8;

use parent qw/Pulltoy/;

use JSON::XS;

use Pulltoy::Authorizer;

use Gion::Data;
use Gion::DB;

sub create_authorizer { Pulltoy::Authorizer->new(shift) }

sub data { Gion::Data->new(dbh => Gion::DB->new) }

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

