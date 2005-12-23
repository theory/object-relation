package TEST::Kinetic::Party::Person;

# $Id$

use strict;
use warnings;

use base 'TEST::Kinetic::Party';
use Test::More;

sub class_key { 'person' }

sub test_name : Test(no_plan) {
    my $self = shift;
}

1;
__END__
