package TEST::Kinetic::Build;

use strict;
use warnings;
use base 'TEST::Class::Kinetic';
use Test::More;
use aliased 'Test::MockModule';
use Test::Exception;
use Test::File;
use Test::File::Contents;
use File::Copy;
use File::Spec::Functions;

__PACKAGE__->runtests;

sub test_props : Test(8) {
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
    like $builder->install_base, qr/kinetic$/,
      'The install base should end with "kinetic"';
    is $builder->store_config, "    class => 'Kinetic::Store::DB::SQLite',\n",
      "The store_config method should set up the SQLite store";
}

sub test_check_store_action : Test(5) {
    my $self = shift;
    my $class = $self->test_class;

    # Break things.
    my $builder;
    my $mb = MockModule->new($class);
    $mb->mock(resume => sub { $builder });
    $mb->mock(check_manifest => sub { return });
    $self->chdirs($self->data_dir);
    local @INC = (catdir(updir, updir, 'lib'), @INC);
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
    isa_ok $builder->notes('build_store'), 'Kinetic::Build::Store';

    # Make sure that the build action relies on check_store.
    $builder = $self->new_builder;
    $mb->mock('ACTION_code' => 0);
    $mb->mock('ACTION_docs' => 0);
    ok $builder->dispatch('build'), "Run build";
    isa_ok $builder->notes('build_store'), 'Kinetic::Build::Store';
    $builder->dispatch('clean');
}

sub test_config_action : Test(1){
    my $self = shift;
    my $class = $self->test_class;
    # XXX Add tests for ACTION_config().
    ok 1, " TODO: Add tests for ACTION_config().";
    $self->chdirs($self->data_dir);
    local @INC = (catdir(updir, updir, 'lib'), @INC);
    # Copy Kinetic::Util::Config here and test it.
}

sub test_test_actions : Test(9) {
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
    my $data_dir = catdir(Cwd::getcwd, $self->data_dir, 'data');
    $mb->mock(test_data_dir => sub () { $data_dir });
    $self->chdirs($self->data_dir);
    local @INC = (catdir(updir, updir, 'lib'), @INC);
    $builder = $self->new_builder;

    # Dev tests are off.
    file_not_exists_ok $data_dir, 'We should not yet have a test data directory';
    ok $builder->dispatch('setup_test'), "Run setup_test action";
    file_exists_ok $data_dir, 'Now we should have a test data directory';
    file_not_exists_ok $data_dir . '/kinetic.db',
      '... but not a SQLite database, since dev tests are off';

    # Turn the dev tests on.
    $builder = $self->new_builder( run_dev_tests => 1);
    $builder->source_dir(catdir updir, 'sample');
    ok $builder->dispatch('setup_test'), "Run setup_test action";
    file_exists_ok $data_dir . '/kinetic.db',
      'SQLite database should now exist';

    # Make sure that the test_teardown action calls the store's test_cleanup
    # method.
    my $store = MockModule->new('Kinetic::Build::Store::DB::SQLite');
    $store->mock('test_cleanup' =>
                   sub { ok 1, "Store->test_cleanup should be called" });
    ok $builder->dispatch('teardown_test'),
      "We should be able to execute the teardown_test action";

    # Make sure we clean up our mess.
    $builder->dispatch('clean');
    file_not_exists_ok $data_dir, 'Data directory should be deleted';
}

sub test_process_conf_files : Test(13) {
    my $self = shift;
    my $class = $self->test_class;

    # Copy the configuration file for us to play with without hurting anybody.
    $self->mkpath(qw't data conf');
    $self->mkpath(qw't data t');
    copy catfile(qw'conf kinetic.conf'), catdir(qw't data conf');
    $self->chdirs('t', 'data');
    file_exists_ok 'conf/kinetic.conf', "We should have a default config file";

    # There should be no blib direcory or t/conf directories.
    file_not_exists_ok 'blib/conf/kinetic.conf',
      "We should start with no blib config file";
    file_not_exists_ok 't/conf/kinetic.conf',
      "Nor should there be a t/conf config file";

    # We can make sure thing work with the default SQLite store.
    my $info = MockModule->new('App::Info::RDBMS::SQLite');
    $info->mock(installed => 1);
    $info->mock(version => '3.0.8');

    # I mock thee, builder!
    my $builder;
    my $mb = MockModule->new($class);
    $mb->mock(resume => sub { $builder });
    $mb->mock('ACTION_docs' => 0);
    $builder = $self->new_builder;

    # Building should create these things.
    is $builder->dispatch('build'), $builder, "Run check_store";
    file_exists_ok 'blib/conf/kinetic.conf',
      "Now there should be a blib config file";
    file_exists_ok 't/conf/kinetic.conf',
      "And there should be a t/conf config file";

    # Check the config file to be installed.
    my $db_file = catfile $builder->install_base, 'store', 'kinetic.db';
    file_contents_like 'blib/conf/kinetic.conf', qr/file\s+=>\s+'$db_file',/,
      '... The database file name should be set properly';
    file_contents_like 'blib/conf/kinetic.conf', qr/#\s*pg\s+=>\s+{/,
      '... The PostgreSQL section should be commented out';
    file_contents_like 'blib/conf/kinetic.conf',
      qr/\n\s*store\s*=>\s*{\s*class\s*=>\s*'Kinetic::Store::DB::SQLite'/,
      '... The store should point to the correct data store';

    # Check the test config file.
    my $test_file = catfile 't', 'data', 'kinetic.db';
    file_contents_like 't/conf/kinetic.conf', qr/file\s+=>\s+'$test_file',/,
      '... The test database file name should be set properly';
    file_contents_like 't/conf/kinetic.conf', qr/#\s*pg\s+=>\s+{/,
      '... The PostgreSQL section should be commented out in the test conf';
    file_contents_like 't/conf/kinetic.conf',
      qr/\n\s*store\s*=>\s*{\s*class\s*=>\s*'Kinetic::Store::DB::SQLite'/,
      '... The store should point to the correct data store in the test conf';

    # Make sure we clean up our mess.
    $builder->dispatch('clean');
    file_not_exists_ok 'blib', 'Build lib should be gone';
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

1;
__END__
