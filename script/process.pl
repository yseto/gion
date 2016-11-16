#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Proclet;
my $proclet = Proclet->new(color => 1);

$proclet->service(
    code => 'plackup -s Starlet --max-workers 5 app.psgi',
    tag => 'web',
);

my @terms = (
    '15,45 * * * *',
    '55 * * * *',
    '20 5,17 * * *',
    '30 19 */2 * *',
    '30 20 * * 1'
);

for (my $i = 0; $i < @terms; $i++) {
    my $term = $i + 1;
    $proclet->service(
        every => $terms[$i],
        tag => "crawler.$i",
        code => "script/crawler.pl --term $term",
    );
}

$proclet->service(
    every => '35 4 * * *',
    tag => 'cleanup',
    code => 'script/cleanup.pl',
);

$proclet->run;
__END__

