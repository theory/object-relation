package Kinetic::Util::Constants;

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
our $VERSION = version->new('0.0.2');

=head1 Name

Kinetic::Util::Constants - The Kinetic constants class

=head1 Synopsis

  use Kinetic::Util::Contants qw/:data_store/;
  if ($name =~ /$GROUP_OP/) {
    ...
  }

=head1 Description

This class is a centralized place for Kinetic constants that are not
configuration specific.

=cut

use Readonly;
use File::Spec;

# data_store
Readonly our $GROUP_OP         => qr/^(?:AND|OR)$/;
Readonly our $OBJECT_DELIMITER => '__';
Readonly our $ATTR_DELIMITER   => '.';
Readonly our $PREPARE          => 'prepare';
Readonly our $CACHED           => 'prepare_cached';
Readonly our $UUID_RE          =>
  qr/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/;

# class exclusion
SCOPE: {
    my $sep = File::Spec->catdir('');
    Readonly our $CLASS_EXCLUDE_RE =>
        qr/Kinetic$sep(?:(?:App)?Build|DataType|Format|Meta|Store|Util)/;
}

# Format
Readonly our $KEY => 'Key';

use Exporter::Tidy
  data_store => [
    qw/
      $ATTR_DELIMITER
      $CACHED
      $GROUP_OP
      $UUID_RE
      $OBJECT_DELIMITER
      $PREPARE
      /
  ],
  class_exclude => [
    qw/$CLASS_EXCLUDE_RE/
  ],
  format => [
    qw/$KEY/
  ],
  labels => [
    qw/
      $AVAILABLE_INSTANCES
      $AVAILABLE_RESOURCES
      /
  ],
;

=head2 :data_store

These constants all relate to the data store and data various data store
modules need to manipulate it.

=over 4

=item * $ATTR_DELIMITER

In the Kinetic objects, contained object attributes are frequently referred
to by C<$key . $delimiter . $attribute_name>.  Thus, an object with a key of
I<customer> and an attribute named "last_name" might be referred to as
I<customer.last_name>.  The C<$ATTR_DELIMITER> should be the C<$delimiter>.

=item * $CACHED

This resolves to C<prepare_cached>:  the name of the L<DBI|DBI> method used to
prepare and cache an SQL statement.

=item * $GROUP_OP

A regular expression matching search grouping operators 'AND' and 'OR'.

=item * $UUID_RE

All objects in a data store have a UUID.  This regular expression matches
UUIDs.  Assumes all letters are upper case.

=item * $OBJECT_DELIMITER

In the data store, contained object fields are usually the
L<Kinetic::Meta|Kinetic::Meta> key, followed by the object delimiter and the
name of the actual field.  Thus, if asking for a C<first_name> field in an
object in a K:M class with the key C<customer> and the object delimiter is
C<__>, the resulting field would be C<customer__first_name>.

=item * $PREPARE

This resolves to C<prepare>:  the name of the L<DBI|DBI> method used to prepare
an SQL statement.

=back

=head2 :format

L<Kinetic::Format|Kinetic::Format> related constants.

=over 4

=item * $KEY

The identifier for the class key used in formats. Important because it must
not conflict with attributes names and must be an allowable key for JSON and
XML.

=back

=cut

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

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
