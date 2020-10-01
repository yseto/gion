package Gion::Crawler::Feed;

use strict;
use warnings;
use utf8;

use Class::Accessor::Lite (
    new => 1,
    rw  => [ qw(
        id
        url
        siteurl
        title
        time
        http_status
        parser
        pubdate
        term
        cache
        next_serial
    ) ],
);

use Gion::Crawler::Entry;
use Gion::Crawler::Time;
use Gion::Data;
use Gion::DB;

use Carp;

use Date::Parse;
use DateTime;
use DateTime::Format::ISO8601;
use DateTime::Format::Mail;
use DateTime::Format::W3CDTF;

use Encode;
use HTTP::Date ();
use JSON::XS;
use Log::Minimal;
use Time::Piece;
use Try::Tiny;
use URI;
use XML::Atom::Feed;
use XML::RSS::LibXML;

sub data { Gion::Data->new(dbh => Gion::DB->new) }

sub load {
    my ($self, %attr) = @_;
    $self->$_($attr{$_}) for keys %attr;
}

# エラーレスポンスを取得したことを記録
sub catch_error {
    my ($self, %attr) = @_;
    $self->set_cache($attr{response});

    my $data = $self->data;
    $data->update_feed(
        http_status => 404,
        term => 4,
        cache => $self->cache,
        id => $self->id,
    );
    warnf('404 %4d %s', $self->id, encode_utf8($self->title));
    $self->http_status(404);
    $self->term(4);
}

# フィードのURLを更新
sub catch_redirect {
    my ($self, %attr) = @_;
    
    my $data = $self->data;
    $data->update_feed_url(url => $attr{location}, id => $self->id);

    infof('301 %s -> %s', $self->url, $attr{location});
    $self->url($attr{location});
}

# 未更新のため、クロールタイミングの調整、ヘッダレスポンスを記録
sub catch_notmodified {
    my ($self, %attr) = @_;

    # 304 応答で、ヘッダによるレスポンス返却がある場合にのみ上書きをする
    if (keys %{$attr{response}}) {
        $self->set_cache($attr{response});
    }

    my $term = update_term(from_mysql_datetime($self->pubdate)->epoch);
    my $data = $self->data;
    $data->update_feed(
        http_status => 304,
        term => $term,
        cache => $self->cache,
        id => $self->id,
    );

    $self->http_status(304);
    $self->term($term);
}

# パースエラーを記録し、次回クロール時にリトライする
sub catch_parse_error {
    my ($self, %attr) = @_;
    $self->set_cache($attr{response});

    warnf('ERR %4d %s', $self->id, encode_utf8($self->title));

    my $data = $self->data;
    $data->update_feed_parser_error(
        http_status => $attr{code},
        cache => $self->cache,
        id => $self->id,
    );

    $self->parser(0);
    $self->term(1);
    $self->http_status($attr{code});
}

# 最終更新日、ヘッダレスポンスを記録
sub update_feed_info {
    my ($self, %attr) = @_;
    $self->set_cache($attr{response});

    my $pubdate = to_mysql_datetime(
        Time::Piece->new($attr{last_modified})
    );

    if (not defined $attr{term}) {
        $attr{term} = update_term($attr{last_modified});
    }

    my $data = $self->data;
    $data->update_feed_info(
        http_status => $attr{code},
        pubdate => $pubdate,
        term => $attr{term},
        cache => $self->cache,

        id => $self->id,
    );
    $self->http_status($attr{code});
    $self->pubdate($pubdate);
    $self->term($attr{term});
}

# パーサーの設定を更新
sub update_parser {
    my ($self, %attr) = @_;
    my $data = $self->data;
    $data->update_feed_parser(parser => $attr{parser}, id => $self->id);
    $self->parser($attr{parser});
}

#
# setter/getter cache
#

sub get_cache {
    my $self = shift;
    unless ($self->cache) {
        return;
    }
    decode_json $self->cache;
}

sub set_cache {
    my ($self, $response) = @_;
    my $cache = encode_json $response;
    $self->cache($cache);
}

#
# parse a feed
#

sub parse_rss {
    my ($self, $feed_content) = @_;

    my $rss = XML::RSS::LibXML->new(
        libxml_opts => +{
            # default on XML::RSS::LibXML
            recover => 1,
            load_ext_dtd => 0,

            # parser error : internal error: Huge input lookup
            set_options => +{
                huge => 1,
            },
        },
    );
    try {
        $rss->parse($feed_content);
    } catch {
        croak('error');
    };
 
    my $ns_dc = 'http://purl.org/dc/elements/1.1/';
    my @data;

    foreach (@{$rss->{items}}) {
        my $dt;
        if (defined $_->{pubDate}) {
            $dt = from_feed_datetime($_->{pubDate});
        } elsif (defined $_->{$ns_dc}{date}) {
            $dt = from_feed_datetime($_->{$ns_dc}{date});
        } else {
            $dt = localtime;
        }

        my $url  = $_->{link};
        if (!$url or $url eq '') {
            $url = $_->{guid};    # URLがない場合は、GUIDを代用
        }

        if ($url eq '') {
            next;   # 空の場合は登録できない
        }

        if (ref($url) eq 'XML::RSS::LibXML::MagicElement') {
            $url = $url->toString;
        }

        #相対パスだと修正する
        if ( $url !~ /^https?:/ ) {
            $url = URI->new_abs($url, $self->url)->as_string;
        }

        my $entry_model = Gion::Crawler::Entry->new(
            title       => $_->{title},
            description => $_->{description},
            pubdate     => $dt,
            url         => $url,
        );
        push @data, $entry_model;
    }

    unless (@data) {
        croak('error');
    }

    @data;
}

sub parse_atom {
    my ($self, $feed_content) = @_;

    my $atom = XML::Atom::Feed->new(\$feed_content);
    my @data;
    my @entry = $atom->entries;

    foreach (@entry) {
        my $dt  = from_feed_datetime($_->updated ? $_->updated : $_->published);
        my $url = $_->link->href;

        #相対パスだと修正する
        if ( $url !~ /^https?:/ ) {
            $url = URI->new_abs($url, $self->url)->as_string;
        }

        my $entry_model = Gion::Crawler::Entry->new(
            title       => decode_utf8($_->title),
            description => decode_utf8($_->summary),
            pubdate     => $dt,
            url         => $url,
        );
        push @data, $entry_model;
    }

    unless (@data) {
        croak('error');
    }

    @data;
}

sub get_next_serial {
    my $self = shift;

    my $data = $self->data;
    my $txn = $data->dbh->txn_scope;

    $data->update_next_serial(id => $self->id);
    my $serial = $data->get_next_serial(id => $self->id);

    $txn->commit;
    return $serial;
}

#
# util
#

sub update_term {
    my $epoch = shift;

    return 1 unless $epoch;

    my $now = Time::Piece->new()->epoch;

    # 1: half hour, 2: every hour, 3: half day, 4: 2days, 5: one week
    my $term = 1; 
    my $ans = $now - $epoch;

    #更新がない場合、クロールを疎遠にしていく。
    if ( $ans > 86400 * 14 ) {
        # 14日以上に更新がない場合は、1週間に1回クロールする
        $term = 5;
    } elsif ( $ans > 86400 * 7 ) {
        # 7日以上に更新がない場合は、2日に1回クロールする
        $term = 4;
    } elsif ( $ans > 86400 * 4 ) {
        # 4日以上に更新がない場合は、半日に1回クロールする
        $term = 3;
    } elsif ( $ans > 3600 * 12 ) {
        # 12時間以上に更新がない場合は、毎時に1回クロールする
        $term = 2;
    }
    return $term;
}

# すごく汚い日付のパース
sub from_feed_datetime {
    my $t = shift;
    my $dt;

    eval {
        $dt = DateTime::Format::Mail->parse_datetime($t)
            unless defined $dt;
    };

    eval {
        $dt = DateTime::Format::W3CDTF->parse_datetime($t)
            unless defined $dt;
    };

    eval {
        $dt = DateTime::Format::ISO8601->parse_datetime($t)
            unless defined $dt;
    };

    eval {
        $dt = DateTime->from_epoch(
            epoch => HTTP::Date::str2time($t)
        )
            unless defined $dt;
    };

    eval {
        $dt = DateTime->from_epoch(
            epoch => Date::Parse::str2time($t)
        )
            unless defined $dt;
    };

    if (defined $dt) {
        return Time::Piece->new( $dt->epoch() );
    }

    Time::Piece->new();
}

1;

__END__

