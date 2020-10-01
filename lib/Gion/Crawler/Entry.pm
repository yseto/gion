package Gion::Crawler::Entry;

use strict;
use warnings;
use utf8;

use Gion::Crawler::Time;
use Gion::Data;
use Gion::DB;

use Class::Accessor::Lite (
    new => 1,
    rw  => [ qw(
        title
        description
        pubdate
        url
    ) ],
);

sub data { Gion::Data->new(dbh => Gion::DB->new) }

sub pubdate_epoch {
    my $self = shift;
    $self->pubdate->epoch;
}

#
# insert
#

sub insert_entry {
    my ($self, %attr) = @_;

    die 'missing: subscription_id' if not defined $attr{subscription_id};
    die 'missing: user_id' if not defined $attr{user_id};

    my $data = $self->data;
    $data->insert_entry(
        user_id         => $attr{user_id},
        feed_id         => $attr{feed_id},
        serial          => $attr{serial},
        subscription_id => $attr{subscription_id},
        pubdate         => to_mysql_datetime($self->pubdate),
    );
}

sub insert_story {
    my ($self, %attr) = @_;

    my $data = $self->data;
    $data->insert_story(
        feed_id     => $attr{feed_id},
        serial      => $attr{serial},

        title       => ($self->title       ? $self->title       : ''),
        description => ($self->description ? $self->description : ''),
        url         => $self->url,
    );
}

1;

