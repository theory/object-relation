package TEST::Kinetic::Build::Store;

use strict;
use warnings;
use base 'TEST::Class::Kinetic';
use Test::More;

__PACKAGE__->runtests;
sub test_interface : Test(17) {
    my $self = shift;
    my $class = $self->test_class;
    for my $method (qw'new builder build test_build info_class info rules
                       validate config test_config min_version max_version
                       schema_class is_required_version store_class
                       serializable resume',
                    @_) {
        can_ok $class, $method;
    }
}

1;
__END__
