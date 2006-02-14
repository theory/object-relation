package TEST::Kinetic::Build::Setup::Engine;

# $Id$

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Setup';
use TEST::Kinetic::Build;
use Test::More;
use aliased 'Kinetic::Build';
use aliased 'Test::MockModule';

__PACKAGE__->runtests unless caller;

sub test_interface : Test(7) {
    my $self = shift;
    my $class = $self->test_class;
    can_ok $class, qw(base_uri);

    # Fake the Kinetic::Build interface.
    my $builder = MockModule->new(Build);
    $builder->mock(resume => sub { bless {}, Build });
    $builder->mock(_app_info_params => sub { } );

    ok my $engine = $class->new(bless {}, Build),
        'Create new engine setup object';

    is $engine->base_uri, '/', 'Base URI should default to "/"';
    ok $engine->base_uri('/foo/'), 'Should be able to set the base URI';
    is $engine->base_uri, '/foo/', 'Base URI should be new value';

    # Test add_to_config.
    my $mocker = MockModule->new($class);
    $mocker->mock(conf_sections => sub { qw(foo bar)});
    $mocker->mock(engine_class => 'Engine::Class');
    $mocker->mock(conf_engine => 'catalyst');

    my %conf;
    $mocker->mock(foo => 'one');
    $mocker->mock(bar => 'two');
    ok $engine->add_to_config(\%conf), 'Add to config';
    is_deeply \%conf, {
        'catalyst' => {
            foo => 'one',
            bar => 'two',
        },
        engine => {
            class => 'Engine::Class',
        },
        kinetic => {
            base_uri => '/foo/',
        }
    }, 'Config should be properly set';
}

1;
__END__
