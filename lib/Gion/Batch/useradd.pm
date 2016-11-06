package Gion::Batch::useradd;
use Mojo::Base 'Mojolicious::Command';
use Getopt::Long qw(GetOptionsFromArray :config posix_default no_ignore_case gnu_compat);

use Gion::Util::Auth;

has description => 'user management';
has usage => '--user ID --pass Password';

sub run {
    my $self = shift;
    my $data;
    GetOptionsFromArray(
        \@_,
        "user=s"    => \$data->{user},
        "password=s"    => \$data->{password},
        "overwrite" => \$data->{force},
    );

    unless ( defined $data->{user} || defined $data->{password} ) {
        say "need parameter: --user ID --password Password";
        exit();
    }

    my $auth = Gion::Util::Auth->new(
        strech => $self->app->config->{strech} || 500,
        salt   => $self->app->config->{salt}   || "Gion::Util::Auth",
        id     => $data->{user},
        password => $data->{password},
    );

    my $password = $auth->get_hash;

    my $db = $self->app->dbh;
    if ( defined $data->{force} ) {
        $db->dbh->query( 'UPDATE user SET password = ? WHERE name = ?',
            $password, $data->{user} );
        say "Password Change: " . $data->{user};
    }
    else {
        $db->dbh->query( 'INSERT INTO user (id,password,name) VALUES (null,?,?)',
            $password, $data->{user} );
        say "User Added: " . $data->{user};
    }
}

1;

=encoding utf8

=head1 NAME

Gion::Batch::useradd - user management

=cut
