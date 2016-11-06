package Gion::Batch::cleanup;
use Mojo::Base 'Mojolicious::Command';

has description => 'item cleaner';
has usage => 'supported some options.';

# 既読のものを削除する。
# ただし、最新の既読エントリは残しておく必要がある
# （そこを目印に、RSSの読み取りが行われるため）

#  http://stackoverflow.com/questions/8886026/mysql-delete-all-but-latest-x-records

sub run {
    my $self = shift;

    my $count;
    my $cmp;

    my $db = $self->app->dbh;

    $count       = $db->dbh->select_row('SELECT COUNT(guid) AS t FROM entry');
    $cmp->{olde} = $count->{t};
    $count       = $db->dbh->select_row('SELECT COUNT(guid) AS t FROM story');
    $cmp->{olds} = $count->{t};

    my $rs = $db->dbh->select_all('SELECT id FROM target');

    for (@$rs) {
        my $id = $_->{id};
        $db->dbh->query(
            "DELETE FROM entry WHERE target_id = ? AND readflag = 1
            AND updatetime < DATE_ADD(CURRENT_TIMESTAMP, INTERVAL -1 DAY)
            AND 
	    	pubdate NOT IN (SELECT pubdate FROM 
	    		(SELECT pubdate FROM entry
	    			WHERE target_id = ?  AND readflag = 1
	    			ORDER BY pubdate DESC LIMIT 1
	    		) x )"
            , $id, $id
        );
        #       print $id . "\n";
    }

    my $entry = $db->dbh->select_all("SELECT * FROM entry;");
    for (@$entry) {
        my $target =
          $db->dbh->select_row( "SELECT COUNT(*) AS t FROM target WHERE id = ?",
            $_->{target_id} );
        unless ( $target->{t} > 0 ) {
            $db->dbh->query( "DELETE FROM entry WHERE target_id = ?",
                $_->{target_id} );
        }
    }

    my $feed = $db->dbh->select_all("SELECT * FROM feed;");
    for (@$feed) {
        my $target = $db->dbh->select_row(
            "SELECT COUNT(*) AS t FROM target WHERE feed_id = ?",
            $_->{id} );
        unless ( $target->{t} > 0 ) {
            printf "remove target: %s \n", $_->{siteurl};
            $db->dbh->query( "DELETE FROM feed WHERE id = ?", $_->{id} );
        }
    }

    $db->dbh->query('OPTIMIZE TABLE entry;');
    $db->dbh->query('DELETE FROM story WHERE guid NOT IN (SELECT guid FROM entry);');
    $db->dbh->query('OPTIMIZE TABLE story;');

    $count    = $db->dbh->select_row('SELECT COUNT(guid) AS t FROM entry');
    $cmp->{e} = $count->{t};
    $count    = $db->dbh->select_row('SELECT COUNT(guid) AS t FROM story');
    $cmp->{s} = $count->{t};

    printf "entry %d -> %d \n", $cmp->{olde}, $cmp->{e};
    printf "story %d -> %d \n", $cmp->{olds}, $cmp->{s};
}

1;

=encoding utf8

=head1 NAME

Gion::Batch::cleanup - item cleaner.

=cut
