package Gion;

use strict;
use warnings;
use utf8;

use Encode;

use Gion::Base;
use parent qw(Gion::Base);

use Gion::Api;
use Gion::ExternalAPI::Hatena;
use Gion::ExternalAPI::Pocket;
use Gion::Opml;
use Gion::Util;

route '/', { controller => 'Gion', action => 'index' };
route '/login', { controller => 'Gion', action => 'login' };
route '/logout', { controller => 'Gion', action => 'logout' };
route '/robots.txt', { controller => 'Gion', action => 'robots_txt' };

route '/entry/', { controller => 'Gion', action => 'static', page => 'entry' };
route '/add/', { controller => 'Gion', action => 'static', page => 'add' };
route '/subscription/', { controller => 'Gion', action => 'static', page => 'subscription' };
route '/settings/', { controller => 'Gion', action => 'static', page => 'settings' };

route '/api/:action', { controller => 'Gion::Api' };
route '/opml/:action', { controller => 'Gion::Opml' };
route '/external_api/hatena/:action', { controller => 'Gion::ExternalAPI::Hatena' };
route '/external_api/pocket/:action', { controller => 'Gion::ExternalAPI::Pocket' };

sub index {
    my ($class, $r) = @_;

    $r->is_login ?
        $r->html('entrance.html') :
        $r->html('welcome.html');
}

sub login {
    my ($class, $r) = @_;
    my $db = $r->dbh->dbh;

    my $auth = Gion::Util->auth(
        strech => config->param('strech'),
        salt => config->param('salt'),
        id => encode_utf8 $r->req->param('id'),
        password => encode_utf8 $r->req->param('password'),
    );

    my $c = $db->select_row('SELECT * FROM user WHERE password = ?', $auth);
    if ( defined $c ) {
        $r->session->set(username => $c->{id});
        $r->session->set(superuser => $r->req->param('id') eq 'admin' ? 1 : 0);
        $db->query('UPDATE user SET last_login = CURRENT_TIMESTAMP WHERE id = ?', $c->{id});
    }
    $r->res->redirect('/');
}

sub logout {
    my ($class, $r) = @_;
    $r->session->expire;
    $r->res->redirect('/');
}

sub robots_txt {
    my ($class, $r) = @_;
    $r->res->content_type('text/plain');
    $r->res->body(<<EOT);
User-agent: *
Disallow: /
EOT

}

sub static {
    my ($class, $r) = @_;

    my $filename = $r->req->env->{'myweb.router'}{'page'};
    $r->is_login ?
        $r->html("${filename}.html") :
        $r->res->redirect('/');
}

1;

