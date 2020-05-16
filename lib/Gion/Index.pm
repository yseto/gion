package Gion::Index;

use strict;
use warnings;
use utf8;

use parent qw/Gion::Base/;

use Gion::Config;

use File::Slurp;
use File::Spec::Functions;

sub dispatch_index {
    my $self = shift;
    $self->res->code(200);
    $self->res->content_type("text/html");
    $self->res->body([read_file(catfile(config->root, "public", "index.html"))]);
    $self->finished(1);
}

1;

