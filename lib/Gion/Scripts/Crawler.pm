package Gion::Scripts::Crawler;

use strict;
use warnings;
use utf8;

use Gion::Config;
use Gion::Crawler::Entry;
use Gion::Crawler::Feed;
use Gion::Crawler::Subscription;
use Gion::Crawler::Time;
use Gion::Crawler::UserAgent;
use Gion::Data;
use Gion::DB;

use Encode;
use Getopt::Long qw(GetOptionsFromArray);
use HTTP::Status qw(:constants :is);
use Log::Minimal;
use Scope::Container;
use Try::Tiny;

sub data { Gion::Data->new(dbh => Gion::DB->new) }

sub main_script {
    my ($class, @argv) = @_;

    my $container = start_scope_container();
    my $data = $class->data;

    # 指定取得などのオプション読み込み
    my $eid;
    my $term;
    GetOptionsFromArray(\@argv,
        'e=i{,}' => \@$eid,
        'term=i' =>\$term,
    );

    #取得先を取得
    my $list;
    if (@$eid) {
        $list = $data->feed_by_id_range(id => $eid);
    } elsif ($term) {
        $list = $data->feed_by_term(term => $term);
    } else {
        $list = $data->feed;
    }

    bless {
        scope_container => $container,
        list => $list,
        tolerance_time => (time + 86400*7),
    }, $class;
}

sub main_proclet {
    my ($class, $term) = @_;

    my $container = start_scope_container();
    my $data = $class->data;

    bless {
        scope_container => $container,
        list => $data->feed_by_term(term => $term),
        tolerance_time => (time + 86400*7),
    }, $class;
}

sub main_api {
    my ($class, %args) = @_;

    my $data = $class->data;

    my $list = ($args{term}) ?
        $data->feed_by_term(term => $args{term}) :
        [ $data->feed_by_id(id => $args{id}) ];

    bless {
        list => $list,
        tolerance_time => (time + 86400*7),
    }, $class;
}

sub crawl {
    my $self = shift;

    for my $feed (@{$self->{list}}) {
        $self->crawl_per_feed($feed);
    }
}

sub crawl_per_feed {
    my ($self, $feed) = @_;

    my $ua_config = config->param('crawler');
    my $ua = Gion::Crawler::UserAgent->new(%$ua_config);

    my $data = $self->data;
    my $txn = $data->dbh->txn_scope;

    my $feed_model = Gion::Crawler::Feed->new;

    # モデルに読み込み
    $feed_model->load(%$feed);

    # 取得する
    my $cache = $feed_model->get_cache;
    $ua->get($feed_model->url, %$cache);

    # 結果が得られない場合、次の対象を処理する
    if (is_error($ua->code)) {
        $feed_model->catch_error(response => $ua->response);
        $txn->commit;
        return;
    }

    # 301 Moved Permanently の場合
    if ($ua->location) {
        $feed_model->catch_redirect(location => $ua->location);
    }

    debugf('%3d %4d %s',
        $ua->code, $feed_model->id, encode_utf8($feed_model->title));

    # 304 Not Modified の場合更新しない、次の対象を処理する
    if ($ua->code eq '304') {
        $feed_model->catch_notmodified(response => $ua->response);
        $txn->commit;
        return;
    }

    my $onerror = 0;
    my @data;

    my $content = $ua->content;
    # XML 文書に含まれてはいけない文字を除去する
    # https://stackoverflow.com/questions/1016910/how-can-i-strip-invalid-xml-characters-from-strings-in-perl
    $content =~ s/[^\x09\x0A\x0D\x20-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}]//go;

    try {
        @data = $feed_model->parse($content);
    } catch {
        $onerror = 1;
    };

    # パースに RSS 、 ATOM いずれも失敗した場合、次回のクロール時にクロールする
    if ($onerror) {
        $feed_model->catch_parse_error(
            response => $ua->response,
            code => $ua->code
        );
        $txn->commit;
        return;
    }

    # クロール対象のフィードのDBに保存してある最新の情報の
    # 日付を取得する
    my $latest = from_mysql_datetime($feed_model->pubdate);

    # last_modified は feed_model->pubdate 更新のため
    my $last_modified = $latest->epoch;
    my $import_counter = 0;

    # フィードのエントリを日付順 新 -> 古 にする
    @data = sort { $b->pubdate_epoch <=> $a->pubdate_epoch } @data;

    for my $entry (@data) {
        # 新しいもののみを取り込む XXX デバッグ時は以下を抑止
        next if $entry->pubdate_epoch <= $latest->epoch;
        # 遠い未来のエントリは取り込まない
        next if $self->{tolerance_time} <= $entry->pubdate_epoch;

        # フィードの記事データからフィードの最終更新時間を更新する
        if ($entry->pubdate_epoch > $last_modified) {
            $last_modified = $entry->pubdate_epoch;
        }

        # 取り込み対象となるため、次回取得対象としてマーク
        $import_counter++;

        my $subscription_model = Gion::Crawler::Subscription->new;

        # 購読リストを取得する
        my $subscriptions = $data->subscription_by_feed_id_for_crawler(
            feed_id => $feed_model->id
        );

        my $serial = $feed_model->get_next_serial;
        debugf('GENERATE serial:%d', $serial);

        for my $subscription (@$subscriptions) {
            # モデルに読み込み
            $subscription_model->load(%$subscription);

            # 既読管理から最終既読の時刻を参照
            my $latest_entry = $subscription_model->latest_entry;

            # 既読データがあれば、状態から取り込みを判断する
            my $state = $latest_entry ?
                $latest_entry < $entry->pubdate : 1;

            if ($state) {
                # 購読リストに基づいて、更新情報をユーザーごとへ挿入
                $entry->insert_entry(
                    subscription_id => $subscription_model->id,
                    user_id         => $subscription_model->user_id,
                    feed_id         => $subscription_model->feed_id,
                    serial          => $serial,
                );

                debugf('INSERT user_id:%4d feed_id:%d serial:%d',
                    $subscription_model->user_id,
                    $subscription_model->feed_id,
                    $serial,
                );
            }
        }

        # エントリに対するストーリーを挿入
        $entry->insert_story(serial => $serial, feed_id => $feed_model->id);
    }

    # 取得したものがあれば、次回もクロールする対象とするため、term => 1
    $feed_model->update_feed_info(
        response => $ua->response,
        code => $ua->code,
        last_modified => $last_modified,
        $import_counter ? (term => 1) : (),
    );
    $txn->commit;
}

1;
