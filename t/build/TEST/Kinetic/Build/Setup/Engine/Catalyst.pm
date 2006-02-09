package TEST::Kinetic::Build::Setup::Engine::Catalyst;

# $Id$

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Setup::Engine';
use TEST::Kinetic::Build;
use Test::More;
use aliased 'Kinetic::Build';
use aliased 'Test::MockModule';

__PACKAGE__->runtests unless caller;

sub test_catalyst : Test(10) {
    my $self  = shift;
    my $class = $self->test_class;

    # Fake the Kinetic::Build interface.
    my $builder = MockModule->new(Build);
    $builder->mock(resume => sub { bless {}, Build });
    $builder->mock(_app_info_params => sub { } );

    ok my $catalyst = $class->new, "Create new $class object";
    isa_ok $catalyst, $class;
    isa_ok $catalyst, 'Kinetic::Build::Setup::Engine';
    isa_ok $catalyst, 'Kinetic::Build::Setup';
    isa_ok $catalyst->builder, 'Kinetic::Build';
    is $catalyst->info, undef, 'info() should be undef';
    is $catalyst->engine_class, 'Kinetic::Engine::Catalyst',
        'Engine class should be "Kinetic::Engine::Catalyst"';
    is $catalyst->conf_engine, 'catalyst', 'Conf engine should be "catalyst"';
    is_deeply [$catalyst->conf_sections], [qw(port host restart)],
        'Conf sections should be qw(port host restart)';
    ok $catalyst->rules, 'Rules should be defined';
}

sub test_rules : Test(20) {
    my $self  = shift;
    my $class = $self->test_class;

    # Override builder methods to keep things quiet.
    my $kb = MockModule->new(Build);
    $kb->mock( check_manifest  => sub {return} );
    $kb->mock( check_store     => 1 );
    $kb->mock(_prompt => sub { shift; $self->{output} .= join '', @_; });

    my $builder = $self->new_builder;
    $kb->mock( resume => $builder );
    $builder->{tty} = 1;

    # Construct the object.
    ok my $catalyst = $class->new($builder), "Create new $class object";
    isa_ok $catalyst, $class;
    is $catalyst->builder, $builder, 'Builder should be set';

    # Run the rules.
    ok $catalyst->validate, 'Run validate()';
    is $catalyst->port, 3000, 'Port should be 3000';
    is $catalyst->host, 'localhost', 'Host should be "localhost"';
    ok !$catalyst->restart, 'Restart should be false';
    is $self->{output}, undef,' There should have been no output';

    # Try it with prompts.
    $builder->accept_defaults(0);
    my @input = qw(4321 barhost y);
    $kb->mock(_readline => sub { shift @input });

    ok $catalyst->validate, 'Run validate() with prompts';
    is $catalyst->port, 4321, 'Port should be 4321';
    is $catalyst->host, 'barhost', 'Host should be "barhost"';
    ok $catalyst->restart, 'Restart should be true';
    is delete $self->{output}, join(
        q{},
        q{Please enter the port on which to run the Catalyst server [3000]: },
        q{Please enter the hostname on which the Catalyst server will run [localhost]: },
        q{Should the Catalyst server automatically restart if .pm files change? [n]: },
   ), 'Questions should be sent to output';

    # Try it with command-line arguments.
    local @ARGV = qw(
        --catalyst-host    foohost
        --catalyst-port    1234
        --catalyst-restart 1
    );
    $builder = $self->new_builder;
    $kb->mock( resume => $builder );

    ok $catalyst = $class->new($builder),
        "Create new $class object to read \@ARGV";
    is $catalyst->builder, $builder, 'Builder should be the new builder';

    # Run the rules.
    ok $catalyst->validate, 'Run validate()';
    is $catalyst->port, 1234, 'Port should be 1234';
    is $catalyst->host, 'foohost', 'Host should be "foohost"';
    ok $catalyst->restart, 'Restart should be true';
    is $self->{output}, undef,' There should have been no output';
}

1;
__END__
