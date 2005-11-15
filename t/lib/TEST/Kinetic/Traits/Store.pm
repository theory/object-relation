package TEST::Kinetic::Traits::Store;

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

use aliased 'Test::MockModule';
use Exporter::Tidy default => [
    qw/
      create_test_objects
      desired_attributes
      force_inflation
      mock_dbh
      test_objects
      unmock_dbh
      /
];

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';

my $debugging = 0;

sub mock_dbh {
    my $test = shift;
    my $store = Kinetic::Store->new;
    $test->{dbh} = $store->_dbh;
    unless ($debugging) { # give us an easy debugging hook
        $test->{dbh}->begin_work;
        $test->{dbi_mock} = MockModule->new('DBI::db', no_auto => 1);
        $test->{dbi_mock}->mock(begin_work => 1);
        $test->{dbi_mock}->mock(commit => 1);
        $test->{db_mock} = MockModule->new('Kinetic::Store::DB');
        $test->{db_mock}->mock(_dbh => $test->{dbh});
    }
}

sub unmock_dbh {
    my $test = shift;
    if ($debugging) {
        $test->{dbh}->commit;
    }
    else {
        delete( $test->{dbi_mock} )->unmock_all;
        $test->{dbh}->rollback unless $test->{dbh}->{AutoCommit};
        delete( $test->{db_mock} )->unmock_all;
    }
}

sub create_test_objects {
    my $test = shift;
    my $foo = One->new;
    $foo->name('foo');
    $foo->save;
    my $bar = One->new;
    $bar->name('bar');
    $bar->save;
    my $baz = One->new;
    $baz->name('snorfleglitz');
    $baz->save;
    $test->test_objects([$foo, $bar, $baz]);
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

##############################################################################

=head3 desired_attributes

  $test->desired_attributes(\@attribute_names);
  my @objects = $test->desired_attributes;

Simple getter/setter for attributes desired from objects.  If called in scalar
context, returns an array ref of attribute names.  Otherwise, returns a list of
them.
  
This method is called by several other trait methods which need to know which
attributes from which to pull data from objects.

=cut

sub desired_attributes {
    my $test = shift;
    unless (@_) {
        return wantarray ? @{ $test->{attributes} } : $test->{attributes};
    }
    $test->{attributes} = shift;
    return $test;
}

##############################################################################

=head3 force_inflation

  $object = $test->force_inflation($object);

This method is used by classes to force the inflation of values of Kinetic
objects when tested with is_deeply and friends.

=cut

sub force_inflation {
    my ( $test, $object ) = @_;
    return unless $object;
    no warnings 'void';
    foreach my $attr ( $object->my_class->attributes ) {
        if ( $attr->references ) {
            $test->force_inflation( $attr->get($object) );
        }
        else {
            my $name = $attr->name;
            $object->$name;    # this is what forces inflation
        }
    }
    return $object;
}

1;
