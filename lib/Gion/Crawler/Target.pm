package Gion::Crawler::Target;

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
    ro => [ qw(db) ],
);

use Gion::Crawler::Time;

use Carp;

sub load {
    my ($self, %attr) = @_;
    $self->$_($attr{$_}) for keys %attr;
}

sub latest_entry {
    my $self = shift;

    my $latest_entry_pubdate = $self->db->select_one('
        SELECT pubdate
        FROM entry
        WHERE target_id = ? 
            AND readflag = 1
        ORDER BY pubdate DESC
        LIMIT 1
    ',
        $self->id
    );

    return unless $latest_entry_pubdate;
    from_mysql_datetime($latest_entry_pubdate);
}

1;
