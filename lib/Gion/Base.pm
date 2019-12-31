package Gion::Base;

use strict;
use warnings;
use utf8;
use Exporter 'import';
our @EXPORT = qw(route config);

# some ref. https://github.com/cho45/starter.pl/tree/master/templates/mywebapp

use Plack::Request;
use Plack::Response;
use Plack::Session;

use DBIx::Handler::Sunny;
use Digest::HMAC_SHA1 qw(hmac_sha1_hex);
use Module::Load;
use Router::Simple;
use Text::Xslate;
use Try::Tiny;

use Gion::Config;
use Gion::Exception;
use Gion::View;

our $router = Router::Simple->new;

sub new {
    my $class = shift;
    my $env = shift;

    bless {
        req => Plack::Request->new($env),
        res => Plack::Response->new(200),
    }, $class;
}

sub req { shift->{req} }
sub res { shift->{res} }

sub route ($$) {
    $router->connect($_[0], $_[1]);
}

sub throw (%) {
    Gion::Exception->throw(@_);
}

sub before_dispatch {
    my ($r) = @_;
    if ($r->req->method eq 'POST') {
        my $attr = $r->is_xhr ? 'header' : 'param';
        my $param = $r->is_xhr ? 'X-CSRF-Token' : '_token';

        if (my $token = $r->req->$attr($param)) {
            if ($r->csrf_token ne $token) {
                throw code => 500, body => 'Invalid session';
            }
        } else {
            throw code => 403, body => 'Require session';
        }
    }
    $r->res->header('X-XSS-Protection' => '1');
    $r->res->header('X-Content-Type-Options' => 'nosniff');
    $r->res->header('X-Frame-Options' => 'deny');
    $r->res->header('Cache-Control' => 'no-cache');
}

sub after_dispatch {
    my ($r) = @_;
    return if ($r->res->header('content-type') || '') !~ m|^text/x?html|;

    # insert csrf-token
    my $content = $r->res->body;
    my $csrf_token = '<meta name="csrf-token" content="'. $r->csrf_token .'">';
    $content =~ s|(</head>)|$csrf_token$1|;
    $r->res->body($content);
}

sub run {
    my ($r) = @_;

    $r->before_dispatch;
    try {
        if (my $p = $router->match($r->req->env)) {
            my $action = delete $p->{action};
            my $controller = delete $p->{controller};
            $r->req->env->{'myweb.router'} = $p;

            load $controller;
            if ($controller->can($action)) {
                $controller->$action($r);
            } else {
                $r->res->code(404);
            }
        } else {
            $r->res->code(404);
        }
    } catch {
        my ($e) = @_;
        if (ref $e eq 'Gion::Exception') {
            $r->res->code($e->code);
            $r->res->body($e->body);
        } else {
            warn $e;
            $r->res->code(503);
            $r->res->body("Internal Server Error");
        }
    };

    $r->after_dispatch;
    $r;
}

sub dbh {
    $_[0]->{dbh} //= do {
        my $conf = config->param('db');
        DBIx::Handler::Sunny->new($conf->{dsn}, $conf->{username}, $conf->{password}, {
            mysql_enable_utf8mb4 => 1,
        });
    };
}

sub cli_dbh { $_[0]->new({})->dbh }

sub session {
    $_[0]->{session} //= do {
        $_[0]->{req}->env->{'psgix.session'} ? Plack::Session->new($_[0]->{req}->env) : ''
    };
}

sub csrf_token {
    my ($r) = @_;
    hmac_sha1_hex($r->session->id, config->param('token'));
}

sub is_xhr {
    my ($r) = @_;
    return 1
        if lc ($r->req->header('X-Requested-With') || '') eq 'xmlhttprequest';
}

sub is_login {
    my ($r) = @_;
    $r->session->get('username') ? 1 : 0;
}

sub is_admin {
    my ($r) = @_;
    $r->session->get('superuser') ?
        $r->session->get('superuser') : 0;
}

sub require_xhr {
    my ($r) = @_;
    $r->is_xhr ?
        undef :
        throw code => 403, body => 'need xhr.';
}

sub require_login {
    my ($r) = @_;
    $r->is_login ?
        undef :
        throw code => 401, body => 'need login.';
}

sub require_admin {
    my ($r) = @_;
    $r->is_admin ?
        undef :
        throw code => 401, body => 'need privilege.';
}

sub require_batch {
    my ($r) = @_;
    my $batch_token = config->param('batch_token');
    return 1
        if ($r->req->header('Authorization') || '') eq "Bearer $batch_token";
    throw code => 401, body => 'token_required or invalid_token';
}

1;

