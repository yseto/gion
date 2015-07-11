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

    $count       = $db->dbh->select_row('SELECT COUNT(guid) AS t FROM entries');
    $cmp->{olde} = $count->{t};
    $count       = $db->dbh->select_row('SELECT COUNT(guid) AS t FROM stories');
    $cmp->{olds} = $count->{t};

    my $rs = $db->dbh->select_all('SELECT id FROM target');

    for (@$rs) {
        my $id = $_->{id};
        $db->dbh->query(
            "DELETE FROM entries WHERE _id_target = ? AND readflag = 1
            AND updatetime < DATE_ADD(CURRENT_TIMESTAMP, INTERVAL -1 DAY)
            AND 
	    	pubdate NOT IN (SELECT pubdate FROM 
	    		(SELECT pubdate FROM entries
	    			WHERE _id_target = ?  AND readflag = 1
	    			ORDER BY pubdate DESC LIMIT 1
	    		) x )"
            , $id, $id
        );
        #       print $id . "\n";
    }

    my $entries = $db->dbh->select_all("SELECT * FROM entries;");
    for (@$entries) {
        my $target =
          $db->dbh->select_row( "SELECT COUNT(*) AS t FROM target WHERE id = ?",
            $_->{_id_target} );
        unless ( $target->{t} > 0 ) {
            $db->dbh->query( "DELETE FROM entries WHERE _id_target = ?",
                $_->{_id_target} );
        }
    }

    my $feeds = $db->dbh->select_all("SELECT * FROM feeds;");
    for (@$feeds) {
        my $target = $db->dbh->select_row(
            "SELECT COUNT(*) AS t FROM target WHERE _id_feeds = ?",
            $_->{id} );
        unless ( $target->{t} > 0 ) {
            printf "remove target: %s \n", $_->{siteurl};
            $db->dbh->query( "DELETE FROM feeds WHERE id = ?", $_->{id} );
        }
    }

    $db->dbh->query('OPTIMIZE TABLE entries;');
    $db->dbh->query('DELETE FROM stories WHERE guid NOT IN (SELECT guid FROM entries);');
    $db->dbh->query('OPTIMIZE TABLE stories;');

    $count    = $db->dbh->select_row('SELECT COUNT(guid) AS t FROM entries');
    $cmp->{e} = $count->{t};
    $count    = $db->dbh->select_row('SELECT COUNT(guid) AS t FROM stories');
    $cmp->{s} = $count->{t};

    printf "entries %d -> %d \n", $cmp->{olde}, $cmp->{e};
    printf "stories %d -> %d \n", $cmp->{olds}, $cmp->{s};
}

1;

=encoding utf8

=head1 NAME

Gion::Batch::cleanup - item cleaner.

=cut
