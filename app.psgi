#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Cache::Memcached::Fast::Safe;
use FindBin;
use Plack::Builder;
use Plack::Middleware::Session;
use Plack::Session::State::Cookie;
use Plack::Session::Store::Cache;

use lib qq($FindBin::Bin/lib/);
use Gion;

builder {
    enable 'Static',
        path => qr{^/(static/|favicon.ico|apple-touch-icon-precomposed.png)},
        root => "$FindBin::Bin/public";

    enable 'HTTPExceptions';

    enable 'Session',
        state => Plack::Session::State::Cookie->new(
            secure => ($ENV{SECURE_COOKIE} || 0),
            expires => ($ENV{EXPIRE_COOKIE} || 0),
            httponly => 1,
            session_key => 'gion',
        ),
        store => Plack::Session::Store::Cache->new(
            cache => Cache::Memcached::Fast::Safe->new(+{
                servers => ["memcached:11211"],
                namespace => 'gion',
            }),
        );

    sub {
        Gion->new(shift)->run->res->finalize;
    }
};

