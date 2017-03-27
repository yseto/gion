package Gion::Config;

use strict;
use warnings;
use utf8;

use Config::ENV 'PLACK_ENV', export => 'config';
use File::Spec::Functions ':ALL';

use constant root => rel2abs(".");

common +{
    appname => 'gion',

    # for auth.
    salt => "Gion::Util::Auth",
    strech => 500,

    # csrf-token
    token => "csrf-token",

    crawler => {
        agent => "Gion Crawler/0.1 (https://github.com/yseto/gion)",
        timeout => 10,
    },

    redirector => 'https://www.google.com/url?sa=D&q=',

    load('gion.conf'),
};

1;

