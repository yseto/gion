#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Plack::Builder;
use FindBin;

use lib qq($FindBin::Bin/lib/);
use Gion;
use Gion::Preload;

$ENV{LM_DEBUG} = ($ENV{PLACK_ENV} && $ENV{PLACK_ENV} eq 'development') ? 1 : 0;

builder {
    enable 'ReverseProxy';
    enable 'AccessLog';
    enable 'Static',
        path => qr{^/(robots.txt|gion.js|favicon.ico|apple-touch-icon-precomposed.png)},
        root => "$FindBin::Bin/public";

    enable 'HTTPExceptions';
    enable 'Scope::Container';

    Gion->to_app;
};

