#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use lib "lib/";
use Gion::Scripts::Crawler;
Gion::Scripts::Crawler->main_script(@ARGV)->crawl;

=encoding utf8

=head1 NAME

crawler - item crawler.

=cut
