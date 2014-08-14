package Gion::Batch::Useradd;
use base qw/Gion::Batch/;

use Getopt::Long qw(GetOptionsFromArray);
use Gion::Util::Auth;
use Gion::DB;

sub run {
    my $self   = shift;
    my $data;
    GetOptionsFromArray(\@_, 
        "user=s" => \$data->{user},
        "pass=s" => \$data->{pass},
        "overwrite" => \$data->{force},
    );

    unless (defined $data->{user} || defined $data->{pass}){
        warn "--user ID --pass Password";
        exit();
    }

    my $a = Gion::Util::Auth->new(
        strech => $self->config->{strech} || 500,
        salt   => $self->config->{salt}   || "Gion::Util::Auth",
        id     => $data->{user},
        passwd => $data->{pass},
    );

    my $pw = $a->get_hash;

    my $db = Gion::DB->new;
    if(defined $data->{force}){
        $db->dbh->query('UPDATE user SET pw = ? WHERE name = ?', $pw,$data->{user});
        warn "Password Change: " . $data->{user};
    }else{
        $db->dbh->query('INSERT INTO user (id,pw,name) VALUES (null,?,?)', $pw,$data->{user});
        warn "User Added: " . $data->{user};
    }
}

1;
