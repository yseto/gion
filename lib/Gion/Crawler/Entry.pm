package Gion::Crawler::Entry;

use strict;
use warnings;
use utf8;

use Gion::Crawler::Time;

use Class::Accessor::Lite (
    new => 1,
    rw  => [ qw(
        guid
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
        (guid, pubdate, readflag, subscription_id, update_at, user_id)
        VALUES (?,?,0,?,CURRENT_TIMESTAMP,?)
    ',
    $self->guid,
    to_mysql_datetime($self->pubdate),
    $attr{subscription_id},
    $attr{user_id},
    );

}

sub insert_story {
    my ($self, %attr) = @_;

    $self->db->query('INSERT IGNORE INTO story
        (guid, title, description, url) VALUES (?,?,?,?)',
        $self->guid,
        ($self->title       ? $self->title       : ''),
        ($self->description ? $self->description : ''),
        $self->url,
    );
}



1;

