package TEST::Kinetic::Build::Store::DB;

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Store';
use Test::More;
use Test::Exception;
use aliased 'Test::MockModule';
use aliased 'Kinetic::Build';
use Test::Exception;

__PACKAGE__->runtests;
sub test_interface : Test(+5) {
    shift->SUPER::test_interface(qw(
        dsn test_dsn create_dsn dbd_class dsn_dbd
    ));
}

sub test_db_class_methods : Test(2) {
    my $self = shift;
    my $class = $self->test_class;
    if ($class eq 'Kinetic::Build::Store::DB') {
        throws_ok { $class->dbd_class }
          qr'dbd_class\(\) must be overridden in the subclass',
            'dbd_class() needs to be overridden';
        my $store = MockModule->new($class);
        $store->mock(dbd_class => 'DBD::SQLite');
        is $class->dsn_dbd, 'SQLite',
          "dsn_dbd() should get its value from dbd_class()";
    } else {
        ok $class->dbd_class, "We should have a DBD class";
        ok $class->dsn_dbd, "We should have a DSN DBD";
    }
}

sub test_db_instance_methods : Test(4) {
    my $self = shift;
    my $class = $self->test_class;

    # Fake the Kinetic::Build interface.
    my $builder = MockModule->new(Build);
    $builder->mock(resume => sub { bless {}, Build });
    $builder->mock(_app_info_params => sub { } );
    my $store = MockModule->new($class);
    $store->mock(info_class => 'TEST::Kinetic::TestInfo');

    # Create an object and try basic accessors.
    ok my $kbs = $class->new, "Create new $class object";

  SKIP: {
        skip "DSN methods should be tested in subclasses", 3
          unless $class eq 'Kinetic::Build::Store::DB';
        throws_ok { $kbs->dsn }
          qr'dsn\(\) must be overridden in the subclass',
          'dsn() needs to be overridden';
        throws_ok { $kbs->test_dsn }
          qr'test_dsn\(\) must be overridden in the subclass',
          'test_dsn() needs to be overridden';
        throws_ok { $kbs->create_dsn }
          qr'dsn\(\) must be overridden in the subclass',
          'create_dsn should use dsn()';
    }
}

1;
__END__
