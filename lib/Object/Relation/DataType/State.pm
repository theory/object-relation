package Object::Relation::DataType::State;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use aliased 'Object::Relation::Language';
use Object::Relation::Meta::Type;
use overload
    '""'     => \&name,
    '<=>'    => \&compare,
    'cmp'    => \&compare,
    'bool'   => \&is_active,
    '0+'     => \&value,
    fallback => 1;

=head1 Name

Object::Relation::DataType::State - Object::Relation object states

=head1 Synopsis

Use class methods:

  use Object::Relation::DataType::State;

  if ($obj_rel_obj->state->compare(Object::Relation::DataType::State->ACTIVE)) {
      $obj_rel->obj->set_state(Object::Relation::DataType::State->ACTIVE);
  }

Or use constants:

  use Object::Relation::DataType::State qw(:all);

  if ($obj_rel_obj->state->compare(ACTIVE)) {
      $obj_rel->obj->set_state(ACTIVE);
  }

Comparison, boolean, and numification operations are overloaded:

  unless ($obj_rel_obj->state == ACTIVE) {
      $obj_rel->obj->set_state(ACTIVE);
  }

  if ($state < ACTIVE) {
      print "This object is not active\n";
  }

  unless ($state) {
      print "This object is not active\n";
  }

  my $state_val = int $state;

Stringification works, too.

  print "The state is $state"; # Prints "The state is Active".

=head1 Description

This module creates the "state" data type for use in Object::Relation attributes. This
class defines Object::Relation object states. There are five different states for
objects:

=over 4

=item C<PERMANENT>

Objects in this state are permanent and always visible, and can never be
deleted or purged. It will mainly be a few objects that ship with obj_rel
that will be permanent.

=item C<ACTIVE>

Active objects are visible in the UI, and uniqueness checks for them will
be enforced.

=item C<INACTIVE>

Inactive objects are visible in the UI, and uniqueness checks for them will be
enforced, but they will cannot be used in any other context, including
publishing or the creation of associations with other objects.

=item C<DELETED>

Deleted objects are no longer visible in the UI, and can only be instantiated
by looking them up via the API by calling C<lookup()> with the appropriate
arguments. Any uniqueness checks will not be affected by DELETED objects.
Deleted objects cannot be undeleted; their deletion should be considered
permanent.

=item C<PURGED>

Purged objects are objects that are permanently purged from the data store. As
such, they will only exist as objects until C<save()> is called and any
references to the object exist in memory. An object should only be purged in
extreme circumstances, such as when some sort of legal motivation compels
permanently eliminating data from the data store. Furthermore, a Object::Relation
object should not be purged lightly, since an RDBMS data store will likely
cascade delete all of its associations. For example, purging a type will
delete all objects based on that type. More commonly, deleting a document will
delete all data associated with the document, including all of its previous
versions.

=back

Object::Relation::DataType::State has constants with these names, which may be
accessed as either class methods or as exportable functions. The constants
return singleton Object::Relation::DataType::State objects that represent the
various states. These same objects are returned by the state attribute
accessors of Object::Relation.

=cut

# The numbers are subject to change. Change them in t/01state.t, and
# Object::Relation::Base, too. Order is important here; the state numbers match
# their positions in the array--so don't change them unless the values change!

my @states = (
    bless( [ 0,  'Inactive'  ] ),
    bless( [ 1,  'Active'    ] ),
    bless( [ 2,  'Permanent' ] ),
    bless( [ -2, 'Purged'    ] ),
    bless( [ -1, 'Deleted'   ] ),
);

sub PERMANENT () { return $states[2]  }
sub ACTIVE    () { return $states[1]  }
sub INACTIVE  () { return $states[0]  }
sub DELETED   () { return $states[-1] }
sub PURGED    () { return $states[-2] }

use Exporter::Tidy all => [qw(PERMANENT ACTIVE INACTIVE DELETED PURGED)];

Object::Relation::Meta::Type->add(
    key     => 'state',
    name    => 'State',
    raw     => sub { ref $_[0] ? shift->value : shift },
    bake    => sub { __PACKAGE__->new(shift) },
    check   => sub {
        UNIVERSAL::isa($_[0], __PACKAGE__)
            or throw_invalid(['Value "[_1]" is not a valid [_2] object',
                              $_[0], __PACKAGE__]);
        throw_invalid(['Cannot assign permanent state'])
          if $_[0] == PERMANENT;
    }
);

##############################################################################
# Instance Methods.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $state = Object::Relation::DataType::State->new($value);

Returns a Object::Relation::DataType::State object corresponding to the state
value passed to it.

=cut

sub new { return $states[ $_[1] ] }

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

Object::Relation::DataType::State overloads a number of Perl operators in order
to ease its use in various contexts. Each instance method overloads one or
more operations.

=head3 value

  my $value = $state->value;

  # Or...
  my $value = int $state;

Returns the numeric value of the state. This is the value that is stored in
the data store. This method overrides operations performed upon a state object
in a numeric context. Such contexts include:

=over 4

=item *

Where used with a built-in operator that expects a number (e.g.,
C<int($state)>, C<substr($string, $state)>, or C<print "#" x $state>).

=item *

Where used as an operand for the range operator (e.g., C<for (1..$state)>).

=item *

Where used as an array entry index (e.g., C<$states[$state]>).

=back

=cut

sub value { $_[0]->[0] }

##############################################################################

=head3 is_active

  if ($state->is_active) {
      # ...
  }

  # Or...
  if ($state) {
      # ...
  }

  # From a Object::Relation object:
  if ($obj_rel->state) {
      # ...
  }

This method returns a true value if the state object is active or permanent.
We expect that checking such a state will be a common occurence; therefore,
this method overrides boolean operations (C<bool> on the state object itself.

=cut

sub is_active { $_[0]->[0] > 0 }

##############################################################################

=head3 compare

  if ($state->compare($other_state) {
      print "States are not equal\n";
  }

  if ($state->compare($other_state) > 0) {
      print "$state is greater than $other_state\n";
  }

  if ($state->compare($other_state) < 0) {
      print "$state is less than $other_state\n";
  }

  # Or...
  if ($state == $other_state) {
      # ...
  }

  if ($state > $other_state) {
      # ...
  }

  if ($state < $other_state) {
      # ...
  }

Compares the state object to another state object and returns -1 if the state
object is less than the other state object, returns 0 if they're equal, and
returns 1 if the state object is greater than the other state object. This
behavior allows the method to override the following operators:

=over 4

=item C<< < >>

=item C<< > >>

=item C<< <= >>

=item C<< >= >>

=item C<==>

=item C<!=>

=item C<< <=> >>

=item C<lt>

=item C<gt>

=item C<le>

=item C<ge>

=item C<eq>

=item C<ne>

=item C<cmp>

=back

=cut

sub compare { $_[0]->[0] <=> $_[1]->[0] }

##############################################################################

=head3 name

  print "The state is ", $state->name;

  # Or...
  print "The state is $state";

Outputs a localized string representation the name of the state object. This
method overloads the double-quoted string context (C<""> for
Object::Relation::DataType::State objects.

=cut

sub name { Language->get_handle->maketext($_[0]->[1]) }

##############################################################################

1;
__END__

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@obj_relode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
