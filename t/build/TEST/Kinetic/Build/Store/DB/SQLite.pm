package TEST::Kinetic::Build::Store::DB::SQLite;

# $Id$

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Store::DB';
use Test::More;
use aliased 'Test::MockModule';
use aliased 'Kinetic::Build';
use Test::Exception;
use File::Spec::Functions;
use Test::File;

__PACKAGE__->runtests unless caller;

sub test_class_methods : Test(8) {
    my $test = shift;
    my $class = $test->test_class;
    is $class->info_class, 'App::Info::RDBMS::SQLite',
      'We should have the correct App::Info class';
    is $class->min_version, '3.0.8',
      'We should have the correct minimum version number';
    is $class->max_version, 0,
      'We should have the correct maximum version number';
    is $class->schema_class, 'Kinetic::Build::Schema::DB::SQLite',
      'We should have the correct schema class';
    is $class->store_class, 'Kinetic::Store::DB::SQLite',
      'We should have the correct store class';
    is $class->dbd_class, 'DBD::SQLite',
      'We should have the correct DBD class';
    is $class->dsn_dbd, 'SQLite',
      'We should have the correct DSN DBD string';
    ok $class->rules, "We should get some rules";
}

sub test_rules : Test(27) {
    my $self = shift;
    my $class = $self->test_class;

    # Override builder methods to keep things quiet.
    my $mb = MockModule->new(Build);
    $mb->mock(check_manifest => sub { return });
    my $builder = $self->new_builder;
    $self->{builder} = $builder;
    $mb->mock(resume => $builder);
    $mb->mock(_app_info_params => sub { } );

    # Construct the object.
    ok my $kbs = $class->new, "Create new $class object";
    isa_ok $kbs, $class;
    $builder->notes(build_store => $kbs);

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
    $info->mock(version => '3.0.8');
    $mb->mock(get_reply => 'fooness');
    ok $kbs->validate,
      '... and it should return a true value if everything is ok';
    is $kbs->db_file, 'fooness',
      '... and set the db_file correctly';
    is_deeply [$kbs->actions], ['build_db'],
      "... and the actions should be set up";

    # Check the DSNs. Make sure that the install base is the same as the test
    # base for the purposes of testing.
    $builder->install_base(curdir);
    my $db_file = catfile 'store', 'fooness';
    is $kbs->dsn, "dbi:SQLite:dbname=$db_file",
      "...and the DSN should be set";
    my $test_file = catfile 't', 'data', 'fooness';
    is $kbs->test_dsn, "dbi:SQLite:dbname=$test_file",
      "as should the test DSN";

    # Check the configs.
    $mb->mock(store => 'sqlite');
    is_deeply $kbs->config, {file => $db_file},
      "... and the configuration should be set";
    is_deeply $kbs->test_config, {file => $test_file},
      "... as should the test configuration";

    # Just skip the remaining tests if we can't test against a live database.
    return "Not testing SQLite" unless $self->supported('sqlite');

    # Try building the test database.
    $builder->source_dir('lib');
    $builder->dispatch('code');
    $self->mkpath('t', 'data');
    file_not_exists_ok $test_file,
      "The test database file should not yet exist";
    ok $kbs->test_build, "Build the test database";
    file_exists_ok $test_file, "The test database file should now exist";

    # Make sure that the views were created.
    my $dbh = DBI->connect($kbs->test_dsn, '', '');
    my $sg = $kbs->schema_class->new;
    $sg->load_classes($kbs->builder->source_dir);
    for my $class ($sg->classes) {
        my $view = $class->key;
        is_deeply $dbh->selectall_arrayref(
            "SELECT 1 FROM sqlite_master WHERE type ='view' AND name = ?",
            {}, $view
        ), [[1]], "View $view should exist";
    }

    # Try building the production database.
    unlink $test_file;
    $self->mkpath('store');
    file_not_exists_ok $db_file,
      "The database file should not yet exist";
    ok $kbs->build, "Build the database";
    file_exists_ok $db_file, "The database file should now exist";

    # Make sure that the views were created.
    $dbh->disconnect;
    $dbh = DBI->connect($kbs->dsn, '', '');
    for my $view (qw'simple one two composed comp_comp') {
        is_deeply $dbh->selectall_arrayref(
            "SELECT 1 FROM sqlite_master WHERE type ='view' AND name = ?",
            {}, $view
        ), [[1]], "View $view should exist";
    }
    $dbh->disconnect;
    unlink $db_file;
}

1;
__END__
