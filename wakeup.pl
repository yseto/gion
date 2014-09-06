#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use HTTP::Tiny;

my $url;
Getopt::Long::Configure ("no_ignore_case");
GetOptions(
    "u|url=s" => \$url,
);

my $ua = HTTP::Tiny->new;
$ua->get($url);

