package Gion::Crawler::Entry;

use strict;
use warnings;
use utf8;

use Gion::Crawler::Time;

use Class::Accessor::Lite (
    new => 1,
    rw  => [ qw(
        title
        description
        pubdate
        url
    ) ],
    ro  => [ qw(db) ],
);

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

    $self->db->query('
        INSERT IGNORE INTO entry 
        (pubdate, readflag, subscription_id, update_at, user_id, feed_id, serial)
        VALUES (?,0,?,CURRENT_TIMESTAMP,?,?,?)
    ',
    to_mysql_datetime($self->pubdate),
    $attr{subscription_id},
    $attr{user_id},
    $attr{feed_id},
    $attr{serial},
    );

}

sub insert_story {
    my ($self, %attr) = @_;

    $self->db->query('INSERT IGNORE INTO story
        (title, description, url, serial, feed_id) VALUES (?,?,?,?,?)',
        ($self->title       ? $self->title       : ''),
        ($self->description ? $self->description : ''),
        $self->url,
        $attr{serial},
        $attr{feed_id},
    );
}



1;

