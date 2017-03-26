package Gion::ExternalAPI::Pocket;

use strict;
use warnings;
use utf8;

use Furl;
use HTTP::Request;
use JSON;
use Try::Tiny;
use URI;

use Gion::Config;

sub connect {
    my ($class, $r) = @_;
    $r->require_login;

    my $ua = Furl->new;
    my $app_id = config->param('service')->{pocket};

    if (my $code = $r->req->param('r')) {
        my $req = HTTP::Request->new(POST => 'https://getpocket.com/v3/oauth/authorize');
        $req->content_type('application/x-www-form-urlencoded');
        $req->content("consumer_key=$app_id&code=$code");
        my $res = $ua->request($req);

        my %params;
        for my $pair ( split( /&/, $res->content ) ) {
            my ( $key, $value ) = split( /=/, $pair );
            $params{$key} = $value;
        }

        if ( defined $params{access_token} and defined $params{username} ) {
            my $db = $r->dbh->dbh;
            $db->query("
                INSERT INTO connection (user_id, service, username, `key`) VALUES (?,'pocket',?,?)
            ",
                $r->session->get('username'),
                $params{username},
                $params{access_token},
            );
        }
        return $r->res->redirect("/#settings"); # XXX
    } else {
        my $req = HTTP::Request->new(POST => "https://getpocket.com/v3/oauth/request");
        $req->content_type('application/x-www-form-urlencoded');
        my $redirect_uri = $r->req->uri;
        $req->content("consumer_key=$app_id&redirect_uri=$redirect_uri");
        my $res = $ua->request($req);

        my %params = ();
        for my $pair ( split( /&/, $res->content ) ) {
            my ( $key, $value ) = split( /=/, $pair );
            $params{$key} = $value;
        }
        my $uri = URI->new("https://getpocket.com/auth/authorize");
        $uri->query_form(
            request_token => $params{code},
            redirect_uri => $redirect_uri . "?r=" . $params{code},
        );
        $r->res->redirect($uri->as_string);
    }
}

sub post {
    my ($class, $r) = @_;
    $r->require_login;

    my $db = $r->dbh->dbh;
    my $rs = $db->select_row("
        SELECT `key` FROM connection WHERE user_id = ? AND service = 'pocket'
    ", $r->session->get('username'));
    return $r->json({ e => "ng"}) unless $rs;

    my %hash = (
        url => $r->req->param('url'),
        access_token => $rs->{key},
        consumer_key => config->param('service')->{pocket},
    );

    try {
        my $url = 'https://getpocket.com/v3/add';
        my $req = HTTP::Request->new(POST => $url);
        $req->content_type('application/json');
        $req->content( JSON::encode_json(\%hash) );

        my $ua = Furl->new;
        $ua->request($req)->content;
    }
    catch {
        return $r->json({ e => "ng" });
    };
    $r->json({ e => "ok" });
}

sub disconnect {
    my ($class, $r) = @_;
    $r->require_login;

    my $db = $r->dbh->dbh;
    $db->query("
        DELETE FROM connection WHERE user_id = ? AND service = 'pocket'
    ", $r->session->get('username'));
    $r->res->redirect("/#settings"); # XXX
}

1;
