package Pulltoy::Pad;

use strict;
use warnings;
use utf8;

# stolen from Sledge::Plugin::ScratchPad
sub new { bless {}, shift }

sub param {
    my $self = shift;
    if (@_ == 0) {
        return keys %$self;
    } elsif (@_ == 1) {
        return $self->{$_[0]};
    } else {
        $self->{$_[0]} = $_[1];
    }
}

sub clear {
    my $self = shift;
    %$self = ();
}

1;

