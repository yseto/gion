package Gion::BatchApi;

use strict;
use warnings;
use utf8;

use Encode;
use FormValidator::Lite;
use Gion::Scripts::Crawler;
use Gion::Scripts::Cleanup;

sub feed_terms {
    my ($class, $r) = @_;
    $r->require_batch;

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check( term => ['NOT_NULL', 'UINT'], );
    return $r->json([]) if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($r->req->param($_))) } qw/term/;

    my $db = $r->dbh;
    my $handler = Gion::Scripts::Crawler->main_api($db, term => $values{term});

    $r->json({ feed_id => [map { $_->{id} } @{$handler->{list}}] });
}

sub retrieve_feed {
    my ($class, $r) = @_;
    $r->require_batch;

    if (lc($r->req->method) ne 'put') {
	$r->res->code(405);
	return;
    }

    my $validator = FormValidator::Lite->new($r->req);
    my $res = $validator->check( id => ['NOT_NULL', 'UINT'], );
    return $r->json([]) if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($r->req->param($_))) } qw/id/;

    my $db = $r->dbh;
    my $handler = Gion::Scripts::Crawler->main_api($db, id => $values{id})->crawl;

    $r->res->code(202);
}

sub cleanup {
    my ($class, $r) = @_;
    $r->require_batch;

    if (lc($r->req->method) ne 'delete') {
	$r->res->code(405);
	return;
    }

    my $db = $r->dbh;
    my $handler = Gion::Scripts::Cleanup->main_api($db);

    $r->res->code(202);
}

1;

