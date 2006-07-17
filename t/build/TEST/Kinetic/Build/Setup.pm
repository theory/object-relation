package TEST::Kinetic::Build::Setup;

# $Id$

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use aliased 'Test::MockModule';
use Test::Output;
use constant Build => 'Kinetic::Build';

__PACKAGE__->runtests unless caller;

sub test_class_interface : Test(4) {
    my $self  = shift;
    my $class = $self->test_class;
    return 'Subclass may override class methods'
        unless $class eq 'Kinetic::Build::Setup';

    throws_ok { $class->rules }
        qr/rules\(\) must be overridden in the subclass/,
        'rules() should die';
    is $class->info_class, undef, 'The info class should be undef';
    throws_ok { $class->min_version }
        qr/min_version\(\) must be overridden in the subclass/,
        'min_version() should die';
    is $class->max_version, 0, 'max_version() should return 0';
}

sub test_instance_interface : Test(39) {
    my $self    = shift;
    my $class   = $self->test_class;
    my $is_base = $class eq 'Kinetic::Build::Setup';

    can_ok $class, qw(
        new builder setup test_setup info_class info rules validate
        add_to_config add_to_test_config min_version max_version
        is_required_version resume test_cleanup
    );

    # Fake the Kinetic::Build interface.
    my $builder = MockModule->new(Build);
    $builder->mock(resume => sub { bless {}, Build });
    $builder->mock(_app_info_params => sub { } );

    ok my $setup = $class->new(bless {}, Build),
        'Create new setup object';
    isa_ok $setup, $class;
    isa_ok $setup->builder, 'Kinetic::Build', 'builder()';
    SKIP: {
        skip 'Subclass may suppy info object', 1, unless $is_base;
        is $setup->info, undef, 'info() should return undef';
    }

    my $mocker = MockModule->new($class);
    my $message = 'la la la';
    $setup->builder->verbose(1);
    $mocker->mock(rules => sub {
        Done => {
            do => sub {
                my $state = shift;
                $state->done(1);
                $state->message($message);
                ok 1, 'validate() should execute rules';
            }
        }
    });
    stdout_like {
        ok $setup->validate, 'validate() should work';
    } qr/$message\n/, 'Rule message should be output';
    $setup->builder->verbose(0);

    my $mock_info = MockModule->new(__PACKAGE__, no_auto => 1);
    $mock_info->mock(version => '2.2');
    $mocker->mock(min_version => '2.3');
    $mocker->mock(info => __PACKAGE__);
    ok !$setup->is_required_version, '2.2 !>= 2.3';
    $mocker->mock(min_version => '2.2');
    ok $setup->is_required_version, '2.2 >= 2.2';
    $mocker->mock(min_version => '2.1');
    ok $setup->is_required_version, '2.2 >= 2.1';
    $mocker->mock(max_version => '3.0');
    ok $setup->is_required_version, '2.2 >= 2.1 && 2.2 <= 3.0';
    $mock_info->mock(version => '3.0');
    ok $setup->is_required_version, '3.0 >= 2.1 && 3.0 <= 3.0';
    $mock_info->mock(version => '3.1');
    ok !$setup->is_required_version, '3.1 >= 2.1 && 3.1 !<= 3.0';

    # Check actions.
    is_deeply [$setup->actions], [], "There should be no actions";
    is $setup->add_actions('foo'), $setup, "We should be able to add an action";
    is_deeply [$setup->actions], ['foo'], "There should now be one action";
    is $setup->add_actions('bar', 'bat'), $setup,
      "We should be able to add multiple actions";
    is_deeply [$setup->actions], ['foo', 'bar', 'bat'],
      "There should now be three actions";
    is $setup->add_actions('foo'), $setup, "We can try adding an existing action";
    is_deeply [$setup->actions], ['foo', 'bar', 'bat'],
      "But it should make no difference";
    is $setup->del_actions('foo'), $setup,
      "We can try deleting an existing action";
    is_deeply [$setup->actions], ['bar', 'bat'],
      "And it should be gone";
    is $setup->del_actions('bat', 'bar'), $setup,
      "We should be able to delete multiple actions";
    is_deeply [$setup->actions], [], 'And now there should be no more actions';
    is $setup->add_actions('foo'), $setup,
      "We should be able to add a deleted one again";
    is_deeply [$setup->actions], ['foo'], "There should now be one action";
    is $setup->del_actions($setup->actions), $setup, "Clean out actions";

    SKIP: {
        skip 'Subclasses should test config, setup, and cleanup methods', 9
            unless $is_base;

        # Check config methods.
        is $setup->add_to_config, $setup,
            'add_to_config() should return setup';
        is $setup->add_to_test_config, $setup,
            'And add_to_test_config() should, too';

        $setup->add_actions(qw(max_version info_class));
        my $i = 0;
        my $meth = 'setup';
        $mocker->mock(max_version => sub {
            is ++$i, 1, "$meth() should have called max_version first";
        });
        $mocker->mock(info_class => sub {
            is ++$i, 2, "$meth() should have called info_class second";
        });
        ok $setup->setup, 'setup() should run';
        $i = 0;
        $meth = 'test_setup';
        ok $setup->test_setup, 'test_setup() should also just run';

        is $setup->test_cleanup, $setup, 'test_cleanup should just return';
    }

    # Check resume.
    my $build = $setup->builder;
    is $setup->resume($build), $setup,
        'resume() should return itself';
    is $setup->builder, $build, '... And now the builder should be back';
}

sub new_builder {
    my $self = shift;
    local $SIG{__DIE__} = sub {
        Kinetic::Store::Exception::ExternalLib->throw(shift);
    };
    return $self->{builder} = Build->new(
        dist_name       => 'Testing::Kinetic',
        dist_version    => '1.0',
        quiet           => 1,
        accept_defaults => 1,
        @_,
    )
}

1;
