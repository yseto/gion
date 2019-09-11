#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Proclet::Declare;
color;

use lib "lib/";
use Gion::Scripts::Cleanup;
use Gion::Scripts::Crawler;

service('web', 'plackup -s Starlet --max-workers 5 app.psgi');

scheduled('cleanup',   '8 16 * * *',    sub { Gion::Scripts::Cleanup->main_proclet; });

scheduled('crawler.1', '15,45 * * * *', sub { Gion::Scripts::Crawler->main_proclet(1)->crawl });
scheduled('crawler.2', '55 * * * *',    sub { Gion::Scripts::Crawler->main_proclet(2)->crawl });
scheduled('crawler.3', '20 5,17 * * *', sub { Gion::Scripts::Crawler->main_proclet(3)->crawl });
scheduled('crawler.4', '30 19 */2 * *', sub { Gion::Scripts::Crawler->main_proclet(4)->crawl });
scheduled('crawler.5', '30 20 * * 1',   sub { Gion::Scripts::Crawler->main_proclet(5)->crawl });

run;
