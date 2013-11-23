package Gion::Gion::Plugin::Auth;
use Mojo::Base 'Mojolicious::Plugin';
use Digest::SHA qw(sha512_hex);

our $FIXEDSALT;

sub register {
    my ( $self, $app ) = @_;
    $FIXEDSALT = $app->{config}->{salt};
    $app->helper( authenticate => sub { _authenticate(@_) } );
}

sub _authenticate {
    my $self = shift;
    my $pw   = get_password_hash(@_);
    return undef unless defined $pw;
    my $db = $self->{app}->dbh;
    my $rs =
      $db->execute( 'SELECT name, id FROM user WHERE pw = :pw', { pw => $pw } )
      or die $db->error;
    my $c = $rs->fetch_hash;

    return $c if defined $c;
    return undef;
}

# ソルトを生成する
sub get_salt {
    my ($id) = @_;
    return $id
      . pack( 'H*', $FIXEDSALT );    # ユーザIDと固定文字列を連結
}

# ソルト化ハッシュを繰り返し求める（ストレッチング）
sub get_password_hash {
    my $STRETCHCOUNT = 500;

    my ( $id, $pwd ) = @_;
    return undef unless defined $id;
    return undef unless defined $pwd;
    return undef if length($id) == 0 or length($pwd) == 0;

    my $salt = get_salt($id);
    my $hash = '';              # ハッシュの初期値
    for ( my $i = 0 ; $i < $STRETCHCOUNT ; $i++ ) {
        $hash = sha512_hex( $hash . $pwd . $salt );    # ストレッチング
    }
    return $hash;
}

1;
