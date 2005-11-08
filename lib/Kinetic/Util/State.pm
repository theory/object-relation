package Kinetic::Util::State;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with the
# Kinetic framework, to Kineticode, Inc., you confirm that you are the
# copyright holder for those contributions and you grant Kineticode, Inc.
# a nonexclusive, worldwide, irrevocable, royalty-free, perpetual license to
# use, copy, create derivative works based on those contributions, and
# sublicense and distribute those contributions and any derivatives thereof.

use strict;

use version;
our $VERSION = version->new('0.0.1');

use Kinetic::Util::Context;
use overload '""'     => \&name,
             '<=>'    => \&compare,
             'cmp'    => \&compare,
             'bool'   => \&is_active,
             '0+'     => \&value,
             fallback => 1;

=head1 Name

Kinetic::Util::State - Kinetic object states

=head1 Synopsis

Use class methods:

  use Kinetic::Util::State;

  if ($kinetic_obj->state->compare(Kinetic::Util::State->ACTIVE)) {
      $kinetic->obj->set_state(Kinetic::Util::State->ACTIVE);
  }

Or use constants:

  use Kinetic::Util::State qw(:all);

  if ($kinetic_obj->state->compare(ACTIVE)) {
      $kinetic->obj->set_state(ACTIVE);
  }

Comparison, boolean, and numification operations are overloaded:

  unless ($kinetic_obj->state == ACTIVE) {
      $kinetic->obj->set_state(ACTIVE);
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

This class defines Kinetic object states. There are five different states
for objects:

=over 4

=item C<PERMANENT>

Objects in this state are permanent and always visible, and can never be
deleted or purged. It will mainly be a few objects that ship with kinetic
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
permanently eliminating data from the data store. Furthermore, a Kinetic
object should not be purged lightly, since an RDBMS data store will likely
cascade delete all of its associations. For example, purging a type will
delete all objects based on that type. More commonly, deleting a document will
delete all data associated with the document, including all of its previous
versions.

=back

Kinetic::Util::State has constants with these names, which may be accessed
as either class methods or as exportable functions. The constants return
singleton Kinetic::Util::State objects that represent the various states.
These same objects are returned by the state attribute accessors of
Kinetic.

=cut

# The numbers are subject to change. Change them in t/01state.t, and Kinetic,
# too. Order is important here; the state numbers match their positions in the
# array--so don't change them unless the values change!

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

##############################################################################
# Instance Methods.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $state = Kinetic::Util::State->new($value);

Returns a Kinetic::Util::State object corresponding to the state value
passed to it.

=cut

sub new { return $states[ $_[1] ] }

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

Kinetic::Util::State overloads a number of Perl operators in order to ease
its use in various contexts. Each instance method overloads one or more
operations.

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

  # From a Kinetic object:
  if ($kinetic->state) {
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
Kinetic::Util::State objects.

=cut

sub name { Kinetic::Util::Context->language->maketext($_[0]->[1]) }

##############################################################################

1;
__END__

=head1 Copyright and License

Copyright (c) 2004-2005 Kineticode, Inc. <info@kineticode.com>

This work is made available under the terms of Version 2 of the GNU General
Public License. You should have received a copy of the GNU General Public
License along with this program; if not, download it from
L<http://www.gnu.org/licenses/gpl.txt> or write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

This work is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License Version 2 for more
details.

=cut
