package TEST::Kinetic::Build::Setup::Store;

# $Id$

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Setup';
use TEST::Kinetic::Build;
use Test::More;
use Test::Exception;
use aliased 'Test::MockModule';

__PACKAGE__->runtests unless caller;

sub teardown_builder : Test(teardown) {
    my $self = shift;
    if (my $builder = delete $self->{builder}) {
        $builder->dispatch('realclean');
    }
}

sub test_schema_store_meths : Test(3) {
    my $self = shift;
    my $class = $self->test_class;
    can_ok $class, qw(schema_class store_class);
    (my $store_class = $class) =~ s/Build::Setup:://;
    is $class->store_class, $store_class, 'Store class should be correct';
    (my $schema_class = $class) =~ s/Build::Setup::Store/Store::Schema/;
    is $class->schema_class, $schema_class, 'Schema class should be correct';
}

1;
__END__
