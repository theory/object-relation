package TEST::Kinetic::Traits::SampleObjects;

use strict;
use warnings;

use Class::Trait 'base';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';

##############################################################################

=head3 create_test_objects

  $test->create_test_objects;

Creates three test objects of the C<TestApp::Simple::One> class and saves them
to the data store.  Sets their names to 'foo', 'bar' and 'snorfleglitz'.  Not
other attributes are set.

=cut

sub create_test_objects {
    my $test = shift;
    my $foo  = One->new;
    $foo->name('foo');
    $foo->save;
    my $bar = One->new;
    $bar->name('bar');
    $bar->save;
    my $baz = One->new;
    $baz->name('snorfleglitz');
    $baz->save;
    $test->test_objects( [ $foo, $bar, $baz ] );
}

##############################################################################

=head3 test_objects

  $test->test_objects(\@objects);
  my @objects = $test->test_objects;

Simple getter/setter for test objects.  If called in scalar context, returns
an array ref of objects.  Otherwise, returns a list of objects.

May be passed a list of objects or a single object:

 $test->test_objects($foo);

=cut

sub test_objects {
    my $test = shift;
    unless (@_) {
        return wantarray ? @{ $test->{test_objects} } : $test->{test_objects};
    }
    my $objects = shift;
    $objects = [$objects] unless 'ARRAY' eq ref $objects;
    $test->{test_objects} = $objects;
    $test;
}

1;
__END__
