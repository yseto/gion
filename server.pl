#!/usr/bin/env perl

#
#   refer:
#   http://blog.nomadscafe.jp/2014/07/heroku-proclet.html
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use Proclet;
use Plack::Loader;
use Getopt::Long;
use HTTP::Tiny;
use Mojo::Server::PSGI;
use Plack::Builder;
use Gion::Web;
use Gion::Batch::Crawler;
use Gion::Batch::Cleanup;

my $port = 5000;
Getopt::Long::Configure ("no_ignore_case");
GetOptions(
    "p|port=s" => \$port,
);

chdir($FindBin::Bin);
my $proclet = Proclet->new(
    color => 1
);

my $psgi = Mojo::Server::PSGI->new( app => Gion::Web->new );
my $app = $psgi->to_psgi_app;
$proclet->service(
    code => sub {
        my $loader = Plack::Loader->load(
            'Starlet',
            port => $port,
            host => 0,
            max_workers => 5,
        );
        $loader->run($app);
    },
    tag => 'web',
);

if( $ENV{DYNO} ) {
$proclet->service(
    every => '*/30 * * * *',
    tag => 'ping',
    code => sub {
        my $ua = HTTP::Tiny->new;
        $ua->get("http://xxxxxxxxxx.herokuapp.com/");
    }
);
}

$proclet->service(
    every => '21,41 * * * *',
    tag => 'worker_crawl',
    code => sub {
        my $class = Gion::Batch::Crawler->new;
        $class->run();
    }
);

$proclet->service(
    every => '1 * * * *',
    tag => 'worker_crawl_fail',
    code => sub {
        my $class = Gion::Batch::Crawler->new;
        $class->run("--fail");
    }
);

$proclet->service(
    every => '51 4 * * *',
    tag => 'worker_cleanup',
    code => sub {
        my $class = Gion::Batch::Cleanup->new;
        $class->run();
    }
);

$proclet->run;

