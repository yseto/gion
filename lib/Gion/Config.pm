package Gion::Config;

use strict;
use warnings;
use utf8;

use Config::ENV 'PLACK_ENV', export => 'config';
use File::Spec::Functions ':ALL';
use File::Slurp qw(slurp);

use constant root => rel2abs(".");

common +{
    crawler => {
        agent => "Gion Crawler/0.1 (https://github.com/yseto/gion)",
        timeout => 10,
    },

    batch_token => 'batch_token-batch_token-batch_token',

    jwt => +{
        cookie_name => "_jwt",
        alg => 'RSA1_5',
        enc => 'A256CBC-HS512',
        private_key => "". slurp(catfile(root, 'var','keys','private.pem')),
        public_key  => "". slurp(catfile(root, 'var','keys','public.pem')),
    },
};

config test => +{
};

config portable => +{
    db => {
        dsn => "dbi:mysql:database=gion:host=mysql",
        username => 'gion',
        password => 'gion',
    },
};

1;
