package Gion::Middleware::GitHeadRefs;

use strict;
use warnings;
use utf8;

use parent qw(Plack::Middleware);
use File::Spec::Functions ':ALL';
use File::Slurp;
use Plack::Util::Accessor qw(hash);

sub prepare_app {
    my $self = shift;

    my $dir = rel2abs('.');
    my $head_path = catfile($dir, '.git', 'HEAD');

    if (-f $head_path) {
        my $head = read_file($head_path);
        if ($head =~ m/^ref: (.*)$/) {
            my $refs_path = catfile($dir, '.git', split('/', $1));
            if (-f $refs_path) {
                my $hash = read_file($refs_path);
                if ($hash =~ m/^([0-9a-f]{40})$/) {
                    $hash =~ tr/[\r\n]+//d;
                    $self->hash($hash);
                }
            }
        }
    }
}

sub call {
    my($self, $env) = @_;
    $env->{GIT_COMMIT_HASH} = $self->hash;
    return $self->app->($env);
}

1;
