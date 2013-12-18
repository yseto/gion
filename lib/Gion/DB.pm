package Gion::DB;
use DBIx::Handler;
use DBIx::Sunny;

use File::Spec;
use File::Basename;

our $conf;

BEGIN {
    my $d = File::Spec->catdir(dirname((caller 0)[1]) , '..','..');
    my $c = eval slurp(File::Spec->catfile($d, 'gion.conf'));

    sub slurp {
        my $p = shift;
        open my $f, '<', $p;
        my $c = '';
        while ( $f->sysread( my $b, 131072, 0 ) ) { $c .= $b }
        $c;
    }

    $conf = $c->{db};
}

sub new {
    my $h = DBIx::Handler->new($conf->{dsn}, $conf->{username}, $conf->{password}, 
        {RootClass => 'DBIx::Sunny',});
    return $h;
}

1;
