package Pulltoy;

use strict;
use warnings;
use utf8;

# stolen from Sledge::Pages::Base, and more.

use Class::Accessor::Lite (
    rw => [
        'req',              # Plack::Request
        'res',              # Plack::Response
        'authorizer',       # Authorizer
        'finished',         # flag whether request is finished
        'page',             # page name (arg to dispatch())
        'pad',              # scratch pad
    ],
);

use HTTP::Status;
use Plack::Response;
use Plack::Request;
use Try::Tiny;
use URI;

use Pulltoy::Pad;

# abstract methods
sub create_authorizer { die "AbstractMethod"; }

use Class::Trigger qw(BEFORE_INIT AFTER_INIT BEFORE_DISPATCH AFTER_DISPATCH);

*register_hook = \&add_trigger;
*invoke_hook   = \&call_trigger;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->invoke_hook('BEFORE_INIT');
    $self->init(@_);
    $self->invoke_hook('AFTER_INIT');
    return $self;
}

sub init {
    my($self, $env) = @_;
    $self->req(Plack::Request->new($env));
    $self->res(Plack::Response->new);
    $self->authorizer($self->create_authorizer);
    $self->pad(Pulltoy::Pad->new);
}

sub dispatch {
    my($self, $page) = @_;
    return if $self->finished;

    try {
        $self->init_dispatch($page);
        $self->invoke_hook('BEFORE_DISPATCH') unless $self->finished;
        my $method = 'dispatch_' . $page;
        unless ($self->finished) {
            if ($self->can($method)) {
                $self->$method();
                $self->invoke_hook('AFTER_DISPATCH');
            } else {
                $self->res->code(404);
                $self->finished(1);
            }
        }
    } catch {
        my $code = 500;
        $self->res->code($code);
        $self->res->body(status_message $code);
        warn $_;
    };
    $self->res->finalize;
}

sub init_dispatch {
    my($self, $page) = @_;
    $self->page($page);
    $self->authorizer->authorize($self);
}

1;

