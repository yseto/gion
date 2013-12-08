package Gion::Web::Api::Pocket;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;
use LWP::UserAgent;
use URI;
use Mojo::JSON;
use Try::Tiny;

sub connect {
    my $self         = shift;
    my $db           = $self->app->dbh->dbh;
    my $data         = $self->req->params->to_hash;
    my $ua           = LWP::UserAgent->new;
    my $redirect_uri = $self->req->url->base . $self->req->url->path;
    my $app_id       = $self->config->{service}->{pocket};

    if ( my $code = $data->{r} ) {
        my $req =
          HTTP::Request->new(
            POST => 'https://getpocket.com/v3/oauth/authorize' );
        $req->content_type('application/x-www-form-urlencoded');
        $req->content("consumer_key=$app_id&code=$code");

        my $return = $ua->request($req);

        warn Dumper $return->content;

        my $params;
        for my $pair ( split( /&/, $return->content ) ) {
            my ( $key, $value ) = split( /=/, $pair );
            $params->{$key} = $value;
        }

        if ( defined $params->{access_token} and defined $params->{username} ) {
            $db->query("INSERT INTO connection (user,service,username,`key`)
            VALUES (?,'pocket',?,?)",
                $self->session('username'), $params->{username}, $params->{access_token});
            return $self->redirect_to( $self->req->url->base . "/settings/" );
        }
        return $self->redirect_to( $self->req->url->base . "/settings/" );
    }
    else {
        my $req =
          HTTP::Request->new(
            POST => "https://getpocket.com/v3/oauth/request" );
        $req->content_type('application/x-www-form-urlencoded');
        $req->content("consumer_key=$app_id&redirect_uri=$redirect_uri");
        my $return = $ua->request($req);

        my %params = ();
        for my $pair ( split( /&/, $return->content ) ) {
            my ( $key, $value ) = split( /=/, $pair );
            $params{$key} = $value;
        }
        my $token = $params{code};

        my $uri = URI->new("https://getpocket.com/auth/authorize");
        $uri->query_form(
            request_token => $token,
            redirect_uri  => $redirect_uri . "?r=" . $token,
        );
        $self->redirect_to($uri);
    }
}

sub post {
    my $self = shift;
    my $data = $self->req->params->to_hash;
    my $db   = $self->app->dbh->dbh;
    my $rs   = $db->select_row(
        "SELECT `key` FROM connection WHERE user = ? AND service = ?",
         $self->session('username'), $data->{service});

    return $self->render( json => "ng" ) unless $rs;

    my $hash = {
        url          => $data->{url},
        access_token => $rs->{key},
        consumer_key => $self->config->{service}->{pocket},
    };

    try {
        my $url = 'https://getpocket.com/v3/add';
        my $req = HTTP::Request->new( POST => $url );
        $req->content_type('application/json');
        $req->content( Mojo::JSON->new->encode($hash) );

        my $ua = LWP::UserAgent->new;
        $ua->request($req)->content;
        return $self->render( json => { e => "ok" } );
    }
    catch {
        return $self->render( json => { e => "ng" } );
    };
}
1;
