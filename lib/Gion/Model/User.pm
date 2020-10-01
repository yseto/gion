package Gion::Model::User;

use strict;
use warnings;
use utf8;

use Class::Accessor::Lite (
    new => 1,
    rw  => [ qw(password numentry nopinlist numsubstr) ],
    ro  => [ qw(id name) ],
);

use Digest::SHA qw/sha1_hex/;

use Gion::Config;

sub check_password_digest {
    my ($self, %attr) = @_;

    return $self->generate_password_digest($attr{password}) eq $self->password;
}

sub generate_password_digest {
    my $self = shift;
    my $raw_password = shift;

    $self->_auth(
        id => $self->name,
        password => $raw_password,
    );
}

sub generate_password_digest_with_username {
    my ($class, %attr) = @_;

    $class->_auth(
        id => $attr{username},
        password => $attr{password},
    );
}

sub _auth {
    my ($self, %opt) = @_;

    return undef unless defined $opt{id} and length( $opt{id} ) > 0;
    return undef
      unless defined $opt{password} and length( $opt{password} ) > 0;

    $opt{salt} = config->param('salt');
    $opt{strech} = config->param('strech');

    my $salt = $opt{id} . pack( 'H*', $opt{salt} );

    my $hash = '';
    for ( my $i = 0 ; $i < $opt{strech} ; $i++ ) {
        $hash = sha1_hex join '', $hash, $opt{password}, $salt;
    }
    $hash;
}

1;

