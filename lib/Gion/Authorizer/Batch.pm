package Gion::Authorizer::Batch;

use strict;
use warnings;
use utf8;

use parent qw/Pulltoy::Authorizer/;

use Gion::Config;

sub authorize {
    my ($self, $page) = @_;

    my $batch_token = config->param('batch_token');
    my $token = ($page->req->header('Authorization') || '') eq "BatchToken $batch_token";

    if ($token) {
        $page->res->code(200);
    } else {
        $page->res->code(401);
        $page->finished(1);
    }
}

1;

