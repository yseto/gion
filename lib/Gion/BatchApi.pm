package Gion::BatchApi;

use strict;
use warnings;
use utf8;
use parent qw/Gion::Base/;

use Encode;
use FormValidator::Lite;

use Gion::Authorizer::Batch;
use Gion::Scripts::Crawler;
use Gion::Scripts::Cleanup;

sub create_authorizer { Gion::Authorizer::Batch->new(shift) }

sub dispatch_feed_terms {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check( term => ['NOT_NULL', 'UINT'], );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/term/;

    my $db = $self->dbh;
    my $handler = Gion::Scripts::Crawler->main_api($db, term => $values{term});

    $self->json({ feed_id => [map { $_->{id} } @{$handler->{list}}] });
}

sub dispatch_retrieve_feed {
    my $self = shift;

    if (lc($self->req->method) ne 'put') {
        $self->res->code(405);
        return;
    }

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check( id => ['NOT_NULL', 'UINT'], );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/id/;

    my $db = $self->dbh;
    my $handler = Gion::Scripts::Crawler->main_api($db, id => $values{id})->crawl;

    $self->res->code(202);
}

sub dispatch_cleanup {
    my $self = shift;

    if (lc($self->req->method) ne 'delete') {
        $self->res->code(405);
        return;
    }

    my $db = $self->dbh;
    my $handler = Gion::Scripts::Cleanup->main_api($db);

    $self->res->code(202);
}

1;

