package Gion::Web::Api::Hatena;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;
use OAuth::Lite::Consumer;
use OAuth::Lite::Token;
use JSON;
use Encode;
use Try::Tiny;

sub _consumer {
    my $self = shift;
    my $consumer_info = $self->config->{service}->{hatena};

    OAuth::Lite::Consumer->new(
        consumer_key       => $consumer_info->{consumer_key},
        consumer_secret    => $consumer_info->{consumer_secret},
        site               => q{https://www.hatena.com},
        request_token_path => q{/oauth/initiate},
        access_token_path  => q{/oauth/token},
        authorize_path     => q{https://www.hatena.ne.jp/oauth/authorize},
    );
}

sub connect {
    my $self = shift;
    my $consumer = $self->_consumer;

    # define callback url
    my $callback_url = $self->req->url->to_abs->to_string;
    $callback_url =~ s/connect$/callback/;

    # get request token
    my $request_token = $consumer->get_request_token(
        callback_url => $callback_url,
        scope        => 'read_public,write_private,write_public',
    ) or die $consumer->errstr;

    # save request_token
    $self->session(hatena_request_token => $request_token->as_encoded);

    $self->redirect_to( $consumer->url_to_authorize(token => $request_token) );
}

sub callback {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;
    my $consumer = $self->_consumer;

    my $verifier = $self->param('oauth_verifier');
    my $request_token = OAuth::Lite::Token->from_encoded($self->session('hatena_request_token'));

    # get access token from provider
    my $access_token = $consumer->get_access_token(
        token    => $request_token,
        verifier => $verifier,
    ) or die $consumer->errstr;

    # discard request token
    $self->session(hatena_request_token => undef);

    # get hatena id
    my $res = $consumer->request(
        method => 'GET',
        url    => 'http://n.hatena.com/applications/my.json',
        token  => $access_token,
        params => {},
    ) or die $consumer->errstr;

    my $data = JSON::decode_json($res->decoded_content);
 
    # save access_token
    $db->query(
        "INSERT INTO connection (user,service,username,`key`) VALUES (?,'hatena',?,?)",
        $self->session('username'), $data->{display_name},
        $access_token->as_encoded
    );
    $self->redirect_to( $self->req->url->base . "/settings/" );
};

sub post {
    my $self = shift;
    my $data = $self->req->params->to_hash;
    my $db   = $self->app->dbh->dbh;
    my $rs   = $db->select_row(
        "SELECT `key` FROM connection WHERE user = ? AND service = 'hatena'",
        $self->session('username') );

    return $self->render( json => "ng" ) unless $rs;

    # get access_token from db values.
    my $access_token = OAuth::Lite::Token->from_encoded($rs->{key});
    unless ($access_token) {
        return $self->render( json => "ng" ) unless $rs;
    }
    my $consumer = $self->_consumer;

    try {
        # post bookmark
        my $res = $consumer->request(
            method => 'POST',
            url    => 'http://api.b.hatena.ne.jp/1/my/bookmark',
            token  => $access_token,
            params => {
                url => $data->{url},
                comment => (encode_utf8($data->{comment}) || ''),
            },
        );
        JSON::decode_json($res->decoded_content);

        return $self->render( json => { e => "ok" } );
    }
    catch {
        return $self->render( json => { e => "ng" } );
    };
}

sub disconnect {
    my $self = shift;
    my $db   = $self->app->dbh->dbh;
    my $data = $self->req->params->to_hash;
    $db->query( "DELETE FROM connection WHERE user = ? AND service = 'hatena'",
        $self->session('username') );

    $self->redirect_to( $self->req->url->base . "/settings/" );
}

1;
