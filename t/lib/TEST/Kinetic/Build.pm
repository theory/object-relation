package TEST::Kinetic::Build;

# $Id$

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

sub atest_process_conf_files : Test(14) {
    my $self = shift;
    my $class = $self->test_class;

    $self->chdirs('t', 'sample');
    local @INC = (catdir(updir, updir, 'lib'), @INC);
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

    use Carp; $SIG{__DIE__} = \&Carp::confess;
    # I mock thee, builder!
    my $builder;
    my $mb = MockModule->new($class);
    $mb->mock(resume => sub { $builder });
    $mb->mock('ACTION_docs' => 0);
    $builder = $self->new_builder;

    # Building should create these things.
    is $builder->dispatch('build'), $builder, "Run the build action";
    file_exists_ok 'blib/conf/kinetic.conf',
      "Now there should be a blib config file";
    file_exists_ok 't/conf/kinetic.conf',
      "And there should be a t/conf config file";
    is $ENV{KINETIC_CONF}, catfile(qw'blib conf kinetic.conf'),
      "The KINETIC_CONF environment variable should point to the new config file";

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

sub test_props : Test(9) {
    my $self = shift;
    my $class = $self->test_class;

    $self->chdirs('t', 'sample');
    local @INC = (catdir(updir, updir, 'lib'), @INC);

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

    # Make sure we clean up our mess.
    $builder->dispatch('clean');
    file_not_exists_ok 'blib', 'Build lib should be gone';
}

sub test_check_store_action : Test(6) {
    my $self = shift;
    my $class = $self->test_class;

    $self->chdirs('t', 'sample');
    local @INC = (catdir(updir, updir, 'lib'), @INC);

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
    isa_ok $builder->notes('build_store'), 'Kinetic::Build::Store';

    # Make sure that the build action relies on check_store.
    $builder = $self->new_builder;
    $mb->mock('ACTION_code' => 0);
    $mb->mock('ACTION_docs' => 0);
    ok $builder->dispatch('build'), "Run build";
    isa_ok $builder->notes('build_store'), 'Kinetic::Build::Store';
    $builder->dispatch('clean');
    file_not_exists_ok 'blib', 'Build lib should be gone';
}

sub test_config_action : Test(4) {
    my $self = shift;
    my $class = $self->test_class;

    # Copy Kinetic::Util::Config to data dir (not sample!).
    $self->mkpath(qw't data lib Kinetic Util');
    copy catfile(qw'lib Kinetic Util Config.pm'),
         catdir($self->data_dir, qw'lib Kinetic Util');
    $self->chdirs($self->data_dir);
    my $default = '/usr/local/kinetic/conf/kinetic.conf';

    my $config = catfile qw'lib Kinetic Util Config.pm';
    file_contents_like $config, qr"\s+|| '$default';",
      qq{Config.pm should point to "$default" by default};

    my $builder;
    my $mb = MockModule->new($class);
    $mb->mock(resume => sub { $builder });
    $mb->mock('ACTION_code' => 0);
    my $base = catdir '', 'foo', 'bar';
    $builder = $self->new_builder(install_base => $base);
    can_ok $builder, 'ACTION_config';
    ok $builder->dispatch('config'),
      "We should be able to dispatch to the config action";

    my $conf_file = catfile $base, 'kinetic', 'conf', 'kinetic.conf';
    file_contents_like $config, qr"\s+|| '$conf_file';",
      qq{Config.pm should now point to "$conf_file"};

    # Clean up our mess.
    unlink $config or die "Unable to delete $config: $!";
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

    $self->chdirs(qw't sample');
    local @INC = (catdir(updir, updir, 'lib'), @INC);
    $builder = $self->new_builder;

    # Dev tests are off.
    file_not_exists_ok $self->data_dir,
      'We should not yet have a test data directory';
    ok $builder->dispatch('setup_test'), "Run setup_test action";
    file_exists_ok $self->data_dir, 'Now we should have a test data directory';
    file_not_exists_ok $self->data_dir . '/kinetic.db',
      '... but not a SQLite database, since dev tests are off';

    # Turn the dev tests on.
    $builder = $self->new_builder( run_dev_tests => 1);
    $builder->source_dir('lib');
    ok $builder->dispatch('setup_test'), "Run setup_test action";
    file_exists_ok $self->data_dir . '/kinetic.db',
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
    file_not_exists_ok $self->data_dir, 'Data directory should be deleted';
}

sub test_get_reply : Test(28) {
    my $self = shift;
    my $class = $self->test_class;

    $self->chdirs('t', 'sample');
    local @INC = (catdir(updir, updir, 'lib'), @INC);

    my $kb = MockModule->new($class);
    $kb->mock(check_manifest => sub { return });
    my $mb = MockModule->new('Module::Build');
    $kb->mock(_prompt => sub { shift; $self->{output} .= join '', @_; });
    $kb->mock(_readline => sub {
        chomp $self->{input}[0] if defined $self->{input}[0];
        shift @{$self->{input}};
    });

    # Start not quiet and with defaults accepted.
    my $builder = $self->new_builder(quiet => 0);
    $builder->{tty} = 1;
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        exp_message => "Favorite color: blue",
        exp_value   => 'blue',
        input_value => 'blue',
        comment     => "With defaults accepted, should not be prompted",
    );

    # We should get blue and no prompt with defaults accepted even when
    # we set up an answer (which will never be fetched).
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        exp_message => "Favorite color: blue",
        exp_value   => 'blue',
        input_value => 'red',
        comment     => "With defaults accepted, should not be prompted",
    );

    # With TTY off, we should get the same answer.
    $builder->{tty} = 0;
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        exp_message => "Favorite color: blue",
        exp_value   => 'blue',
        input_value => 'blue',
        comment     => "We shouldn't get prompted with TTY",
    );

    # If we go into quiet mode, there should be no prompt at all!
    $builder->quiet(1);
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        exp_message => undef,
        exp_value   => 'blue',
        input_value => 'blue',
        comment     => "No prompt in quiet mode with no TTY.",
    );

    # Even with TTY back on we should get no output.
    $builder->{tty} = 1;
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        exp_message => undef,
        exp_value   => 'blue',
        input_value => 'blue',
        comment     => "No prompt in quiet mode with TTY.",
    );

    # But if we no longer accept defaults, we should be prompted, even with
    # quiet on.
    $builder->accept_defaults(0);
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        exp_message => "What is your favorite color? [blue]: ",
        exp_value   => 'yellow',
        input_value => 'yellow',
        comment     => "Quiet, but prompted",
    );

    # Try just accepting the default by inputting \n.
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        exp_message => "What is your favorite color? [blue]: ",
        exp_value   => 'blue',
        input_value => "\n",
        comment     => "We should be able to accept the default",
    );

    # Now try a callback.
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        exp_message => "What is your favorite color? [blue]: "
                       . "\nInvalid selection, please try again [blue]: ",
        exp_value   => 'red',
        input_value => ['foo', 'red'],
        callback    => sub { $_ eq 'red' },
        comment     => "We should be able to check our answer with a callback",
    );

    # Turn quiet back off and we should still get the answer we specify.
    $builder->quiet(0);
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        exp_message => "What is your favorite color? [blue]: ",
        exp_value   => 'red',
        input_value => 'red',
        comment     => "Without defaults accepted, we should be prompted",
    );

    # And if we specify no default, it shouldn't appear in the message.
    $builder->quiet(0);
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        exp_message => "What is your favorite color? ",
        exp_value   => 'red',
        input_value => 'red',
        comment     => "With no default, there should be none in the message",
    );

    # But with TTY disabled, no more prompt, and our input will be ignored.
    $builder->{tty} = 0;
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        exp_message => "Favorite color: blue",
        exp_value   => 'blue',
        input_value => 'red',
        comment     => "Without defaults accepted, by no TTY, our answer should be igored",
    );

    # The same should hold true even if we specify options.
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        options     => ['red', 'blue', 'yellow', 'orange'],
        exp_message => "Favorite color: blue",
        exp_value   => 'blue',
        input_value => 'red',
        comment     => "With options by no TTY, we should just get the default",
    );

    # Now if we turn TTY back on, we should be prompted for options.
    $builder->{tty} = 1;
    $self->try_reply(
        $builder,
        message     => "Please select your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        options     => ['red', 'blue', 'yellow', 'orange'],
        exp_message => "  1> red\n  2> blue\n  3> yellow\n  4> orange\n"
                       . "Please select your favorite color? [2]: ",
        exp_value   => 'blue',
        input_value => '2',
        comment     => "With options by no TTY, we should just get the default",
    );

    # Now we should go into a loop if we put in the wrong answer.
    $builder->{tty} = 1;
    $self->try_reply(
        $builder,
        message     => "Please select your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        options     => ['red', 'blue', 'yellow', 'orange'],
        exp_message => "  1> red\n  2> blue\n  3> yellow\n  4> orange\n"
                       . "Please select your favorite color? [2]: "
                       . "\nInvalid selection, please try again [2]: ",
        exp_value   => 'yellow',
        input_value => ['foo', '3'],
        comment     => "With options by no TTY, we should just get the default",
    );
}

sub try_reply {
    my ($self, $builder, %params) = @_;
    my $exp_msg = delete $params{exp_message};
    my $exp_value = delete $params{exp_value};
    my $comment = delete $params{comment};
    $self->{input} = ref $params{input_value}
      ? delete $params{input_value}
      : [ delete $params{input_value} ];
    is $builder->get_reply(%params), $exp_value, $comment;

    is delete $self->{output}, $exp_msg, 'Output should be ' .
      (defined $exp_msg ? qq{"$exp_msg"} : 'undef');

    delete $self->{input};
    return $self;
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
