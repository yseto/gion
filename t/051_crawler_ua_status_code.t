use strict;
use warnings;
use utf8;

use lib "t/";
use resolver;
use testenv (); # no mysql, no memd

use Test::More;
use Test::TCP;
use Plack::Builder;
use Plack::Loader;
use Plack::Request;

use lib "lib/";
use Gion::Crawler::UserAgent;

my $app = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my (undef, $code, $ext) = split "/", $req->path_info;
    my @headers = ('Content-Type' => 'text/plain');
    if ($code =~ /^30[12]/) {
        my $url = ($ext && $ext eq "on") ?
            sprintf("http://127.0.0.1:%d/200", $req->port) :
            '/200';
        push @headers, 'Location', $url;
    }
    return [ $code, \@headers, [ '' ] ];
};

my $builder = Plack::Builder->new;

my $server = Test::TCP->new(
    code => sub {
        my $port   = shift;
        my $server = Plack::Loader->auto(
            port => $port,
            host => '127.0.0.1',
        );
        $server->run($builder->to_app($app));
    },
);

my $port = $server->port;
my $base = "http://127.0.0.1:$port";

my $resolver = resolver->new;

subtest 'get 200', sub {
    my $ua = Gion::Crawler::UserAgent->new(resolver => $resolver);
    $ua->get("$base/200");

    is $ua->code, 200;
    is $ua->content, '';
    is $ua->location, undef;
    is_deeply $ua->response, {};
};

subtest 'get 301', sub {
    my $ua = Gion::Crawler::UserAgent->new(resolver => $resolver);

    my $url = "$base/301/on";
    my $impl = Gion::Crawler::UserAgent::new_ua(resolver => $resolver);
    my $ua_impl = $impl->get($url);
    is $ua_impl->code, 301;
    is $ua_impl->headers->{location}[0], "$base/200";

    $ua->get($url);

    is $ua->code, 200;
    is $ua->location, "$base/200";
    is_deeply $ua->response, {};
};

subtest 'get 301 local', sub {
    my $ua = Gion::Crawler::UserAgent->new(resolver => $resolver);

    my $url = "$base/301";
    my $impl = Gion::Crawler::UserAgent::new_ua(resolver => $resolver);
    my $ua_impl = $impl->get($url);
    is $ua_impl->code, 301;
    is $ua_impl->headers->{location}[0], '/200';

    $ua->get($url);

    is $ua->code, 200;
    is $ua->location, "$base/200";
    is_deeply $ua->response, {};
};

subtest 'get 302', sub {
    my $ua = Gion::Crawler::UserAgent->new(resolver => $resolver);

    my $url = "$base/302/on";
    my $impl = Gion::Crawler::UserAgent::new_ua(resolver => $resolver);
    my $ua_impl = $impl->get($url);
    is $ua_impl->code, 302;
    is $ua_impl->headers->{location}[0], "$base/200";

    $ua->get($url);

    is $ua->code, 200;
    is $ua->location, undef;
    is_deeply $ua->response, {};
};


subtest 'get 302 local', sub {
    my $ua = Gion::Crawler::UserAgent->new(resolver => $resolver);

    my $url = "$base/302";
    my $impl = Gion::Crawler::UserAgent::new_ua(resolver => $resolver);
    my $ua_impl = $impl->get($url);
    is $ua_impl->code, 302;
    is $ua_impl->headers->{location}[0], "/200";

    $ua->get($url);

    is $ua->code, 200;
    is $ua->location, undef;
    is_deeply $ua->response, {};
};


subtest 'get 304', sub {
    my $ua = Gion::Crawler::UserAgent->new(resolver => $resolver);
    $ua->get("$base/304");

    is $ua->code, 304;
    is $ua->location, undef;
    is_deeply $ua->response, {};
};

subtest 'get 404', sub {
    my $ua = Gion::Crawler::UserAgent->new(resolver => $resolver);
    $ua->get("$base/404");

    is $ua->code, 404;
    is $ua->location, undef;
    is_deeply $ua->response, {};
};

subtest 'get 503', sub {
    my $ua = Gion::Crawler::UserAgent->new(resolver => $resolver);
    $ua->get("$base/503");

    is $ua->code, 503;
    is $ua->location, undef;
    is_deeply $ua->response, {};
};

done_testing();

