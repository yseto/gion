package Gion::Crawler::Subscription;

use strict;
use warnings;
use utf8;

use Class::Accessor::Lite (
    new => 1,
    rw  => [ qw(
        id
        category_id
        feed_id
        user_id
    ) ],
);

use Gion::Crawler::Time;
use Gion::Data;
use Gion::DB;

use Carp;

sub data { Gion::Data->new(dbh => Gion::DB->new) }

sub load {
    my ($self, %attr) = @_;
    $self->$_($attr{$_}) for keys %attr;
}

sub latest_entry {
    my $self = shift;

    my $data = $self->data;
    my $pubdate = $data->latest_entry_pubdate_by_subscription(id => $self->id);

    return unless $pubdate;
    from_mysql_datetime($pubdate);
}

1;
