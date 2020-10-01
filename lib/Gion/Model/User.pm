package Gion::Model::User;

use strict;
use warnings;
use utf8;

use Class::Accessor::Lite (
    new => 1,
    rw  => [ qw(numentry nopinlist numsubstr digest) ],
    ro  => [ qw(id name) ],
);

use Digest;
use Data::Entropy::Algorithms qw(rand_bits);

use Gion::Config;

sub generate_secret_digest {
    my $self = shift;
    my $raw_password = shift;

    my $bcrypt = Digest->new('Bcrypt', cost => 8, salt => rand_bits(16*8));
    my $digest =
        $bcrypt->settings() .
        $bcrypt->add($raw_password)->bcrypt_b64digest;

    return $digest;
}

sub check_password_digest {
    my ($self, $raw_password) = @_;

    my $bcrypt = Digest->new('Bcrypt', settings => $self->digest);
    my $cmp_digest =
        $bcrypt->settings() .
        $bcrypt->add($raw_password)->bcrypt_b64digest;

    return $self->digest eq $cmp_digest;
}

1;

