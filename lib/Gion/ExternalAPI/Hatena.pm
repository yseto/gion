package Gion::ExternalAPI::Hatena;

use strict;
use warnings;
use utf8;

use Encode;
use JSON;
use OAuth::Lite::Consumer;
use OAuth::Lite::Token;
use Try::Tiny;

use Gion::Config;

sub _consumer {
    my $class = shift;
    my $consumer_info = config->param('service')->{hatena};

    OAuth::Lite::Consumer->new(
        consumer_key => $consumer_info->{consumer_key},
        consumer_secret => $consumer_info->{consumer_secret},
        site => q{https://www.hatena.com},
        request_token_path => q{/oauth/initiate},
        access_token_path => q{/oauth/token},
        authorize_path => q{https://www.hatena.ne.jp/oauth/authorize},
    );
}

sub connect {
    my ($class, $r) = @_;
    $r->require_login;

    my $consumer = $class->_consumer;

    # define callback url
    my $callback_url = $r->req->uri;
    $callback_url =~ s/connect$/callback/;

    # get request token
    my $request_token = $consumer->get_request_token(
        callback_url => $callback_url,
        scope => 'read_public,write_private,write_public',
    ) or die $consumer->errstr;

    # save request_token
    $r->session->set(hatena_request_token => $request_token->as_encoded);

    $r->res->redirect( $consumer->url_to_authorize(token => $request_token) );
}

sub callback {
    my ($class, $r) = @_;
    $r->require_login;

    my $db = $r->dbh;
    my $consumer = $class->_consumer;

    my $verifier = $r->req->param('oauth_verifier');
    my $request_token = OAuth::Lite::Token->from_encoded($r->session->get('hatena_request_token'));

    # get access token from provider
    my $access_token = $consumer->get_access_token(
        token => $request_token,
        verifier => $verifier,
    ) or die $consumer->errstr;

    # discard request token
    $r->session->remove(hatena_request_token => undef);

    # get hatena id
    my $res = $consumer->request(
        method => 'GET',
        url => 'http://n.hatena.com/applications/my.json',
        token => $access_token,
        params => {},
    ) or die $consumer->errstr;

    my $data = JSON::from_json($res->decoded_content);
 
    # save access_token
    $db->query(
        "INSERT INTO connection (user_id, service, username, `key`) VALUES (?,'hatena',?,?)",
        $r->session->get('username'),
        $data->{display_name},
        $access_token->as_encoded,
    );
    $r->res->redirect("/#settings"); # XXX
};

sub post {
    my ($class, $r) = @_;
    $r->require_login;

    my $db = $r->dbh;
    my $rs = $db->select_row("
        SELECT `key` FROM connection WHERE user_id = ? AND service = 'hatena'
    ", $r->session->get('username'));

    return $r->json({e => "ng"}) unless $rs;

    # get access_token from db values.
    my $access_token = OAuth::Lite::Token->from_encoded($rs->{key});
    unless ($access_token) {
        return $r->json({e => "ng"}) unless $rs;
    }
    my $consumer = $class->_consumer;

    try {
        # post bookmark
        my $res = $consumer->request(
            method => 'POST',
            url => 'http://api.b.hatena.ne.jp/1/my/bookmark',
            token => $access_token,
            params => {
                url => $r->req->param('url'),
                comment => ($r->req->param('comment') || ''),
            },
        );
        JSON::decode_json($res->decoded_content);

    } catch {
        return $r->json({ e => "ng" });
    };

    $r->json({ e => "ok" });
}

sub disconnect {
    my ($class, $r) = @_;
    $r->require_login;

    my $db = $r->dbh;
    $db->query("
        DELETE FROM connection WHERE user_id = ? AND service = 'hatena'
    ", $r->session->get('username'));

    $r->res->redirect("/#settings"); # XXX
}

1;
