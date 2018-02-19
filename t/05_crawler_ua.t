use strict;
use warnings;
use utf8;

use Test::More;
use Test::TCP;
use Plack::Builder;
use Plack::Loader;
use Plack::Middleware::ConditionalGET;

use Gion::Crawler::UserAgent;

my $ua = Gion::Crawler::UserAgent->new;

subtest 'get 200', sub {
    $ua->get('http://httpstat.us/200');

    is $ua->code, 200;
    is $ua->content, '200 OK';
    is $ua->location, undef;
    is_deeply $ua->response, {};
};

subtest 'get 301', sub {
    $ua->get('http://httpstat.us/301');

    is $ua->code, 200;
    is $ua->location, 'https://httpstat.us';
    is_deeply $ua->response, {};
};

subtest 'get 302', sub {
    $ua->get('http://httpstat.us/302');

    is $ua->code, 200;
    is $ua->location, undef;
    is_deeply $ua->response, {};
};

subtest 'get 304', sub {
    $ua->get('http://httpstat.us/304');

    is $ua->code, 304;
    is $ua->location, undef;
    is_deeply $ua->response, {};
};

subtest 'get 404', sub {
    $ua->get('http://httpstat.us/404');

    is $ua->code, 404;
    is $ua->location, undef;
    is_deeply $ua->response, {};
};

subtest 'get 503', sub {
    $ua->get('http://httpstat.us/503');

    is $ua->code, 503;
    is $ua->location, undef;
    is_deeply $ua->response, {};
};

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

subtest 'get 304/200', sub {
    $ua->get($base);
    is $ua->content, 'something';
    is $ua->code, 200;
    is_deeply $ua->response, {
        'If-Modified-Since' => 'Wed, 02 Aug 2017 00:00:00 GMT',
        'If-None-Match' => '686897696a7c876b7e',
    };
};

subtest 'get 304/200 not full match', sub {
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

