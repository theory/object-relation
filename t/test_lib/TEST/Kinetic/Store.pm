package TEST::Kinetic::Store;

# $Id: SQLite.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;

use aliased 'Test::MockModule';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Store' => 'Store';

__PACKAGE__->runtests;

sub test_new : Test(4) {
    my $test = shift;
    (my $class = ref $test) =~ s/^TEST:://;
    can_ok $class => 'new';
    ok my $store = $class->new;
    isa_ok $store, $class;
    isa_ok $store, 'Kinetic::Store';
}

sub test_save : Test(3) {
    my $test = shift;
    (my $class = ref $test) =~ s/^TEST:://;
    return "Kinetic::Store is an abstract class" if $class eq 'Kinetic::Store';
    can_ok $class, 'save';
    # XXX We should add code here to actually test it, to make sure that all
    # stores behave in the same way.
}

1;
