package resolver;

sub new {
    bless {}, shift;
}

sub resolve {
    [ "127.0.0.1" ]
}

1;

__END__

mock of Net::DNS::Paranoid
