package TEST::Kinetic::Build;

use strict;
use warnings;
use base 'TEST::Class::Kinetic';
use Test::More;
use aliased 'Test::MockModule';
use Test::Exception;
use Test::File;

__PACKAGE__->runtests;

sub test_props : Test(6) {
    my $self = shift;
    my $class = $self->test_class;
    my $mb = MockModule->new($class);
    $mb->mock(check_manifest => sub { return });
    my $builder = $self->new_builder;
    is $builder->accept_defaults, 1, 'Accept Defaults should be enabled';
    is $builder->store, 'sqlite', 'Default store should be "SQLite"';
    is $builder->source_dir, 'lib', 'Default source dir should be "lib"';
    is $builder->conf_file, 'kinetic.conf',
      'Default conf file should be "kinetic.conf"';
    is $builder->run_dev_tests, 0, 'Run dev tests should be disabled';
    is $builder->test_data_dir, $self->data_dir,
      'The test data directory should consistent';
}

sub test_check_store_action : Test(7) {
    my $self = shift;
    my $class = $self->test_class;

    # Break things.
    my $builder;
    my $mb = MockModule->new($class);
    $mb->mock(resume => sub { $builder });
    $mb->mock(check_manifest => sub { return });
    $builder = $self->new_builder(store => 'foo');
    throws_ok { $builder->dispatch('check_store') }
      qr"I'm not familiar with the foo data store",
      "We should get an error for a bogus data store";

    # We can make sure thing work with the default SQLite store.
    my $info = MockModule->new('App::Info::RDBMS::SQLite');
    $info->mock(installed => 1);
    $info->mock(version => '3.0.8');

    $builder = $self->new_builder;
    ok $builder->dispatch('check_store'), "Run check_store";
    is my $kbs_class = $builder->notes('build_store_class'),
      'Kinetic::Build::Store::DB::SQLite',
      '... The store class should be in the notes';
    isa_ok $builder->notes('build_store'), $kbs_class;

    # Make sure that the build action relies on check_store.
    $builder = $self->new_builder;
    $mb->mock('ACTION_code' => 0);
    $mb->mock('ACTION_docs' => 0);
    ok $builder->dispatch('build'), "Run build";
    is $kbs_class = $builder->notes('build_store_class'),
      'Kinetic::Build::Store::DB::SQLite',
      '... The store class should be in the notes';
    isa_ok $builder->notes('build_store'), $kbs_class;
}

sub test_config_action : Test(1){
    my $self = shift;
    my $class = $self->test_class;
    # XXX Add tests for ACTION_config().
    ok 1, " TODO: Add tests for ACTION_config().";
    $self->chdirs($self->data_dir);
    # Copy Kinetic::Util::Config here and test it.
}

sub test_setup_test_action : Test(7) {
    my $self = shift;
    my $class = $self->test_class;

    # We can make sure thing work with the default SQLite store.
    my $info = MockModule->new('App::Info::RDBMS::SQLite');
    $info->mock(installed => 1);
    $info->mock(version => '3.0.8');

    my $builder;
    my $mb = MockModule->new($class);
    $mb->mock(resume => sub { $builder });
    $mb->mock(check_manifest => sub { return });
    $mb->mock('ACTION_code' => 0);
    $builder = $self->new_builder;

    # Dev tests are off.
    ok $builder->dispatch('setup_test'), "Run setup_test action";
    file_exists_ok $self->data_dir, 'We should have a test data directory';
    file_not_exists_ok $self->data_dir . '/kinetic.db',
      '... but not a SQLite database, since dev tests are off';

    # Turn the dev tests on.
    $builder = $self->new_builder( run_dev_tests => 1);
    $builder->source_dir('t/sample');
    ok $builder->dispatch('setup_test'), "Run setup_test action";
    file_exists_ok $self->data_dir, 'We should have a testing data directory';
    file_exists_ok $self->data_dir . '/kinetic.db',
      'SQLite database should now exist';

    # Make sure we clean up our mess.
    $builder->dispatch('clean');
    file_not_exists_ok $self->data_dir, 'Data directory should be deleted';
}

sub new_builder {
    my $self = shift;
    my $class = $self->test_class;
    return $self->{builder} = $class->new(
        dist_name       => 'Testing::Kinetic',
        dist_version    => '1.0',
        quiet           => 1,
        accept_defaults => 1,
        @_,
    );
}
