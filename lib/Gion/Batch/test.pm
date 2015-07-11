package Gion::Batch::test;
use Mojo::Base 'Mojolicious::Command';

use Getopt::Long qw(GetOptionsFromArray :config posix_default no_ignore_case gnu_compat);

has description => 'TEST.';
has usage => sub { shift->extract_usage };

use Data::Dumper;

sub run {
    my ($self, @args) = @_;

my $db = $self->app->dbh;
    
for (@{ $db->dbh->select_all('SELECT id FROM target') }) {
    warn  $_->{id};
}
 
    my $data;
    GetOptionsFromArray(
        \@args,
        "rec=i" => \$data->{rec},
        "paa=s" => \$data->{paa},
    );
#   warn Dumper $self;

#   warn Dumper $data;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Command::cpanify - Cpanify command

=head2 usage

Usage information for this command, used for the help screen.

=cut
