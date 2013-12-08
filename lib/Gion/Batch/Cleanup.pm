package Gion::Batch::Cleanup;
use base qw/Gion::Batch/;
use Gion::DB;

# 既読のものを削除する。
# ただし、最新の既読エントリは残しておく必要がある
# （そこを目印に、RSSの読み取りが行われるため）

#  http://stackoverflow.com/questions/8886026/mysql-delete-all-but-latest-x-records

sub run {
    my $self   = shift;

    my $count;
    my $cmp;

    my $db = Gion::DB->new;

    $count = $db->dbh->select_row('SELECT COUNT(guid) AS t FROM entries');
    $cmp->{olde} = $count->{t};
    $count = $db->dbh->select_row('SELECT COUNT(guid) AS t FROM stories');
    $cmp->{olds} = $count->{t};

    my $rs = $db->dbh->select_all('SELECT id FROM target');

    for (@$rs){
        my $id = $_->{id};
        $db->dbh->query("DELETE FROM entries WHERE _id_target = ? AND readflag = 1
            AND updatetime < DATE_ADD(CURRENT_TIMESTAMP, INTERVAL -1 DAY)
            AND 
    		pubdate NOT IN (SELECT pubdate FROM 
    			(SELECT pubdate FROM entries
    				WHERE _id_target = ?  AND readflag = 1
    				ORDER BY pubdate DESC LIMIT 1
    			) x )"
            , $id, $id );
#       print $id . "\n";
    }

    $db->dbh->query('OPTIMIZE TABLE entries;');
    $db->dbh->query('DELETE FROM stories WHERE guid NOT IN (SELECT guid FROM entries);');
    $db->dbh->query('OPTIMIZE TABLE stories;');

    $count = $db->dbh->select_row('SELECT COUNT(guid) AS t FROM entries');
    $cmp->{e} = $count->{t};
    $count = $db->dbh->select_row('SELECT COUNT(guid) AS t FROM stories');
    $cmp->{s} = $count->{t};

    printf "entries %d -> %d \n", $cmp->{olde}, $cmp->{e};
    printf "stories %d -> %d \n", $cmp->{olds}, $cmp->{s};

}

1;
