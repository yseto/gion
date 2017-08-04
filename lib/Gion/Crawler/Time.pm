package Gion::Crawler::Time;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw(
    to_mysql_datetime
    from_mysql_datetime
);

use Time::Piece;

#
# translator datetime
#

sub to_mysql_datetime {
    shift->strftime('%Y-%m-%d %H:%M:%S');
}

sub from_mysql_datetime {
    my $t = shift;
    if ($t eq '0000-00-00 00:00:00') {
        return Time::Piece->new;
    }
    localtime( Time::Piece->strptime( $t, '%Y-%m-%d %H:%M:%S' ) );
}

1;
