package TEST::Kinetic::Build::Store;

use strict;
use warnings;
use base 'TEST::Class::Kinetic';
use Test::More;

sub test_interface : Test(13) {
    my $self = shift;
    my $class = $self->test_class;
    for my $method (qw(new builder build do_actions info_class info rules
                       validate config test_config min_version max_version
                       schema_class),
                    @_) {
        can_ok $class, $method;
    }
}

1;
__END__
