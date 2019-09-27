package Gion::Scripts::Crawler;

use strict;
use warnings;
use utf8;

use Gion;
use Gion::Config;
use Gion::Crawler::Entry;
use Gion::Crawler::Feed;
use Gion::Crawler::Subscription;
use Gion::Crawler::Time;
use Gion::Crawler::UserAgent;

use Getopt::Long qw(GetOptionsFromArray);
use HTTP::Date qw(str2time);
use Try::Tiny;

sub main_script {
    my ($class, @argv) = @_;

    #DBへ接続
    my $db = Gion->cli_dbh;

    # 指定取得などのオプション読み込み
    my $eid;
    my $term;
    GetOptionsFromArray(\@argv,
        'e=i{,}' => \@$eid,
        'silent' => \(my $silent),
        'term=i' =>\$term,
    );

    #取得先を取得
    my $list;
    if (@$eid) {
        $list = $db->select_all(
            'SELECT * FROM feed WHERE id IN :entry_id',
            { entry_id => $eid }
        );
    } elsif ($term) {
        $list = $db->select_all('SELECT * FROM feed WHERE term = ?', $term);
    } else {
        $list = $db->select_all('SELECT * FROM feed');
    }

    bless {
        list => $list,
        silent => $silent,
        db => $db,
        tolerance_time => (time + 86400*7),
    }, $class;
}

sub main_proclet {
    my ($class, $term) = @_;

    #DBへ接続
    my $db = Gion->cli_dbh;

    my $list = $db->select_all('SELECT * FROM feed WHERE term = ?', $term);

    bless {
        list => $list,
        silent => 0,
        db => $db,
        tolerance_time => (time + 86400*7),
    }, $class;
}

sub crawl {
    my $self = shift;

    my $ua_config = config->param('crawler');
    my $ua = Gion::Crawler::UserAgent->new(%$ua_config);

    for my $feed (@{$self->{list}}) {
        $self->crawl_per_feed($ua, $feed);
    }
}

sub crawl_per_feed {
    my ($self, $ua, $feed) = @_;

    my $db = $self->{db};

    my $feed_model = Gion::Crawler::Feed->new(
        db => $db,
        verbose => $self->{silent} ? 0 : 1,
    );

    # モデルに読み込み
    $feed_model->load(%$feed);

    # 取得する
    my $cache = $feed_model->get_cache;
    $ua->get($feed_model->url, %$cache);

    # 結果が得られない場合、次の対象を処理する
    if ($ua->code eq '404' or $ua->code =~ /5\d\d/) {
        $feed_model->catch_error(response => $ua->response);
        return;
    }

    # 301 Moved Permanently の場合
    if ($ua->location) {
        $feed_model->catch_redirect(location => $ua->location);
    }

    $feed_model->logger('%3d %4d %s',
        $ua->code, $feed_model->id, $feed_model->title);

    # 304 Not Modified の場合更新しない、次の対象を処理する
    if ($ua->code eq '304') {
        $feed_model->catch_notmodified(response => $ua->response);
        return;
    }

    my $onerror = 0;
    my @data;

    # 保存されている設定を元にパースする
    try {
        if      ($feed_model->parser == 1) {
            @data = $feed_model->parse_rss($ua->content);
        } elsif ($feed_model->parser == 2) {
            @data = $feed_model->parse_atom($ua->content);
        }
    } catch {
        $onerror = 1;
    };

    # パーサーの設定がない場合
    if ($feed_model->parser == 0) {
        my $parser_type = 0;
PARSE_RSS:
        try {
            @data = $feed_model->parse_rss($ua->content);
        } catch {
            goto PARSE_ATOM; # RSS でないので ATOM としてパース
        };
        $parser_type = 1;
        goto SAVE_PARSER;

PARSE_ATOM:
        try {
            @data = $feed_model->parse_atom($ua->content);
        } catch {
            goto PARSE_FAIL; # パース失敗として処理
        };
        $parser_type = 2;
        goto SAVE_PARSER;

SAVE_PARSER:
        # パーサ種類を保存
        $feed_model->update_parser(parser => $parser_type);
        goto PARSE_SUCCESS;

PARSE_FAIL:
        $onerror = 1;
    }
PARSE_SUCCESS:

    # パースに RSS 、 ATOM いずれも失敗した場合、設定を初期化
    # 次回のクロール時にクロールする
    if ($onerror) {
        $feed_model->catch_parse_error(
            response => $ua->response,
            code => $ua->code
        );
        return;
    }

    # クロール対象のフィードのDBに保存してある最新の情報の
    # 日付を取得する
    my $latest = from_mysql_datetime($feed_model->pubdate);

    # Last-Modified を取得
    # UserAgent の戻り値では、 If-Modified-Since として返却される
    my $last_modified = str2time($ua->response->{'If-Modified-Since'});

    my $import_counter = 0;

    # フィードのエントリを日付順 新 -> 古 にする
    @data = sort { $b->pubdate_epoch <=> $a->pubdate_epoch } @data;

    for my $entry (@data) {

        # If-Modified-Since が取得できなかった場合、RSSのフィードから得る
        unless ($last_modified) {
            $last_modified = $entry->pubdate_epoch;
        }

        # 新しいもののみを取り込む XXX デバッグ時は以下を抑止
        next if $entry->pubdate_epoch <= $latest->epoch;
        # 遠い未来のエントリは取り込まない
        next if $self->{tolerance_time} <= $entry->pubdate_epoch;

        # フィードのデータから最終更新時間を更新する
        if ($entry->pubdate_epoch > $last_modified) {
            $last_modified = $entry->pubdate_epoch;
        }

        # 取り込み対象となるため、次回取得対象としてマーク
        $import_counter++;

        my $subscription_model = Gion::Crawler::Subscription->new(db => $db);

        # 購読リストを取得する
        my $subscriptions = $db->select_all('SELECT * FROM subscription WHERE feed_id = ?',
            $feed_model->id);

        my $serial = $feed_model->get_next_serial;
        $feed_model->logger('GENERATE serial:%d', $serial);

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

                $feed_model->logger('INSERT user_id:%4d feed_id:%d serial:%d',
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
}

1;
