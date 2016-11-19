package Gion::View;

use strict;
use warnings;
use utf8;

use Exporter 'import';
our @EXPORT = qw(render text html json csrf_field);

use Encode;
use File::Spec;
use JSON;
use Text::Xslate qw(mark_raw);

use Gion::Config;

my $XSLATE = Text::Xslate->new(
    syntax => 'TTerse',
    path => [ File::Spec->catdir(config->root,'templates') ],
);

sub render {
    my ($r, $name, $vars) = @_;
    $vars = {
        %{ $vars || {} },
        r => $r,
    };
    my $content = $XSLATE->render($name, $vars);
}
    
sub text {
    my ($r, $vars) = @_;
    $r->res->content_type('text/plain; charset=utf-8');
    $r->res->content($vars);
}

sub html {
    my ($r, $name, $vars) = @_;
    $r->res->content_type('text/html; charset=utf-8');
    $r->res->content(encode_utf8 $r->render($name, $vars));
}

sub json {
    my ($r, $vars, %opts) = @_;
    my $body = JSON::XS->new->ascii(1)->encode($vars);
    $r->res->content_type('application/json; charset=utf-8');
    $r->res->content($body);
}

sub csrf_field {
    my ($r) = @_;
    mark_raw '<input type="hidden" name="_token" value="'. $r->csrf_token .'">';
}

1;

