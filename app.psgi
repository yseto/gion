#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use FindBin;
use Plack::Builder;
use Plack::Middleware::Session;
use Plack::Session::State::Cookie;
use Plack::Session::Store::File;

use lib qq($FindBin::Bin/lib/);
use Gion;

builder {
    enable 'Static',
        path => qr{^/(static/|favicon.ico|apple-touch-icon-precomposed.png)},
        root => "$FindBin::Bin/public";

    enable 'Session',
        state => Plack::Session::State::Cookie->new(
            #secure => 1,
            httponly => 1,
            session_key => 'gion',
        ),
        store => Plack::Session::Store::File->new(
            dir => "$FindBin::Bin/var/session",
        );

    sub {
        Gion->new(shift)->run->res->finalize;
    }
};

