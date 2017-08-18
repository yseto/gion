package Gion::Crawler::UserAgent;

use strict;
use warnings;
use utf8;

use Class::Accessor::Lite;
Class::Accessor::Lite->mk_accessors(qw{
    code location response content
    ua
});

use Furl;
use URI;

sub new {
    my ($class, %attr) = @_;

    my $ua = Furl->new(
        headers => [
            'Accept-Encoding' => 'gzip',
            Connection => 'close'
        ],
        max_redirects => 0,
        %attr,
    );

    bless {
        ua => $ua,
    }, $class;
}

sub clear {
    my $self = shift;
    $self->$_(undef) for qw/content location response code/;
}

sub get {
    my ($self) = shift;
    $self->clear;
    $self->_get(@_);
}

sub _get {
    my ($self, $url, %opt) = @_;

    my $res = $self->ua->get($url, [%opt]);

    my %response;

    # ここで違う名称で保存する
    # キャッシュして、取得時にそのまま転用させるため
    if (defined $res->headers->{etag}) {
        $response{'If-None-Match'}      = $res->headers->{etag}[0];
    }
    if (my $lm = $res->headers->last_modified) {
        $response{'If-Modified-Since'}  = $lm;
    }

    $self->code($res->code);
    $self->response(\%response);
    $self->content($res->content);

    if ($res->code == 200) {
        return;
    }
    if ($res->code == 304) {
        return;
    }
    if ($res->code >= 400) {
        return;
    }

    # 30[1237] についてはリダイレクトが必要
    if ($res->code =~ /^30[1237]$/) {
        my $location = $res->headers->{location}[0];
        if ($location !~ /^https?:/) {
            $location = URI->new_abs($location, $url)->as_string;
        }
        # 301 は URL更新が必要
        if ($res->code eq '301') {
            $self->location($location);
        }
        return $self->_get($location, %opt);
    }
}

1;

__END__

