package TEST::Kinetic::Build::Store::DB;

# $Id$

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Store';
use Test::More;
use Test::Exception;
use aliased 'Test::MockModule';
use aliased 'Kinetic::Build';
use Test::Exception;
use Test::File;
use File::Spec::Functions;

__PACKAGE__->runtests unless caller;
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

sub test_new : Test(4) {
    my $self = shift;
    my $class = $self->test_class;
    return "Constructor must be tested in a subclass"
      if $class eq 'Kinetic::Build::Store::DB';
    # Fake the Kinetic::Build interface.
    my $builder = MockModule->new(Build);
    $builder->mock(resume => sub { bless {}, Build });
    $builder->mock(_app_info_params => sub { } );
    ok my $kbs = $class->new, "Create new $class object";
    isa_ok $kbs, $class;
    isa_ok $kbs->builder, 'Kinetic::Build';
    isa_ok $kbs->info, $kbs->info_class;
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

sub test_rules : Test(27) {
    my $self = shift;
    my $class = $self->test_class;
    return "Constructor must be tested in a subclass"
      if $class eq 'Kinetic::Build::Store::DB';

    # Override builder methods to keep things quiet.
    my $mb = MockModule->new(Build);
    $mb->mock(check_manifest => sub { return });
    my $builder = $self->new_builder;
    $mb->mock(resume => $builder);
    $mb->mock(_app_info_params => sub { } );

    # Construct the object.
    ok my $kbs = $class->new, "Create new $class object";
    isa_ok $kbs, $class;

    # Test behavior if SQLite is not installed
    my $info = MockModule->new($class->info_class);
    $info->mock(installed => 0);
    throws_ok { $kbs->validate }
      qr/SQLite does not appear to be installed/,
      '... and it should die if SQLite is not installed';

    # Test when SQLite is not the correct version.
    $info->mock(installed => 1);
    $info->mock(version => '2.0');
    throws_ok { $kbs->validate }
      qr/SQLite is not the minimum required version/,
      '... or if SQLite is not the minumum supported version';

    # Test when everything is cool.
    $info->mock(version => '3.2.2');
    $mb->mock(prompt => 'fooness');
    ok $kbs->validate,
      '... and it should return a true value if everything is ok';
    is $kbs->db_file, 'fooness',
      '... and set the db_file correctly';
    is_deeply [$kbs->actions], ['build_db'],
      "... and the actions should be set up";

    # Check the DSNs. Make the install base is the same as the test base
    # for the purposes of testing.
    $builder->install_base($builder->test_data_dir);
    my $db_file = catfile 't', 'data', 'store', 'fooness';
    is $kbs->dsn, "dbi:SQLite:dbname=$db_file",
      "...and the DSN should be set";
    my $test_file = catfile 't', 'data', 'fooness';
    is $kbs->test_dsn, "dbi:SQLite:dbname=$test_file",
      "as should the test DSN";

    # Check the configs.
    is_deeply $kbs->config, {file => '$db_file'},
      "... and the configuration should be set";
    is_deeply $kbs->test_config, {file => '$test_file'},
      "... as should the test configuration";

    # Try building the test database.
    $builder->source_dir('t/sample/lib');
    file_not_exists_ok $test_file,
      "The test database file should not yet exist";
    ok $kbs->test_build, "Build the test database";
    file_exists_ok $test_file, "The test database file should now exist";

    # Make sure that the views were created.
    my $dbh = DBI->connect($kbs->test_dsn, '', '', {
        RaiseError     => 0,
        PrintError     => 0,
        HandleError    => Kinetic::Util::Exception::DBI->handler,
    });

    for my $view (qw'simple one two composed comp_comp') {
        is_deeply $dbh->selectall_arrayref(
            "SELECT 1 FROM sqlite_master WHERE type ='view' AND name = ?",
            {}, $view
        ), [[1]], "View $view should exist";
    }

    # Try building the production database.
    unlink $test_file;
    $self->mkpath('t', 'data', 'store');
    file_not_exists_ok $db_file,
      "The database file should not yet exist";
    ok $kbs->build, "Build the database";
    file_exists_ok $db_file, "The database file should now exist";

    # Make sure that the views were created.
    $dbh->disconnect;
    $dbh = DBI->connect($kbs->dsn, '', '', {
        RaiseError     => 0,
        PrintError     => 0,
        HandleError    => Kinetic::Util::Exception::DBI->handler,
    });

    for my $view (qw'simple one two composed comp_comp') {
        is_deeply $dbh->selectall_arrayref(
            "SELECT 1 FROM sqlite_master WHERE type ='view' AND name = ?",
            {}, $view
        ), [[1]], "View $view should exist";
    }
    $dbh->disconnect;
    unlink $db_file;
}

sub new_builder {
    my $self = shift;
    local $SIG{__DIE__} = sub {
        Kinetic::Util::Exception::ExternalLib->throw(shift);
    };
    return $self->{builder} = Build->new(
        dist_name       => 'Testing::Kinetic',
        dist_version    => '1.0',
        quiet           => 1,
        accept_defaults => 1,
        engine          => 'simple',
        @_,
    )
}

1;
__END__
