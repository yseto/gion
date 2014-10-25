package Gion::DB;
use DBIx::Handler;
use DBIx::Sunny;
use File::Spec;
use File::Basename;
use Mojo::Util qw/slurp/;

our $conf;
our $engine;
our $template;

BEGIN {
    my $d = File::Spec->catdir( dirname( ( caller 0 )[1] ), '..', '..' );
    my $c;
    if ( -e File::Spec->catfile( $d, 'gion.conf' ) ) {
        $c = eval slurp( File::Spec->catfile( $d, 'gion.conf' ) );
    }
    else {
        # heroku addon cleardb
        if ( my $var = $ENV{CLEARDB_DATABASE_URL} ) {
            if ( $var =~ m,mysql://(.*):(.*)@(.*)/(.*), ) {
                my ( $username, $password, $hostname, $database ) =
                  ( $1, $2, $3, $4 );
                $c->{db}->{username} = $username;
                $c->{db}->{password} = $password;
                $database =~ s/(.*)\?(.*)/$1/;
                $c->{db}->{dsn} = sprintf "dbi:mysql:database=%s:host=%s",
                  $database, $hostname;
            }
        }
    }
    $template = File::Spec->catdir( $d, 'templates', 'config' );

    $conf = $c;
    if ( $conf->{db}->{dsn} =~ /^(?i:dbi):SQLite:/ ) {
        $engine = "SQLite";
        $template = File::Spec->catfile( $template, "sqlite.sql" );
    }
    else {
        $engine = "mysql";
        $template = File::Spec->catfile( $template, "mysql.sql" );
    }
}

sub new {
    my $h = DBIx::Handler->new(
        $conf->{db}->{dsn}, $conf->{db}->{username},
        $conf->{db}->{password}, { RootClass => 'DBIx::Sunny', }
    );
    if ( $engine eq "SQLite" ) {
        $h->dbh->query('PRAGMA foreign_keys = ON;');
    }
    elsif ( $engine eq "mysql" ) {
        sql_loader($h);
    }

    return $h;
}

sub sql_loader {
    my $h = shift;

    my $sql = slurp($template);
    my $c;
    for ( split /\n/, $sql ) {
        if ( $_ eq "/**/" ) {
            $h->dbh->do($c);
            $c = "";
        }
        else {
            $c .= $_;
        }
    }

    use Gion::Util::Auth;
    my $a = Gion::Util::Auth->new(
        strech => $conf->{strech} || 500,
        salt   => $conf->{salt}   || "Gion::Util::Auth",
        id     => "admin",
        passwd => "password",
    );
    my $pw = $a->get_hash;
    my $engine_str = $engine eq "SQLite" ? "OR" : "";
    $h->dbh->query(
        "INSERT $engine_str IGNORE INTO user (id,pw,name) VALUES (null,?,?)",
        $pw, "admin" );

}

1;
