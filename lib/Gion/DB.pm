package Gion::DB;

use strict;
use warnings;
use utf8;

use Scope::Container::DBI;

use Gion::Config;

sub new {
    my $class = shift;

    my $config = config->param('db');
    Scope::Container::DBI->connect(
        $config->{dsn}, $config->{username}, $config->{password},
        {
            RootClass => 'DBIx::Sunny',
            mysql_enable_utf8mb4 => 1,
        }
    );
}

1;

__END__

http://blog.nomadscafe.jp/2011/04/scopecontainerdbi-amon2dbi.html

