package Gion::Crawler::UserAgent;

use strict;
use warnings;
use utf8;

use Class::Accessor::Lite;
Class::Accessor::Lite->mk_accessors(qw{
    code location response content
    ua redirect_counter
});

use Furl;
use HTTP::Status qw(:constants :is);
use Net::DNS::Paranoid;
use URI;

sub new {
    my ($class, %attr) = @_;

    my $self = bless {
        attr => \%attr,
        ua => new_ua(%attr),
    }, $class;
    $self->$_(undef) for qw/content location response code redirect_counter/;
    $self;
}

sub new_ua {
    my (%attr) = @_;

    my $resolver = $attr{resolver} || Net::DNS::Paranoid->new;
    Furl->new(
        headers => [
            'Accept-Encoding' => 'gzip',
            Connection => 'close'
        ],
        inet_aton => sub {
            my ($host, $errmsg) = $resolver->resolve($_[0], time(), $_[1]);
            die $errmsg unless $host;
            Socket::inet_aton($host->[0]);
        },
        max_redirects => 0,
        %attr,
    );
}

sub add_redirect_counter {
    my $self = shift;
    if ($self->redirect_counter) {
        $self->redirect_counter($self->redirect_counter + 1);
    } else {
        $self->redirect_counter(1);
    }
}

sub get {
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
            # リダイレクト先が取得できるか評価する
            my $redirect_check = new_ua(%{$self->{attr}});
            eval {
                my $redirect = $redirect_check->get($location);
                if (is_success($redirect->code)) {
                    $self->location($location);
                }
            };
            # リダイレクト先のパスがおかしい場合に拾う
            if ($@) {
                $self->code(400);
                $self->response({});
                return;
            }
        }

        # リダイレクトループを検出する
        # ドメイン パーキング などの厳しい世界でループが多発する
        if ($location eq $url) {
            $self->add_redirect_counter;
            if ($self->redirect_counter > 5) {
                $self->code(400);
                return;
            }
        }
        return $self->get($location, %opt);
    }
}

1;

__END__

