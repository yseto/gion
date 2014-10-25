package Gion::Batch;

use File::Spec;
use File::Basename;

our $conf, $dir;

BEGIN {
    $d = File::Spec->catdir( dirname( ( caller 0 )[1] ), '..', '..' );
    my $c;
    if ( -e File::Spec->catfile( $d, 'gion.conf' ) ) {
        $c = eval slurp( File::Spec->catfile( $d, 'gion.conf' ) );
    }
    else {
        $c->{__nothing_files} = 1;
    }

    sub slurp {
        my $p = shift;
        open my $f, '<', $p;
        my $c = '';
        while ( $f->sysread( my $b, 131072, 0 ) ) { $c .= $b }
        $c;
    }
    $conf = $c;
    $dir  = File::Spec->_collapse($d);
}

sub new {
    my $class = shift;
    my $self  = {
        config  => $conf,
        homedir => $dir,
    };
    bless $self, $class;
}

sub config {
    my $self = shift;
    return $self->{config};
}

sub homedir {
    my $self = shift;
    return $self->{homedir};
}

1;
