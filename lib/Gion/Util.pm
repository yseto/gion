package Gion::Util;

use strict;
use warnings;
use utf8;

use Digest::SHA qw/sha1_hex/;
use Encode;
use Encode::Guess qw/sjis euc-jp 7bit-jis/;
use Furl;
use Try::Tiny;
use URI;
use XML::LibXML;

use Gion::Config;

sub auth {
    my %opt = @_;

    return undef unless defined $opt{id} and length( $opt{id} ) > 0;
    return undef
      unless defined $opt{password} and length( $opt{password} ) > 0;

    $opt{salt} = config->param('salt');
    $opt{strech} = config->param('strech');

    my $salt = $opt{id} . pack( 'H*', $opt{salt} );

    my $hash = '';
    for ( my $i = 0 ; $i < $opt{strech} ; $i++ ) {
        $hash = sha1_hex join '', $hash, $opt{password}, $salt;
    }
    $hash;
}

sub examine_url {
    my $page_url = shift;

    my $res = Furl->new->get($page_url);

    return 0 unless defined $res;

    my $xml = XML::LibXML->new;
    $xml->recover_silently(1);

    my $doc;

    try {
        $doc = $xml->parse_html_string( $res->content );
    } catch {
        return 0;
    };

    return 0 unless defined $doc;

    my $title = $doc->findvalue('//title');

    try {
        my $decoder = Encode::Guess->guess( $res->content );
        die $decoder unless ref $decoder;
        $title = $decoder->decode($title);
    } catch {
        return 0;
    };

    $title =~ s/\r|\n//g;

    # ref. http://blog.livedoor.jp/dankogai/archives/51568463.html
    my $tmp = $doc->findvalue('/html/head/link[@type="application/rss+xml"][1]/@href');
    my $resource = $tmp ? $tmp : $doc->findvalue('/html/head/link[@type="application/atom+xml"][1]/@href');

    return 0 unless $resource;
    return 1, {
        t => $title,
        u => URI->new_abs( $resource, $page_url )->as_string
    };
}

sub redirect_url {
    my $url = shift;
    $url = encode_utf8($url);
    $url =~ s/([^0-9A-Za-z!'()*\-._~])/sprintf("%%%02X", ord($1))/eg;
    return config->param('redirector') . $url;
}

1;

