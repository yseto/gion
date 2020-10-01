package Gion::Scripts::Cleanup;

use strict;
use warnings;
use utf8;

# 既読のものを削除する。
# ただし、最新の既読エントリは残しておく必要がある
# （そこを目印に、RSSの読み取りが行われるため）

#  http://stackoverflow.com/questions/8886026/mysql-delete-all-but-latest-x-records

use Scope::Container;

use Gion::Data;
use Gion::DB;

*main_proclet = \&main;
*main_script = \&main;
*main_api = \&main;

sub main {
    my $container = start_scope_container();
    my $dbh = Gion::DB->new;
    my $data = Gion::Data->new(dbh => $dbh);

    start_message($dbh);
    purge_old_entry_by_subscription($data);
    remove_entry($dbh);
    remove_feed($dbh);
    remove_story($dbh);
    finish_message($dbh);
}

sub start_message {
    my $dbh = shift;

    print  "before\n";
    printf "entry %d\n", $dbh->select_one('SELECT COUNT(*) FROM entry');
    printf "story %d\n", $dbh->select_one('SELECT COUNT(*) FROM story');
}

sub purge_old_entry_by_subscription {
    my $data = shift;

    my $rs = $data->subscription;

    for (@$rs) {
        my $txn = $data->dbh->txn_scope;
        $data->purge_old_entry_by_subscription(subscription_id => $_->{id});
        $txn->commit;
    }
}


sub remove_entry {
    my $dbh = shift;

    my $entry = $dbh->select_all("SELECT subscription_id FROM entry;");
    for (@$entry) {
        my $txn = $dbh->txn_scope;

        my $count = $dbh->select_one(
            "SELECT COUNT(*) FROM subscription WHERE id = ?",
            $_->{subscription_id},
        );
    
        unless ($count > 0) {
            $dbh->query(
                "DELETE FROM entry WHERE subscription_id = ?",
                $_->{subscription_id},
            );
        }

        $txn->commit;
    }
}

sub remove_feed {
    my $dbh = shift;

    my $feed = $dbh->select_all("SELECT * FROM feed;");
    for (@$feed) {
        my $txn = $dbh->txn_scope;

        my $count = $dbh->select_one(
            "SELECT COUNT(*) FROM subscription WHERE feed_id = ?",
            $_->{id},
        );
        unless ($count > 0) {
            # printf "remove subscription: %s\n", $_->{siteurl};
            $dbh->query(
                "DELETE FROM feed WHERE id = ?",
                $_->{id},
            );
        }

        $txn->commit;
    }
}

sub remove_story {
    my $dbh = shift;

    my $story = $dbh->select_all("SELECT feed_id, serial, url FROM story");
    for (@$story) {
        my $txn = $dbh->txn_scope;

        my $count = $dbh->select_one(
            "SELECT COUNT(*) FROM entry WHERE feed_id = ? AND serial = ?",
            $_->{feed_id},
            $_->{serial},
        );
        unless ($count > 0) {
            # printf "remove story: %s\n", $_->{url};
            $dbh->query(
                "DELETE FROM story WHERE feed_id = ? AND serial = ?",
                $_->{feed_id},
                $_->{serial},
            );
        }

        $txn->commit;
    }
}

sub finish_message {
    my $dbh = shift;

    print  "after\n";
    printf "entry %d\n", $dbh->select_one('SELECT COUNT(*) FROM entry');
    printf "story %d\n", $dbh->select_one('SELECT COUNT(*) FROM story');
}

1;

