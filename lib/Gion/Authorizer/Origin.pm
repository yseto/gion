package Gion::Authorizer::Origin;

use strict;
use warnings;
use utf8;

use parent qw/Pulltoy::Authorizer/;

sub check_origin_header {
    my ($self, $page) = @_;

    my $base = $page->req->base;
    $base =~ s|/$||;
    my $origin = lc ($page->req->header('Origin') || '') eq lc($base);

    return $origin;
}

1;

