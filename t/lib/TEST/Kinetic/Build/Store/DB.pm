package TEST::Kinetic::Build::Store::DB;

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Store';
use Test::More;

__PACKAGE__->runtests;
sub test_interface : Test(+5) {
    shift->SUPER::test_interface(qw(
        dsn test_dsn create_dsn dbd_class dsn_dbd
    ));
}

1;
__END__
