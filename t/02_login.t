use strict;
use warnings;

use HTTP::Request;
use Plack::Test;
use Plack::Util;
use Test::More;
use Test::mysqld;
use Test::WWW::Mechanize::PSGI;
use File::Slurp;

use Gion::Util;
use Gion::Config;

$ENV{PLACK_ENV} = 'test';

my $mysqld = Test::mysqld->new;
my $dsn = $mysqld->dsn;

my $guard = config->local(db => {dsn => $dsn}); 

my $app = Plack::Util::load_psgi('app.psgi');

# load schema.
my $dbh = DBI->connect($dsn);
my $source = read_file('templates/config/mysql.sql');
for my $stmt (split /;/, $source) {
    next unless $stmt =~ /\S/;
    $dbh->do($stmt) or die $dbh->errstr;
}

# generate user account.
my $auth = Gion::Util::auth(
    salt => config->param('salt'),
    strech => config->param('strech'),
    id => "admin",
    password => "password123456",
);

$dbh->do("INSERT INTO user (id, password, name) VALUES (null, '$auth', 'admin')");

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

$mech->get_ok('/');
$mech->content_contains('Please sign in');
$mech->submit_form_ok({
    form_number => 1,
    fields      => {
        id => 'admin',
        password => 'password123456',
    }
}, "login form");

$mech->content_contains('/static/gion.js', 'check javascript');
$mech->get_ok('/logout', 'logout ok');
$mech->content_contains('Please sign in');

done_testing;

__END__

