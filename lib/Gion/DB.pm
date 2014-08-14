package Gion::DB;
use DBIx::Handler;
use DBIx::Sunny;

use File::Spec;
use File::Basename;

our $conf;
our $engine;

BEGIN {
    my $d = File::Spec->catdir(dirname((caller 0)[1]) , '..','..');
    my $c;
    if ( -e File::Spec->catfile($d, 'gion.conf')) {
        $c = eval slurp(File::Spec->catfile($d, 'gion.conf'));
    }else{
        # heroku addon cleardb
        if (my $var = $ENV{CLEARDB_DATABASE_URL}){
            if( $var =~ m,mysql://(.*):(.*)@(.*)/(.*), ){
                my ($username, $password, $hostname, $database) = ($1, $2, $3, $4);
                $c->{db}->{username} = $username;
                $c->{db}->{password} = $password;
                $database =~ s/(.*)\?(.*)/$1/;
                $c->{db}->{dsn} = sprintf "dbi:mysql:database=%s:host=%s", $database, $hostname;
            }
        }
    }

    sub slurp {
        my $p = shift;
        open my $f, '<', $p;
        my $c = '';
        while ( $f->sysread( my $b, 131072, 0 ) ) { $c .= $b }
        $c;
    }

    $conf = $c->{db};
    if ($conf->{dsn} =~ /^(?i:dbi):SQLite:/){
        $engine = "SQLite";
    }else{
        $engine = "mysql";
    }
}

sub new {
    my $h = DBIx::Handler->new($conf->{dsn}, $conf->{username}, $conf->{password}, 
        {RootClass => 'DBIx::Sunny',});
    $h->dbh->query('PRAGMA foreign_keys = ON;') if $engine eq "SQLite";
    return $h;
}

1;
