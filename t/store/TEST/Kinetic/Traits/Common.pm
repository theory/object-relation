package TEST::Kinetic::Traits::Common;

#use Class::Trait 'base';

use strict;
use warnings;

# note that the following is a stop-gap measure until Class::Trait has
# a couple of bugs fixed.  Bugs have been reported back to the author.
#
# Traits would be useful here as the REST and REST::Dispatch classes are
# coupled, but not by inheritance.  The tests need to share functionality
# but since inheritance is not an option, I will be importing these methods
# directly into the required namespaces.

use Exporter::Tidy default => [ qw/ desired_attributes / ];

sub desired_attributes {
    my $test = shift;
    unless (@_) {
        return wantarray ? @{$test->{attributes}} : $test->{attributes};
    }
    $test->{attributes} = shift;
    return $test;
}

1;
