package Kinetic::Priority;

# $Id$

use strict;
use Kinetic::Context;
use overload '""'     => \&name,
             '<=>'    => \&compare,
             'cmp'    => \&compare,
             'bool'   => \&value,
             '0+'     => \&value,
             fallback => 1;

=head1 Name

Kinetic::Priority - Kinetic priority objects

=head1 Synopsis

Use class methods:

  use Kinetic::Priority;

  if ($kinetic_obj->priority->compare(Kinetic::Priority->MEDIUM_PRIORITY)) {
      $kinetic->obj->set_priority(Kinetic::Priority->MEDIUM_PRIORITY);
  }

Or use constants:

  use Kinetic::Priority qw(:all);

  if ($kinetic_obj->priority->compare(MEDIUM_PRIORITY)) {
      $kinetic->obj->set_priority(MEDIUM_PRIORITY);
  }

Comparison, boolean, and numification operations are overloaded:

  unless ($kinetic_obj->priority == MEDIUM_PRIORITY) {
      $kinetic->obj->set_priority(MEDIUM_PRIORITY);
  }

  if ($priority < MEDIUM_PRIORITY) {
      print "This object is not active\n";
  }

  unless ($priority) {
      print "This object is not active\n";
  }

  my $priority_val = int $priority;

Stringification works, too.

  print "The priority is $priority"; # Prints "The priority is Normal".

=head1 Description

This class defines Kinetic workflow object priorities. There are five
different priorities:

=over 4

=item C<LOW_PRIORITY>

=item C<LOWEST_PRIORITY>

=item C<MEDIUM_PRIORITY>

=item C<HIGH_PRIORITY>

=item C<HIGHEST_PRIORITY>

=back

Kinetic::Priority has constants with these names, which may be
accessed as either class methods or as exportable functions. The constants
return singleton Kinetic::Priority objects that represent the various
priorities. These same objects are returned by the priority attribute
accessors of Kinetic::Decorator::Workflowable objects.

=cut

# XXX The numbers are subject to change. Change them in t/01priority.t, too.
my @priorities = (
    bless( [ 0, 'Lowest'  ] ),
    bless( [ 1, 'Low'     ] ),
    bless( [ 2, 'Normal'  ] ),
    bless( [ 3, 'High'    ] ),
    bless( [ 4, 'Highest' ] ),
);

sub LOWEST_PRIORITY  () { return $priorities[0]  }
sub LOW_PRIORITY     () { return $priorities[1]  }
sub MEDIUM_PRIORITY  () { return $priorities[2]  }
sub HIGH_PRIORITY    () { return $priorities[3]  }
sub HIGHEST_PRIORITY () { return $priorities[4]  }

use Exporter::Tidy all => [qw(LOWEST_PRIORITY LOW_PRIORITY MEDIUM_PRIORITY
                              HIGH_PRIORITY HIGHEST_PRIORITY)];

##############################################################################
# Instance Methods.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $priority = Kinetic::Priority->new($value);

Returns a Kinetic::Priority object corresponding to the priority value
passed to it.

=cut

sub new { return $priorities[ $_[1] ] }

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

Kinetic::Priority overloads a number of Perl operators in order to
ease its use in various contexts. Each instance method overloads one or more
operations.

=head3 value

  my $value = $priority->value;

  # Or...
  if ($priority) {
      print "Priority isn't lowest!\n";
  }

  # Or...
  my $value = int $priority;

Returns the numeric value of the priority. This is the value that is stored in
the data store. This method overrides the boolean context (C<bool>) of
priority objects. It also overrides operations performed upon a priority
object in a numeric context. Such contexts include:

=over 4

=item *

Where used with a built-in operator that expects a number (e.g.,
C<int($priority)>, C<substr($string, $priority)>, or C<print "#" x $priority>).

=item *

Where used as an operand for the range operator (e.g., C<for (1..$priority)>).

=item *

Where used as an array entry index (e.g., C<$priorities[$priority]>).

=back

=cut

sub value { $_[0]->[0] }

##############################################################################

=head3 compare

  if ($priority->compare($other_priority) {
      print "Priorities are not equal\n";
  }

  if ($priority->compare($other_priority) > 0) {
      print "$priority is greater than $other_priority\n";
  }

  if ($priority->compare($other_priority) < 0) {
      print "$priority is less than $other_priority\n";
  }

  # Or...
  if ($priority == $other_priority) {
      # ...
  }

  if ($priority > $other_priority) {
      # ...
  }

  if ($priority < $other_priority) {
      # ...
  }

Compares the priority object to another priority object and returns -1 if the priority
object is less than the other priority object, returns 0 if they're equal, and
returns 1 if the priority object is greater than the other priority object. This
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

  print "The priority is ", $priority->name;

  # Or...
  print "The priority is $priority";

Outputs a localized string representation of the name of the priority
object. This method overloads the double-quoted string context (C<""> for
Kinetic::Priority objects.

=cut

sub name { Kinetic::Context->language->maketext($_[0]->[1]) }

##############################################################################

1;
__END__

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item L<Kinetic::Base|Kinetic::Base>

The Kinetic base class. All Kinetic classes that store data in the data store
inherit from this class.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This Library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
