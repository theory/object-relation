package Kinetic::Util::Constants;

# $Id: Constants.pm 1818 2005-06-29 03:35:14Z curtis $

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

=head1 Name

Kinetic::Util::Constants - The Kinetic constants class

=head1 Synopsis

  use Kinetic::Util::Contants qw/:data_store/;
  if ($name =~ /GROUP_OP/) {
    ...
  }

=head1 Description

This class is a centralized place for Kinetic constants that are not
configuration specific.

=cut

# data_store
use constant GROUP_OP         => qr/^(?:AND|OR)$/;
use constant OBJECT_DELIMITER => '__';
use constant ATTR_DELIMITER   => '.';
use constant PREPARE          => 'prepare';
use constant CACHED           => 'prepare_cached';
use constant GUID_RE          => 
    qr/[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}/;

# HTTP content types
use constant TEXT_CT => 'text/plain';
use constant XML_CT  => 'text/xml';
use constant HTML_CT => 'text/html';

# HTTP status codes
use constant OK_STATUS                    => '200 OK';
use constant INTERNAL_SERVER_ERROR_STATUS => '500 Internal Server Error';
use constant NOT_IMPLEMENTED_STATUS       => '501 Not Implemented';

use Exporter::Tidy
    http       => [qw/
        HTML_CT
        TEXT_CT
        XML_CT

        OK_STATUS
        INTERNAL_SERVER_ERROR_STATUS
        NOT_IMPLEMENTED_STATUS
    /],
    data_store => [qw/
        ATTR_DELIMITER
        CACHED 
        GROUP_OP 
        GUID_RE
        OBJECT_DELIMITER 
        PREPARE 
    /];

=head1 :data_store

These constants all relate to the data store and data various data store
modules need to manipulate it.

=over 4

=item * ATTR_DELIMITER

In the Kinetic objects, contained object attributes are frequently referred
to by C<$key . $delimiter . $attribute_name>.  Thus, an object with a key of
I<customer> and an attribute named "last_name" might be referred to as
I<customer.last_name>.  The C<ATTR_DELIMITER> should be the C<$delimeter>.

=item * CACHED

This resolves to C<prepare_cached>:  the name of the L<DBI|DBI> method used to
prepare and cache an SQL statement.

=item * GROUP_OP

A regular expression matching search grouping operators 'AND' and 'OR'.

=item * GUID_RE

All objects in a data store have a GUID.  This regular expression matches
GUIDs.  Assumes all letters are upper case.

=item * OBJECT_DELIMITER

In the data store, contained object fields are usually the
L<Kinetic::Meta|Kinetic::Meta> key, followed by the object delimeter and the
name of the actual field.  Thus, if asking for a C<first_name> field in an
object in a K:M class with the key C<customer> and the object delimeter is
C<__>, the resulting field would be C<customer__first_name>.

=item * PREPARE

This resolves to C<prepare>:  the name of the L<DBI|DBI> method used to prepare
an SQL statement.

=back

=head1 HTTP

HTTP related constants.  These are content types or status codes.

=head2 Content types

Used with HTTP C<Content-type:> header.

=over 4

=item * HTML_CT

C<text/html>

=item * TEXT_CT

C<text/plain>

=item * XML_CT

C<text/xml>

=back

=head2 Status codes

Use with HTTP C<Status:> header.

=over 4

=item * INTERNAL_SERVER_ERROR_STATUS

C<500 Internal Server Error>

=item * NOT_IMPLEMENTED_STATUS

C<501 Not Implemented>

=item * OK_STATUS

C<200 OK>

=back

=cut

1;
__END__

##############################################################################

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
