package Gion::Util::Auth;
use Mojo::Util qw/sha1_sum/;

sub new {
    my ( $class, %opt ) = @_;
    my $self;
    while ( my ( $key, $value ) = each %opt ) {
        $self->{$key} = $value;
    }
    bless $self, $class;
    $self;
}

sub get_hash {
    my $self = shift;
    my $hash = '';

    return undef unless defined $self->{id} and length( $self->{id} ) > 0;
    return undef
      unless defined $self->{passwd} and length( $self->{passwd} ) > 0;
    return undef unless defined $self->{salt};
    return undef unless defined $self->{strech};

    my $salt = $self->{id} . pack( 'H*', $self->{salt} );

    for ( my $i = 0 ; $i < $self->{strech} ; $i++ ) {
        $hash = sha1_sum( $hash . $self->{passwd} . $salt );
    }
    $hash;
}

1;

