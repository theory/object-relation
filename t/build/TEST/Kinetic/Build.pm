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
use List::MoreUtils qw(any);

__PACKAGE__->runtests unless caller;

sub teardown_builder : Test(teardown) {
    my $self = shift;
    if (my $builder = delete $self->{builder}) {
        $builder->dispatch('realclean');
    }
}

sub atest_process_conf_files : Test(14) {
    my $self = shift;
    my $class = $self->test_class;

    file_exists_ok 'conf/kinetic.conf', "We should have a default config file";

    # There should be no blib direcory or t/conf directories.
    file_not_exists_ok 'blib/conf/kinetic.conf',
      "We should start with no blib config file";
    file_not_exists_ok 't/conf/kinetic.conf',
      "Nor should there be a t/conf config file";

    # We can make sure things work with the default SQLite store.
    my $info = MockModule->new('App::Info::RDBMS::SQLite');
    $info->mock(installed => 1);
    $info->mock(version => '3.2.2');

    # I mock thee, builder!
    my $builder;
    my $mb = MockModule->new($class);
    $mb->mock(resume => sub { $builder });
    $mb->mock(ACTION_docs => 0);
    $mb->mock(store => 'sqlite');
    $mb->mock(store_config => { class => '' });
    $builder = $self->new_builder;
    $self->{builder} = $builder;

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
    file_contents_like 'blib/conf/kinetic.conf', qr/file\s*:\s*$db_file/,
      '... The database file name should be set properly';
    TODO: {
        local $TODO = 'Need file_contents_unlike()';
        file_contents_like 'blib/conf/kinetic.conf', qr/\s*[pg]\s*\n/,
            '... The PostgreSQL section should be commented out';
    }
    file_contents_like 'blib/conf/kinetic.conf',
      qr/\n\s*\[store\]\s*\n\s*class\s*:\s*\n/,
      '... The store should point to the correct data store';

    # Check the test config file.
    my $test_file = catfile $builder->base_dir, 't', 'data', 'kinetic.db';
    file_contents_like 't/conf/kinetic.conf', qr/file\s*:\s*$test_file/,
      '... The test database file name should be set properly';
    TODO: {
        local $TODO = 'Need file_contents_unlike()';
        file_contents_like 'blib/conf/kinetic.conf', qr/\s*[pg]\s*\n/,
            '... The PostgreSQL section should be commented out';
    }
    file_contents_like 't/conf/kinetic.conf',
      qr/\n\s*\[store\]\s*\n\s*class\s*:\s*\n/,
      '... The store should point to the correct data store in the test conf';

    # Make sure we clean up our mess.
    $builder->dispatch('clean');
    file_not_exists_ok 'blib', 'Build lib should be gone';
}

sub test_bin_files : Test(8) {
    my $self    = shift;
    my $class   = $self->test_class;
    my $bscript = 'blib/script/somescript';

    file_exists_ok 'bin/somescript', 'We should have a bin file';

    # There should be no blib directory.
    file_not_exists_ok $bscript, 'We should start with no blib script file';

    # We can make sure things work with the default SQLite store.
    my $info = MockModule->new('App::Info::RDBMS::SQLite');
    $info->mock(installed => 1);
    $info->mock(version => '3.2.2');

    # I mock thee, builder!
    my $builder;
    my $mb = MockModule->new($class);
    $mb->mock(resume => sub { $builder });
    $mb->mock(ACTION_docs => 0);
    $mb->mock(store => 'sqlite');
    $mb->mock(store_config => { class => '' });
    $builder = $self->new_builder;
    $self->{builder} = $builder;

    # Building should create these things.
    is $builder->dispatch('build'), $builder, "Run the build action";
    diag `pwd`;
    file_exists_ok $bscript, 'Now there should be a blib script file';

    # Check the bin file to be installed.
    my $lib  = File::Spec->catdir($builder->install_base, 'lib');
    file_contents_like $bscript, qr/use lib '$lib';/,
        '... The "use lib" line should be set properly';

    my $config = $builder->config;
    if ($config->{sharpbang} =~ /^\s*\#\!/) {
        my $interpreter = $builder->perl;
        file_contents_like $bscript, qr/\Q$config->{sharpbang}$interpreter/,
            '... And the shebang line should be properly set';

        file_contents_like $bscript, qr/eval 'exec \Q$interpreter/,
            'And the eval exec line should be in place';
    } else {
        pass 'Shebang line irrelevant';
        pass 'eval exec line irrelevant';
    }

    # Make sure we clean up our mess.
    $builder->dispatch('clean');
    file_not_exists_ok 'blib', 'Build lib should be gone';
}

sub test_props : Test(13) {
    my $self = shift;
    my $class = $self->test_class;
    my $mb = MockModule->new($class);
    $mb->mock(check_manifest => sub { return });

    # We can make sure things work with the default SQLite store.
    my $info = MockModule->new('App::Info::RDBMS::SQLite');
    $info->mock(installed => 1);
    $info->mock(version => '3.2.2');

    my $builder = $self->new_builder;
    $self->{builder} = $builder;

    # Make sure the install paths are set.
    my $base = $builder->install_base;
    is_deeply $builder->install_path, {
        lib  => "$base/lib",
        conf => "$base/conf",
    }, 'Make sure that the install paths are set';

    # Make sure that we've added the "config" build element.
    ok any( sub { $_ eq 'conf' }, @{ $builder->build_elements } ),
        'Check for "conf" build element';

    is $builder->accept_defaults, 1, 'Accept Defaults should be enabled';
    is $builder->store, 'sqlite', 'Default store should be "SQLite"';
    is $builder->source_dir, 'lib', 'Default source dir should be "lib"';
    is_deeply $builder->schema_skipper, [],
        'Default schema skippers should be an empty arrayref';
    is $builder->conf_file, 'kinetic.conf',
      'Default conf file should be "kinetic.conf"';
    is $builder->dev_tests, 0, 'Run dev tests should be disabled';
    like $builder->install_base, qr/kinetic$/,
      'The install base should end with "kinetic"';
    is_deeply $builder->store_config, {class => 'Kinetic::Store::DB::SQLite'},
      "The store_config method should set up the SQLite store";

    # Make sure we clean up our mess.
    $builder->dispatch('clean');
    file_not_exists_ok 'blib', 'Build lib should be gone';

    # Don't accept defaults; we should be prompted for stuff.
    my @msgs;
    $mb->mock(_readline => '1');
    $mb->mock(_prompt => sub { shift; push @msgs, @_; });
    my $apache_build = MockModule->new('Kinetic::Build::Engine::Apache2');
    $apache_build->mock(
        _set_httpd => sub { shift->{httpd} = '/usr/bin/apache/httpd' }
    );
    $apache_build->mock(
        _set_httpd_conf => sub { 
            shift->{httpd} = '/usr/bin/apache/conf/httpd.conf';
        }
    );
    my $store = MockModule->new('Kinetic::Build::Store::DB::Pg');
    $store->mock(validate => 1);
    $store->mock(info_class => 'TEST::Kinetic::TestInfo');
    $mb->mock(_is_tty => 1);
    $builder = $self->new_builder(accept_defaults => 0);

    is_deeply \@msgs, [
        "  1> pg\n  2> sqlite\n",
        'Which data store back end should I use?',
        ' [2]:',
        ' ',
        "  1> apache\n  2> simple\n",
        'Which engine should I use?',
        ' [1]:',
        ' ',
        'What password should be used for the default account?',
        ' [change me now!]:',
        ' ',
        'Please enter the port to run the engine on',
        ' [80]:',
        ' ',
        'Please enter the user to run the engine as',
        ' [nobody]:',
        ' ',
        'Please enter the group to run the engine as',
        ' [nobody]:',
        ' ',
        'Please enter the kinetic app root path',
        ' [/kinetic]:',
        ' ',
        'Please enter the kinetic app rest path',
        ' [/kinetic/rest]:',
        ' ',
        'Please enter the kinetic app static files path',
        ' [/]:',
        ' '
    ], 'We should be prompted for the data store and other stuff';

    is $builder->store, 'pg', 'Data store should now be "pg"';
}

sub test_check_store : Test(6) {
    my $self = shift;
    my $class = $self->test_class;

    # Break things.
    my $builder;
    my $mb = MockModule->new($class);
    $mb->mock(resume => sub { $builder });
    $mb->mock(check_manifest => sub { return });
    throws_ok { $self->new_builder(store => 'foo') }
      qr"I'm not familiar with the foo store",
      "We should get an error for a bogus data store";

    # We can make sure thing work with the default SQLite store.
    my $info = MockModule->new('App::Info::RDBMS::SQLite');
    $info->mock(installed => 1);
    $info->mock(version => '3.2.2');

    $builder = $self->new_builder;
    can_ok $builder, 'check_store';
    $builder->dispatch('code');
    isa_ok $builder->notes('build_store'), 'Kinetic::Build::Store';

    # Make sure that the build action relies on check_store.
    $builder = $self->new_builder;
    $self->{builder} = $builder;
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
    $self->mkpath(qw'lib Kinetic Util');
    copy catfile(updir, updir, qw'lib Kinetic Util Config.pm'),
         catdir(qw'lib Kinetic Util');
    my $default = '/usr/local/kinetic/conf/kinetic.conf';

    my $config = catfile qw(lib Kinetic Util Config.pm);
    file_contents_like $config, qr/\s+|| '$default';/,
      qq{Config.pm should point to "$default" by default};

    my $builder;
    my $mb = MockModule->new($class);
    $mb->mock(resume => sub { $builder });
    $mb->mock('ACTION_code' => 0);
    my $base = catdir '', 'foo', 'bar';

    # We can make sure things work with the default SQLite store.
    my $info = MockModule->new('App::Info::RDBMS::SQLite');
    $info->mock(installed => 1);
    $info->mock(version => '3.2.2');

    $builder = $self->new_builder(install_base => $base);
    $self->{builder} = $builder;
    can_ok $builder, 'ACTION_config';
    ok $builder->dispatch('config'),
      "We should be able to dispatch to the config action";

    my $conf_file = catfile $base, 'kinetic', 'conf', 'kinetic.conf';
    file_contents_like $config, qr"\s+|| '$conf_file';",
      qq{Config.pm should now point to "$conf_file"};

    # Clean up our mess.
    unlink $config or die "Unable to delete $config: $!";
}

sub test_get_reply : Test(49) {
    my $self = shift;
    my $class = $self->test_class;

    my $kb = MockModule->new($class);
    $kb->mock(check_manifest => sub { return });
    $kb->mock(check_prereq   => sub { return });
    my $store = MockModule->new('Kinetic::Build::Store');
    $store->mock(validate => 1);
    local @ARGV = qw'--store pg foo=bar';
    my $mb = MockModule->new('Module::Build');
    $kb->mock(_prompt => sub { shift; $self->{output} .= join '', @_; });
    $kb->mock(log_info => sub { shift; $self->{info} .= join '', @_; });
    $kb->mock(_readline => sub {
        chomp $self->{input}[0] if defined $self->{input}[0];
        shift @{$self->{input}};
    });


    # Start not quiet and with defaults accepted.
    my $builder = $self->new_builder(quiet => 0);
    $self->{builder} = $builder;
    my $expected = <<'    END_INFO';
Data store: pg
Kinetic engine: apache
Administrative User password: change me now!
Looking for pg_config
path to pg_config: /usr/local/pgsql/bin/pg_config
Server httpd: /usr/local/apache/bin/httpd
Server httpd_conf: /usr/local/apache/conf/httpd.conf
Server port: 80
Server user: nobody
Server group: nobody
Server kinetic_root: /kinetic
Server kinetic_rest: /kinetic/rest
Server kinetic_static: /
    END_INFO
    is delete $self->{info}, $expected,
      "Should have data store set by command-line option";

    # We should be told what the setting is, but not prompted.
    $builder->{tty} = 1;
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        exp_message => undef,
        exp_info    => "Favorite color: blue\n",
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
        exp_message => undef,
        exp_info    => "Favorite color: blue\n",
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
        exp_message => undef,
        exp_info    => "Favorite color: blue\n",
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
        exp_info    => undef,
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
        exp_info    => undef,
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
        exp_info    => undef,
        exp_value   => 'yellow',
        input_value => 'yellow',
        comment     => "Quiet, but prompted",
    );

    # But we should not be prompted for parameters specified on the
    # command-line.
    $self->try_reply(
        $builder,
        message     => "What store?",
        label       => "Data store",
        name        => 'store',
        default     => 'sqlite',
        exp_message => undef,
        exp_info    => undef,
        exp_value   => 'pg',
        input_value => 'sqlite',
        comment     => "No prompt for command-line property"
    );

    $self->try_reply(
        $builder,
        message     => "What the foo?",
        label       => "Foo me",
        name        => 'foo',
        default     => 'bick',
        exp_message => undef,
        exp_info    => undef,
        exp_value   => 'bar',
        input_value => 'pow',
        comment     => "No prompt for command-line arugment"
    );

    # Try just accepting the default by inputting \n.
    $self->try_reply(
        $builder,
        message     => "What is your favorite color?",
        label       => "Favorite color",
        default     => 'blue',
        exp_message => "What is your favorite color? [blue]: ",
        exp_info    => undef,
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
        exp_info    => undef,
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
        exp_info    => undef,
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
        exp_message => undef,
        exp_info    => "Favorite color: blue\n",
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
        exp_message => undef,
        exp_info    => "Favorite color: blue\n",
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
        exp_info    => undef,
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
        exp_info    => undef,
        exp_value   => 'yellow',
        input_value => ['foo', '3'],
        comment     => "With options by no TTY, we should just get the default",
    );
}

sub try_reply {
    my ($self, $builder, %params) = @_;
    my $exp_msg = delete $params{exp_message};
    my $exp_info = delete $params{exp_info};
    my $exp_value = delete $params{exp_value};
    my $comment = delete $params{comment};
    $self->{input} = ref $params{input_value}
      ? delete $params{input_value}
      : [ delete $params{input_value} ];
    is $builder->get_reply(%params), $exp_value, $comment;

    is delete $self->{output}, $exp_msg, 'Output should be ' .
      (defined $exp_msg ? qq{"$exp_msg"} : 'undef');

    is delete $self->{info}, $exp_info, 'Info should be ' .
      (defined $exp_info ? qq{"$exp_info"} : 'undef');

    delete $self->{input};
    return $self;
}

sub new_builder {
    my $self = shift;
    my $class = $self->test_class;
    $self->{builder} = $class->new(
        dist_name       => 'Testing::Kinetic',
        dist_version    => '1.0',
        quiet           => 1,
        accept_defaults => 1,
        @_,
    );
    return $self->{builder};
}

package TEST::Kinetic::TestInfo;
sub new { bless {} };
sub version { 1 }

1;
__END__
