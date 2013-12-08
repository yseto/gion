package Gion::Batch::Test;
use base qw/Gion::Batch/;

use Getopt::Long qw(GetOptionsFromArray);

use Data::Dumper;

# ./env batch test --rec 1 --paa abcd
# $VAR1 = {
#           'paa' => 'abcd',
#           'rec' => 1
#         };

sub run {
    my $self   = shift;
    warn Dumper $self->config;
    warn Dumper $self->homedir;
    my $data;
    GetOptionsFromArray(\@_, 
        "rec=i"   => \$data->{rec},
        "paa=s"   => \$data->{paa},
    );
    warn Dumper $data;
}

1;
