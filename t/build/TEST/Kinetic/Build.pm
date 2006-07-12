package TEST::Kinetic::Build;

# $Id$

use strict;
use warnings;
use base 'TEST::Class::Kinetic';
use Test::More;
use aliased 'Test::MockModule';
use Class::Trait; # Avoid warnings.
use Test::Exception;
use Test::File;
use Test::File::Contents;
use File::Copy;
use File::Spec::Functions qw(catfile updir catdir tmpdir);
use List::MoreUtils qw(any);

__PACKAGE__->runtests unless caller;

sub teardown_builder : Test(teardown) {
    my $self = shift;
    if (my $builder = delete $self->{builder}) {
        $builder->dispatch('realclean');
    }
}

sub test_props : Test(7) {
    my $self = shift;
    my $class = $self->test_class;
    my $mb = MockModule->new($class);
    $mb->mock(check_manifest => sub { return });

    # We can make sure things work with the default SQLite store.
    my $info = MockModule->new('App::Info::RDBMS::SQLite');
    $info->mock(installed => 1);
    $info->mock(version => '3.2.2');

    my $builder = $self->new_builder;

    is $builder->accept_defaults, 1, 'Accept Defaults should be enabled';
    is $builder->store, 'sqlite', 'Default store should be "SQLite"';
    is $builder->source_dir, 'lib', 'Default source dir should be "lib"';
    is $builder->dev_tests, 0, 'Run dev tests should be disabled';

    # Make sure we clean up our mess.
    $builder->dispatch('clean');
    file_not_exists_ok 'blib', 'Build lib should be gone';

    # Don't accept defaults; we should be prompted for stuff.
    my @msgs;
    my @inputs = (1, '');
    $mb->mock(_readline => sub { shift @inputs }); # Accept defaults.
    $mb->mock(_prompt => sub { shift; push @msgs, @_; });
    my $store = MockModule->new('Kinetic::Build::Setup::Store::DB::Pg');
    $store->mock(validate => 1);
    $store->mock(info_class => 'TEST::Kinetic::TestInfo');
    $mb->mock(_is_tty => 1);
    $builder = $self->new_builder(accept_defaults => 0);

    is_deeply \@msgs, [
        "  1> pg\n  2> sqlite\n",
        'Which data store back end should I use?',
        ' [2]:',
        ' ',
    ], 'We should be prompted for the data store and other stuff';

    is $builder->store, 'pg', 'Data store should now be "pg"';
}

sub test_check_store : Test(4) {
    my $self = shift;
    my $class = $self->test_class;

    # Break things.
    my $builder;
    my $mb = MockModule->new($class);
    $mb->mock(resume => sub { $builder });
    $mb->mock(check_manifest => sub { return });
    throws_ok { $self->new_builder(store => 'foo') }
        qr/I'm not familiar with the foo store/,
        'We should get an error for a bogus data store';

    # We can make sure thing work with the default SQLite store.
    my $info = MockModule->new('App::Info::RDBMS::SQLite');
    $info->mock(installed => 1);
    $info->mock(version => '3.2.2');

    $builder = $self->new_builder;
    $builder->dispatch('code');
    isa_ok $builder->notes('build_store'), 'Kinetic::Build::Setup::Store';

    # Make sure that the build action checks the store.
    $builder = $self->new_builder;
    $mb->mock('ACTION_docs' => 0);
    $builder->dispatch('build');
    isa_ok $builder->notes('build_store'), 'Kinetic::Build::Setup::Store';
    $builder->dispatch('clean');
    file_not_exists_ok 'blib', 'Build lib should be gone';
}

sub test_ask_y_n : Test(34) {
    my $self = shift;
    my $class = $self->test_class;

    my $kb = MockModule->new($class);
    $kb->mock(check_manifest => sub { return });
    $kb->mock(check_prereq   => sub { return });
    my $store = MockModule->new('Kinetic::Build::Setup::Store');
    $store->mock(validate => 1);
    local @ARGV = qw(--store pg);
    my $mb = MockModule->new('Module::Build');
    $kb->mock(_prompt => sub { shift; $self->{output} .= join '', @_; });
    $kb->mock(log_info => sub { shift; $self->{info} .= join '', @_; });
    $kb->mock(_readline => sub {
        chomp $self->{input}[0] if defined $self->{input}[0];
        shift @{$self->{input}};
    });

    my %params = (
        name    => 'ok',
        label   => 'OK',
        message => 'You OK?',
        default => 1,
    );

    # Start with accept_defaults => 1, quiet => 1.
    ok my $builder = $self->new_builder, 'Create new Build object';
    $builder->{tty} = 1;
    ok $builder->ask_y_n(%params), 'Test for true default';
    is $self->{output}, undef, 'There should have been no prompt';
    is $self->{info}, undef, 'There should be no info';

    # Change default to false.
    $params{default} = 0;
    ok !$builder->ask_y_n(%params), 'Test for false default';
    is $self->{output}, undef, 'There should have been no prompt';
    is $self->{info}, undef, 'There should be no info';

    # Enable info.
    $builder->quiet(0);
    ok !$builder->ask_y_n(%params), 'Test for false default with info';
    is $self->{output}, undef, 'There should have been no prompt';
    is delete $self->{info}, "OK: no\n", 'There should be info';

    # Try command-line option.
    @ARGV = qw(--store pg --ok 1);
    ok $builder = $self->new_builder, 'Create new Build object';
    $builder->accept_defaults(0);
    ok $builder->ask_y_n(%params), 'Test for true command-line option';
    is $self->{output}, undef, 'There should have been no prompt';
    is $self->{info}, undef, 'There should be no info';

    # Try false command-line option.
    @ARGV = qw(--store pg --ok 0);
    ok $builder = $self->new_builder, 'Create new Build object';
    $builder->accept_defaults(0);
    $params{default} = 1;
    ok !$builder->ask_y_n(%params), 'Test for false command-line option';
    is $self->{output}, undef, 'There should have been no prompt';
    is $self->{info}, undef, 'There should be no info';

    # Turn off quiet.
    $builder->quiet(0);
    ok !$builder->ask_y_n(%params), 'Test non-quiet command-line option';
    is $self->{output}, undef, 'There should have been no prompt';
    is delete $self->{info}, "OK: no\n", 'There should be info';

    # Now we actually prompt.
    local @ARGV = qw(--store pg);
    ok $builder = $self->new_builder, 'Create new Build object';
    $builder->accept_defaults(0);
    $builder->quiet(0);
    ok $builder->ask_y_n(%params), 'Test for true for answer ""';
    is delete $self->{output}, 'You OK? [y]: ',
        'There should have been a prompt';
    is $self->{info}, undef, 'There should be no info';

    # Now test for an answer 'y'.
    $self->{input} = ['y'];
    ok $builder->ask_y_n(%params), 'Test for true for answer "y"';
    is delete $self->{output}, 'You OK? [y]: ',
        'There should have been a prompt';
    is $self->{info}, undef, 'There should be no info';

    # Now test for answer 'No'.
    $self->{input} = ['No'];
    ok !$builder->ask_y_n(%params), 'Test for false for answer "No"';
    is delete $self->{output}, 'You OK? [y]: ',
        'There should have been a prompt';
    is $self->{info}, undef, 'There should be no info';

    # And finally, put in a bogus answer.
    $self->{input} = ['foo', ''];
    ok $builder->ask_y_n(%params), 'Test for bogus answer';
    is delete $self->{output},
        "You OK? [y]: Please answer 'y' or 'n' [y]: ",
        'There should have been two prompts';
    is $self->{info}, undef, 'There should be no info';
}

sub test_get_reply : Test(53) {
    my $self = shift;
    my $class = $self->test_class;

    my $kb = MockModule->new($class);
    $kb->mock(check_manifest => sub { return });
    $kb->mock(check_prereq   => sub { return });
    my $store = MockModule->new('Kinetic::Build::Setup::Store');
    $store->mock(validate => 1);
    local @ARGV = qw(--store pg foo=bar --hey you --hey me);
    my $mb = MockModule->new('Module::Build');
    $kb->mock(_prompt => sub { shift; $self->{output} .= join '', @_; });
    $kb->mock(log_info => sub { shift; $self->{info} .= join '', @_; });
    $kb->mock(_readline => sub {
        chomp $self->{input}[0] if defined $self->{input}[0];
        shift @{$self->{input}};
    });

    # Start not quiet and with defaults accepted.
    my $builder = $self->new_builder(quiet => 0);

    my $expected = <<"    END_INFO";
Data store: pg
Looking for pg_config
path to pg_config: /usr/local/pgsql/bin/pg_config
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

    # Multiple options on the command-line should give us an array.
    $builder->quiet(0);
    $self->try_reply(
        $builder,
        message     => "Hey who?",
        label       => "Hey who",
        name        => 'hey',
        default     => 'them',
        exp_message => undef,
        exp_info    => "Hey who: you, me\n",
        exp_value   => [qw(you me)],
        input_value => '',
        comment     => 'Should get array ref for multiple options',
    );
    $builder->quiet(1);

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

    # Callback should trigger death for command-line options.
    throws_ok {
        $builder->get_reply(
            message  => "Hey who?",
            label    => "Hey who",
            name     => 'hey',
            default  => 'them',
            callback => sub { $_ eq 'you' },
        );
    } qr/"me" is not a valid value for --hey/,
        'We should get an error for a command-line option that fails the callback';

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

sub test_environ : Test(6) {
    my $self = shift;
    my $class = $self->test_class;

    my $kb = MockModule->new($class);
    $kb->mock( check_manifest         => 1 );
    $kb->mock( check_prereq           => 1 );
    $kb->mock( _check_build_component => 1 );

    ok my $builder = $self->new_builder, 'Create a new builder';

    # Check a coupla values.
    local $ENV{WOOT} = 'howdy';
    is $builder->_get_option(
        key => 'kinetic_root',
        environ => 'WOOT',
    ), $ENV{WOOT}, '_get_option() should get a value from the environment';

    # Make sure it hasn't come from somewhere else...
    $ENV{WOOT} = 'hlghlghlghlgh';
    is $builder->_get_option(
        key => 'kinetic_root',
        environ => 'WOOT',
    ), $ENV{WOOT}, '... and it should get a new value';

    # Try it with a callback.
    is $builder->_get_option(
        key => 'kinetic_root',
        environ => 'WOOT',
        callback => sub { /^hlgh/ },
    ), $ENV{WOOT}, '... and it should work with a callback';

    # Make sure that it get_reply() passes it.
    is $builder->get_reply(
        name => 'kinetic_root',
        environ => 'WOOT',
        callback => sub { /^hlgh/ },
    ), $ENV{WOOT}, '... and it should work via get_reply()';

    # And that the callback is passed, too, of course.
    throws_ok {
        $builder->get_reply(
            name     => 'kinetic_root',
            environ  => 'WOOT',
            callback => sub { /^hownow/ },
        );
    } qr/"$ENV{WOOT}" is not a valid value for the "WOOT" environment variable/,
        'And get_reply() should pass a failing callback';
}

sub try_reply {
    my ($self, $builder, %params) = @_;
    my $exp_msg   = delete $params{exp_message};
    my $exp_info  = delete $params{exp_info};
    my $exp_value = delete $params{exp_value};
    my $comment   = delete $params{comment};

    $self->{input} = ref $params{input_value}
      ? delete $params{input_value}
      : [ delete $params{input_value} ];

    my $reply = $builder->get_reply(%params);
    if (ref $exp_value) {
        is_deeply $reply, $exp_value, $comment;
    }
    else {
        is $reply, $exp_value, $comment;
    }


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
    return $self->{builder} = $class->new(
        dist_name       => 'Testing::Kinetic',
        dist_version    => '1.0',
        quiet           => 1,
        accept_defaults => 1,
        @_,
    );
}

package TEST::Kinetic::TestInfo;
sub new { bless {} };
sub version { 1 }

1;
__END__
