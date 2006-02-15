package TEST::Kinetic::Build::Setup::Cache;

# $Id$

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Setup';
use TEST::Kinetic::Build;
use Test::More;
use aliased 'Kinetic::Build';
use aliased 'Test::MockModule';
use Test::Exception;

__PACKAGE__->runtests unless caller;

sub test_instance_interface :Test(+0) {
    my $self  = shift;
    my $class  = $self->test_class;
    my $mocker = MockModule->new($class);

    $mocker->mock(catalyst_cache_class => 'Some::Class' );
    $mocker->mock(object_cache_class   => 'Another::Class' );

    $self->SUPER::test_instance_interface(@_);
}

sub test_interface : Test(7) {
    my $self  = shift;
    my $class = $self->test_class;
    can_ok $class, qw(catalyst_cache_class object_cache_class expires
                      add_to_config);

    if ($class eq 'Kinetic::Build::Setup::Cache') {
        throws_ok { $class-> catalyst_cache_class }
            qr/catalyst_cache_class\(\) must be overridden in a subclass/,
            'catalyst_cache_class() should die';
        throws_ok { $class-> object_cache_class }
            qr/object_cache_class\(\) must be overridden in a subclass/,
            'object_cache_class() should die';
    }
    else {
        ok $class->catalyst_cache_class,
            "$class->catalyst_cache_class should return a value";
        ok $class->object_cache_class,
            "$class->object_cache_class should return a value";
    }

    # Fake the Kinetic::Build interface.
    my $builder = MockModule->new(Build);
    $builder->mock(resume => sub { bless {}, Build });
    $builder->mock(_app_info_params => sub { } );

    ok my $cache = $class->new(bless {}, Build),
        'Create new cache setup object';

    is $cache->expires, 3600, 'Expires should default to 3600';

    # Test add_to_config.
    my $mocker = MockModule->new($class);
    $mocker->mock(catalyst_cache_class => 'Some::Class' );
    $mocker->mock(object_cache_class   => 'Another::Class' );

    my %conf;
    ok $cache->add_to_config(\%conf), 'Add to config';
    is_deeply \%conf, {
        cache => {
            catalyst_class => 'Some::Class',
            object_class   => 'Another::Class',
            expires        => 3600,
            $self->extra_conf,
        }
    }, 'Config should be properly set';
}

sub extra_conf {}

1;
__END__
