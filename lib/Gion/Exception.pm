package Gion::Exception;

use strict;
use warnings;
use utf8;

sub new {
    my ($class, %attr) = @_;
    bless \%attr, $class;
}

sub throw {
    my ($class, %attr) = @_;
    die $class->new(%attr);
}

sub body { shift->{body} }
sub code { shift->{code} }

1;

