use strict;
use warnings;
use utf8;

use lib "t/";
use resolver;
use testenv (); # no mysql, no memd

use Plack::Builder;
use Plack::Loader;
use Plack::Middleware::ConditionalGET;
use Test::More;
use Test::TCP;

use lib "lib/";
use Gion::Crawler::UserAgent;

my $app = sub {
    my $env = shift;
    return [ 200, [
        'Content-Type' => 'text/plain',
        'Last-Modified' => 'Wed, 02 Aug 2017 00:00:00 GMT',
        'ETag' => '686897696a7c876b7e',
    ], [ 'something' ] ];
};

my $builder = Plack::Builder->new;
$builder->add_middleware('ConditionalGET');

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

subtest 'get 304/200', sub {
    my $ua = Gion::Crawler::UserAgent->new(resolver => $resolver);
    $ua->get($base);
    is $ua->content, 'something';
    is $ua->code, 200;
    is_deeply $ua->response, {
        'If-Modified-Since' => 'Wed, 02 Aug 2017 00:00:00 GMT',
        'If-None-Match' => '686897696a7c876b7e',
    };
};

subtest 'get 304/200 not full match', sub {
    my $ua = Gion::Crawler::UserAgent->new(resolver => $resolver);
    $ua->get($base,
        'If-Modified-Since' => 'Wed, 02 Aug 2017 00:00:00 GMT',
    );
    is $ua->content, 'something';
    is $ua->code, 200;
    is_deeply $ua->response, {
        'If-Modified-Since' => 'Wed, 02 Aug 2017 00:00:00 GMT',
        'If-None-Match' => '686897696a7c876b7e',
    };
};

subtest 'get 304/full match', sub {
    my $ua = Gion::Crawler::UserAgent->new(resolver => $resolver);
    $ua->get($base,
        'If-Modified-Since' => 'Wed, 02 Aug 2017 00:00:00 GMT',
        'If-None-Match' => '686897696a7c876b7e',
    );
    is $ua->content, '';
    is $ua->code, 304;
    is_deeply $ua->response, {
        'If-Modified-Since' => 'Wed, 02 Aug 2017 00:00:00 GMT',
        'If-None-Match' => '686897696a7c876b7e',
    };
};

done_testing();

