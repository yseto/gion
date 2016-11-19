package Gion::Util;
use Digest::SHA qw/sha1_hex/;

sub auth {
    my ($class, %opt) = @_;

    return undef unless defined $opt{id} and length( $opt{id} ) > 0;
    return undef
      unless defined $opt{password} and length( $opt{password} ) > 0;
    return undef unless defined $opt{salt};
    return undef unless defined $opt{strech};

    my $salt = $opt{id} . pack( 'H*', $opt{salt} );

    my $hash = '';
    for ( my $i = 0 ; $i < $opt{strech} ; $i++ ) {
        $hash = sha1_hex join '', $hash, $opt{password}, $salt;
    }
    $hash;
}

1;

