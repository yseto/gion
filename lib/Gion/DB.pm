package Gion::DB;

use strict;
use warnings;
use utf8;

use Scope::Container::DBI;

use Gion::Config;

sub new {
    my $class = shift;

    my $config = config->param('db');
    my $dsn = $config->{dsn};
    my %mysql_attr = (
        mysql_enable_utf8mb4 => 1,
    );
    my %sqlite_attr = (
        sqlite_use_immediate_transaction => 1,
        sqlite_unicode => 1,
    );

    my $dbh = Scope::Container::DBI->connect(
        $dsn, $config->{username}, $config->{password},
        {
            RootClass => 'DBIx::Sunny',
            ($dsn =~ /mysql/) ? %mysql_attr : %sqlite_attr,
        }
    );
}

1;

__END__

http://blog.nomadscafe.jp/2011/04/scopecontainerdbi-amon2dbi.html

