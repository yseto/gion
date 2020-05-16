#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Plack::Builder;
use FindBin;

use lib qq($FindBin::Bin/lib/);
use Gion;
use Gion::Preload;

builder {
    enable 'ReverseProxy';
    enable 'AccessLog';
    enable 'Static',
        path => qr{^/(robots.txt|gion.js|favicon.ico|apple-touch-icon-precomposed.png)},
        root => "$FindBin::Bin/public";

    enable 'HTTPExceptions';

    Gion->to_app;
};

