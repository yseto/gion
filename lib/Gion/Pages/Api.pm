package Gion::Pages::Api;

use strict;
use warnings;
use utf8;

use parent qw/Gion::Pages::Base/;

use Encode;
use Encode::Guess qw/sjis euc-jp 7bit-jis/;
use FormValidator::Lite;
use FormValidator::Lite::Constraint::URL;
use Furl;
use HTML::Scrubber;
use JSON;
use JSON::Types;
use JSON::XS;
use Log::Minimal;
use Net::DNS::Paranoid;
use Text::Xslate;
use Time::Piece;
use Try::Tiny;
use URI;
use XML::LibXML;

use Gion::Authorizer::Api;
use Gion::Config;
use Gion::Crawler::Feed;
use Gion::Crawler::UserAgent;
use Gion::Model::User;

sub create_authorizer { Gion::Authorizer::Api->new(shift) }

sub user_id { shift->pad->param('user_id') }

sub user {
    my $self = shift;

    my $data = $self->data;
    my $user_row = $data->user(id => $self->user_id);
    Gion::Model::User->new($user_row);
}

sub dispatch_register_category {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check( name => ['NOT_NULL'], );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/name/;

    my $data = $self->data;
    if ($data->category_by_name(user_id => $self->user_id, name => $values{name})) {
        return $self->json({ result => "ERROR_ALREADY_REGISTER" });
    }

    $data->insert_category(user_id => $self->user_id, name => $values{name});
    $self->json({ result => "OK" });
}

sub dispatch_register_subscription {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check(
        rss => [ 'HTTP_URL', 'NOT_NULL' ],
        url => [ 'HTTP_URL', 'NOT_NULL' ],
        title => ['NOT_NULL'],
        category => [ 'UINT', 'NOT_NULL' ],
    );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/rss url title category/;

    my $data = $self->data;
    my $txn = $data->dbh->txn_scope;
    my $feed = $data->feed_by_urlset(url => $values{rss}, siteurl => $values{url});
    unless ( defined $feed ) {
        $data->insert_feed(url => $values{rss}, siteurl => $values{url}, title => $values{title});
        $feed = $data->feed_by_urlset(url => $values{rss}, siteurl => $values{url});
    }

    if ($data->subscription_by_feed_id(user_id => $self->user_id, feed_id => $feed->{id})) {
        $txn->rollback;
        return $self->json({ result => "ERROR_ALREADY_REGISTER" });
    }

    if ($data->category_by_id(user_id => $self->user_id, id => $values{category})) {
        $data->insert_subscription(
            category_id => $values{category},
            feed_id => $feed->{id},
            user_id => $self->user_id,
        );
    } else {
        # XXX invalid content
        $txn->rollback;
        return $self->json({ result => "ERROR_ALREADY_REGISTER" });
    }

    $txn->commit;
    $self->json({ result => "OK" });
}

sub dispatch_examine_subscription {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    $validator->check(
        url => [ 'HTTP_URL', 'NOT_NULL' ],
    );

    my ($success, $resource);
    if ($validator->is_valid) {
        try {
            ($success, $resource) = $self->examine_url;
        } catch {
            $success = 0;
        };
    }

    if (!$success) {
        $self->json({ title => '', url => '', preview_feed => undef });
        return;
    }

    my %payload = (%$resource, preview_feed => undef);

    if (my $result = $resource->{url} && preview_feed($resource->{url})) {
        $payload{preview_feed} = $result;
    } else {
        $payload{url} = undef;
    }

    $self->json(\%payload);
}

sub examine_url {
    my $self = shift;
    my $page_url = $self->req->param('url');

    my $resolver = Net::DNS::Paranoid->new;

    my $ua = Furl->new(
        inet_aton => sub {
            my ($host, $errmsg) = $resolver->resolve($_[0], time(), $_[1]);
            die $errmsg unless $host;
            Socket::inet_aton($host->[0]);
        },
    );

    my $res = $ua->get($page_url);

    return 0 unless defined $res;

    my $xml = XML::LibXML->new;
    $xml->recover_silently(1);

    my $doc;

    try {
        $doc = $xml->parse_html_string( $res->content );
    } catch {
        return 0;
    };

    return 0 unless defined $doc;

    my $title = $doc->findvalue('//title');

    try {
        my $decoder = Encode::Guess->guess( $res->content );
        die $decoder unless ref $decoder;
        $title = $decoder->decode($title);
    } catch {
        return 0;
    };

    $title =~ s/\r|\n//g;

    # ref. http://blog.livedoor.jp/dankogai/archives/51568463.html
    my $tmp = $doc->findvalue('/html/head/link[@type="application/rss+xml"][1]/@href');
    my $feed_url = $tmp ? $tmp : $doc->findvalue('/html/head/link[@type="application/atom+xml"][1]/@href');

    return 1, {
        title => $title,
        url   => $feed_url ? URI->new_abs( $feed_url, $page_url )->as_string : undef,
    };
}

sub dispatch_delete_it {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check(
        subscription => [ 'NOT_NULL', [ CHOICE => qw/category entry/ ] ],
        id => [ 'UINT', 'NOT_NULL' ],
    );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/id subscription/;

    my $data = $self->data;
    if ($values{subscription} eq "category") {
        $data->delete_category(id => $values{id}, user_id => $self->user_id);
    } else {
        $data->delete_subscription(feed_id => $values{id}, user_id => $self->user_id);
    }
    $self->json({ r => "OK" });
}

sub dispatch_change_it {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check(
        category => [ 'UINT', 'NOT_NULL' ],
        id => [ 'UINT', 'NOT_NULL' ],
    );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/id category/;

    my $data = $self->data;
    $data->update_subscription(
        category_id => $values{category},
        feed_id => $values{id},
        user_id => $self->user_id
    );

    $self->json({ r => "OK" });
}

sub dispatch_get_numentry {
    my $self = shift;

    my $data = $self->data;
    my $rs = $data->user_profile(id => $self->user_id);

    $self->json({
        numentry => number $rs->{numentry},
        nopinlist => bool $rs->{nopinlist},
        numsubstr => number $rs->{numsubstr},
    });
}

sub dispatch_set_numentry {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check(
        numentry => [ 'UINT', 'NOT_NULL' ],
        nopinlist => [ 'UINT', 'NOT_NULL' ],
        numsubstr => [ 'UINT', 'NOT_NULL' ],
    );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) }
        qw/numentry nopinlist numsubstr/;

    my $data = $self->data;
    $data->update_user_profile(
        numentry => $values{numentry},
        nopinlist => $values{nopinlist},
        numsubstr => $values{numsubstr},
        id => $self->user_id,
    );

    $self->json({ r => "OK" });
}

sub dispatch_get_categories {
    my $self = shift;

    my $data = $self->data;
    my @categories = map {
        {
            id => number $_->{id},
            name => string $_->{name},
        }
    }
    sort { $a->{name} cmp $b->{name} }
    @{$data->category(user_id => $self->user_id)};

    $self->json(\@categories);
}

# category_and_unread_entry_count ignore non available entry category
sub dispatch_get_category {
    my $self = shift;

    my $data = $self->data;
    my @categories = map {
        {
            count   => number $_->{count},
            id      => number $_->{id},
            name    => string $_->{name},
        }
    } @{$data->category_and_unread_entry_count(user_id => $self->user_id)};

    $self->json(\@categories);
}

sub dispatch_get_entry {
    my $self = shift;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check(
        category => [ 'NOT_NULL', 'UINT' ],
    );
    return $self->bad_request if $validator->has_error;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/category/;

    my $scrubber = HTML::Scrubber->new;
    my @info;
    my $count = 0;

    my $data = $self->data;
    my $rs = $data->unread_entry_by_category(
        category_id => $values{category},
        user_id => $self->user_id
    );

    my $user = $self->user;

    my %site_title;
    for (@$rs) {
        unless ($site_title{$_->{subscription_id}}) {
            my $title = $data->feed_title_by_subscription_id(id => $_->{subscription_id});
            $site_title{$_->{subscription_id}} = $title || "";
        }

        my $pubdate = Time::Piece->strptime($_->{pubdate}, '%Y-%m-%d %H:%M:%S')->epoch;
        my $description = $scrubber->scrub($_->{description});
        $description =~ s/\s+/ /mg;
        $description = substr($description, 0, $user->numsubstr) if $user->numsubstr > 0;

        my %row = (
            serial      => number $_->{serial},
            feed_id     => number $_->{feed_id},
            title       => $_->{title},
            description => $description,
            date_epoch  => $pubdate,
            site_title  => $site_title{$_->{subscription_id}},
            readflag    => number $_->{readflag},
            url         => $_->{url},
        );
        push @info, \%row;

        if ( $user->numentry > 0 ) {
            $count++;
            last if $user->numentry == $count;
        }
    }

    $self->json(\@info);
}

sub dispatch_set_asread {
    my $self = shift;

    my $data = $self->data;
    my $payload = JSON->new->decode($self->req->content);
    for (@$payload) {
        debugf(
            "ASREAD U:%s\t feed_id:%s\t serial:%s",
            $self->user_id,
            $_->{feed_id},
            $_->{serial},
        );

        # 既読更新
        $data->update_entry_seen(
            user_id => $self->user_id,
            feed_id => $_->{feed_id},
            serial => $_->{serial},
        );

    }
    $self->json({ result => JSON::true() });
}

sub dispatch_get_subscription {
    my $self = shift;

    my $data = $self->data;

    my @subscription = map {
        {
            siteurl => $_->{siteurl},
            id      => number $_->{id},
            title   => $_->{title},
            category_id => number $_->{category_id},
            http_status => number $_->{http_status},
        }
    } @{$data->subscription_for_user(user_id => $self->user_id)};

    my @category_and_subscription = map {
        {
            id => number $_->{id},
            name => string $_->{name},
            subscription => [do {
                my $category_id = $_->{id};

                sort { $a->{title} cmp $b->{title} }
                grep { $category_id == $_->{category_id} } @subscription;
            }],
        }
    } @{$data->category(user_id => $self->user_id)};

    $self->json(\@category_and_subscription);
}

sub dispatch_get_pinlist {
    my $self = shift;

    my $data = $self->data;
    my $list = $data->pin_list(user_id => $self->user_id);
    $self->json($list);
}

sub dispatch_set_pin {
    my $self = shift;

    my $validator = FormValidator::Lite->new($self->req);
    my $res = $validator->check(
        readflag => [ 'NOT_NULL', 'UINT' ],
        serial => ['NOT_NULL'],
        feed_id => ['NOT_NULL'],
    );
    return $self->bad_request if $validator->has_error;

    my $readflag = $self->req->param('readflag') == 2 ? 1 : 2;

    debugf(
        "PIN U:%s\tfeed_id:%s\tserial:%s",
        $self->user_id,
        $self->req->param('feed_id'),
        $self->req->param('serial'),
    );

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/feed_id serial/;

    my $data = $self->data;
    my $txn = $data->dbh->txn_scope;
    $data->update_entry(
        readflag => $readflag,
        user_id => $self->user_id,
        serial => $values{serial},
        feed_id => $values{feed_id},
    );
    $txn->commit;
    $self->json({
        readflag => number $readflag,
    });
}

sub dispatch_remove_all_pin {
    my $self = shift;

    my $data = $self->data;
    $data->remove_all_pin(user_id => $self->user_id);

    $self->json({ result => JSON::true() });
}

sub dispatch_update_password {
    my $self = shift;

    my $validator = FormValidator::Lite->new( $self->req );
    my $res = $validator->check(
        password_old => [ 'NOT_NULL', [qw/LENGTH 8 255/] ],
        { password => [qw/password passwordc/] } => ['DUPLICATION'],
        password => [ 'NOT_NULL', [qw/LENGTH 8 255/] ],
    );
    return $self->json({ result => 'error' }) if $validator->has_error;

    my $user = $self->user;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/password password_old/;

    my $check_result = $user->check_password_digest($values{password_old});

    return $self->json({ result => 'unmatch now password' })
      if !$check_result;

    debugf("Update Password: %s", $self->user_id);

    my $data = $self->data;
    my $digest = $user->generate_secret_digest($values{password});
    $data->update_user_digest(id => $self->user_id, digest => $digest);
    $self->json({ result => 'update password' });
}

# opml

sub dispatch_opml_export {
    my $self = shift;

    my $data = $self->data;
    my $category = $data->category(user_id => $self->user_id);

    my @records;
    for (@$category) {
        my @items = map {
            $data->feed_by_id(id => $_->{feed_id})
        } @{$data->subscription_feed_id_by_category(
            category_id => $_->{id},
            user_id => $self->user_id
        )};
        push @records, {
            name => $_->{name},
            items => \@items,
        };
    }

    my $xslate = Text::Xslate->new(
        syntax => 'TTerse',
        path => [ File::Spec->catdir(config->root,'templates') ],
    );

    my $xml = $xslate->render("opml.xml", { records => \@records });
    $self->json({ xml => $xml });
}

sub dispatch_opml_import {
    my $self = shift;

    my %values = map { $_ => decode_utf8(scalar($self->req->param($_))) } qw/xml/;

    my $xml = XML::LibXML->new;
    my $dom = $xml->load_xml(string => $values{xml});

    my $data = $self->data;
    my $txn = $data->dbh->txn_scope;
    my $category = "Default Category";
    for my $e ( $dom->findnodes('//outline') ) {
        if ( ($e->getAttribute('type') or '') ne 'rss' ) {
            $category = $e->getAttribute('text') ?
                $e->getAttribute('text') :
                "Default Category";
            next;
        }

        unless  (defined $e->getAttribute('htmlUrl')
            and defined $e->getAttribute('xmlUrl')
            and defined $e->getAttribute('title') )
        {
            warnf "required parameter missing";
            next;
        }

        my $xmlUrl = $e->getAttribute('xmlUrl');
        my $htmlUrl = $e->getAttribute('htmlUrl');

        # guess category id
        my $crs = $data->category_by_name(user_id => $self->user_id, name => $category);

        my $cid;
        unless (defined $crs) {
            $data->insert_category(user_id => $self->user_id, name => $category);
            $crs = $data->category_by_name(user_id => $self->user_id, name => $category);
            $cid = $crs->{id};
        }
        $cid = $crs->{id};

        # guess feed id
        my $feedrs = $data->feed_by_urlset(url => $xmlUrl, siteurl => $htmlUrl);

        unless (defined $feedrs) {
            $data->insert_feed(
                url => $xmlUrl,
                siteurl => $htmlUrl,
                title => $e->getAttribute('title'),
            );
            $feedrs = $data->feed_by_urlset(url => $xmlUrl, siteurl => $htmlUrl);
        }
        my $feedid = $feedrs->{id};

        # already register ?
        # skip already registered.
        if ( $data->subscription_by_feed_id(user_id => $self->user_id, feed_id => $feedid) ) {
            debugf(
                "already registered : %s",
                encode_utf8($e->getAttribute('title')),
            );
            next;
        }

        # register.
        $data->insert_subscription(
            category_id => $cid,
            feed_id => $feedid,
            user_id => $self->user_id,
        );
    }
    $txn->commit;
    $self->json({ done => JSON::true });
}

sub preview_feed {
    my ($url, $limit) = @_;

    $limit = 3 unless $limit;

    my $ua_config = config->param('crawler');
    my $ua = Gion::Crawler::UserAgent->new(%$ua_config);

    $ua->get($url);

    if ($ua->code eq '404' or $ua->code =~ /5\d\d/) {
        return;
    }

    my $feed_model = Gion::Crawler::Feed->new;

    my @data;
    try {
        @data = $feed_model->parse($ua->content);
    } catch {
        warnf $_;
    };

    my @result;
    my $scrubber = HTML::Scrubber->new;

    for my $entry (sort { $b->pubdate_epoch <=> $a->pubdate_epoch } @data) {
        my $description = $scrubber->scrub($entry->description);
        my %entry = (
            title       => $entry->title,
            url         => $entry->url,
            date        => $entry->pubdate->strftime('%m/%d %H:%M'),
        );
        push @result, \%entry;
        last if scalar(@result) == $limit;
    }
    return \@result;
}

1;

