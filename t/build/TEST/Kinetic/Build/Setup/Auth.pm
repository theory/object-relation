package TEST::Kinetic::Build::Setup::Auth;

# $Id$

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Setup';
use TEST::Kinetic::Build;
use Test::More;
use aliased 'Test::MockModule';
use Test::Exception;
use constant Build => 'Kinetic::Build';

__PACKAGE__->runtests unless caller;

sub test_instance_interface :Test(+0) {
    my $self  = shift;
    my $class  = $self->test_class;
    my $mocker = MockModule->new($class);

    $mocker->mock(authorization_class => 'Some::Class' );

    $self->SUPER::test_instance_interface(@_);
}

sub test_interface : Test(6) {
    my $self  = shift;
    my $class = $self->test_class;
    can_ok $class, qw(authorization_class expires add_to_config);

    if ($class eq 'Kinetic::Build::Setup::Auth') {
        throws_ok { $class->authorization_class }
            qr/authorization_class\(\) must be overridden in a subclass/,
            'authorization_class() should die';
    }
    else {
        ok $class->authorization_class,
            "$class->authorization_class should return a value";
    }

    # Fake the Kinetic::Build interface.
    my $builder = MockModule->new(Build);
    $builder->mock(resume => sub { bless {}, Build });
    $builder->mock(_app_info_params => sub { } );

    ok my $auth = $class->new(bless {}, Build),
        'Create new auth setup object';

    is $auth->expires, 3600, 'Expires should default to 3600';

    # Test add_to_config.
    my $mocker = MockModule->new($class);
    $mocker->mock(authorization_class => 'Some::Class' );

    my %conf;
    ok $auth->add_to_config(\%conf), 'Add to config';
    is_deeply \%conf, {
        auth => {
            class   => 'Some::Class',
            expires => 3600,
            $self->extra_conf,
        }
    }, 'Config should be properly set';
}

sub extra_conf {}

1;
__END__
