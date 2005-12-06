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

use version;
our $VERSION = version->new('0.0.1');

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

# data_store
Readonly our $GROUP_OP         => qr/^(?:AND|OR)$/;
Readonly our $OBJECT_DELIMITER => '__';
Readonly our $ATTR_DELIMITER   => '.';
Readonly our $PREPARE          => 'prepare';
Readonly our $CACHED           => 'prepare_cached';
Readonly our $UUID_RE          =>
  qr/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/;

# HTTP content types
Readonly our $TEXT_CT => 'text/plain';
Readonly our $XML_CT  => 'text/xml';
Readonly our $HTML_CT => 'text/html';

# HTTP status codes
Readonly our $HTTP_OK                    => '200 OK';
Readonly our $HTTP_INTERNAL_SERVER_ERROR => '500 Internal Server Error';
Readonly our $HTTP_NOT_IMPLEMENTED       => '501 Not Implemented';
Readonly our $HTTP_NOT_FOUND             => '404 Not Found';
Readonly our $HTTP_BAD_REQUEST           => '400 Bad Request';

# XSLT
Readonly our $CURRENT_PAGE   => '#';
Readonly our $RESOURCES_XSLT => '/xslt/resources.xsl';
Readonly our $SEARCH_XSLT    => '/xslt/search.xsl';
Readonly our $INSTANCE_XSLT  => '/xslt/instance.xsl';

# REST
Readonly our $CLASS_KEY_PARAM => '_class_key';
Readonly our $DOMAIN_PARAM    => '_domain';
Readonly our $PATH_PARAM      => '_path';
Readonly our $TYPE_PARAM      => '_type';
Readonly our $LIMIT_PARAM     => '_limit';
Readonly our $OFFSET_PARAM    => '_offset';
Readonly our $ORDER_BY_PARAM  => '_order_by';
Readonly our $SORT_PARAM      => '_sort_order';
Readonly our $SEARCH_TYPE     => 'STRING';

# Labels
Readonly our $AVAILABLE_INSTANCES => 'Available instances';
Readonly our $AVAILABLE_RESOURCES => 'Available resources';

# Format
Readonly our $KEY => 'Key';

# Directories
Readonly our $WWW_DIR => './www';

use Exporter::Tidy http => [
    qw/
      $HTML_CT
      $TEXT_CT
      $XML_CT

      $HTTP_OK
      $HTTP_INTERNAL_SERVER_ERROR
      $HTTP_NOT_IMPLEMENTED
      $HTTP_NOT_FOUND
      $HTTP_BAD_REQUEST
      /
  ],
  data => [
    qw/
      $WWW_DIR
      /
  ],
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
  format => [
    qw/$KEY/
  ],
  rest => [
    qw/
      $CLASS_KEY_PARAM
      $DOMAIN_PARAM
      $PATH_PARAM
      $TYPE_PARAM
      $LIMIT_PARAM
      $OFFSET_PARAM
      $ORDER_BY_PARAM
      $SORT_PARAM
      $SEARCH_TYPE
      /
  ],
  labels => [
    qw/
      $AVAILABLE_INSTANCES
      $AVAILABLE_RESOURCES
      /
  ],
  xslt => [
    qw/
      $CURRENT_PAGE
      $RESOURCES_XSLT
      $SEARCH_XSLT
      $INSTANCE_XSLT
      /
  ];

=head2 :data_store

These constants all relate to the data store and data various data store
modules need to manipulate it.

=over 4

=item * $ATTR_DELIMITER

In the Kinetic objects, contained object attributes are frequently referred
to by C<$key . $delimiter . $attribute_name>.  Thus, an object with a key of
I<customer> and an attribute named "last_name" might be referred to as
I<customer.last_name>.  The C<$ATTR_DELIMITER> should be the C<$delimeter>.

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
L<Kinetic::Meta|Kinetic::Meta> key, followed by the object delimeter and the
name of the actual field.  Thus, if asking for a C<first_name> field in an
object in a K:M class with the key C<customer> and the object delimeter is
C<__>, the resulting field would be C<customer__first_name>.

=item * $PREPARE

This resolves to C<prepare>:  the name of the L<DBI|DBI> method used to prepare
an SQL statement.

=back

=head2 :format

L<Kinetic::Format|Kinetic::Format> related constants.

=over 4

=item * $KEY

The identifier for the class key used in formats.  Important because it must
not conflict with attributes names and must be an allowable key for JSON and
XML.

=back

=head2 :rest

These constants are related to the REST interface.

=over 4

=item * $CLASS_KEY_PARAM

C<class_key> for current search.

=item * $DOMAIN_PARAM

Domain of server.

=item * $PATH_PARAM

REST base path.

=item * $TYPE_PARAM

Content type to return to client instead of XML.  Currently only supports
'html'.

=item * $LIMIT_PARAM

Parameter specifying the maximum number of items to return from a search.

=item * $OFFSET_PARAM

Parameter specifying how which item in a search to start limiting results
from.

=item * $ORDER_BY_PARAM

Parameter specifying which attributes to order search results by.

=item * $SORT_PARAM

Parameter specifying which direction to sort an C<$ORDER_BY_PARAM> on.  Allowed
values are C<ASC> and C<DESC>.

=item * $SEARCH_TYPE

The type of search requested via the REST interface.

=back

=head2 :http

HTTP related constants.  These are content types or status codes.

=head2 Content types

Used with HTTP C<Content-type:> header.

=over 4

=item * $HTML_CT

C<text/html>

=item * $TEXT_CT

C<text/plain>

=item * $XML_CT

C<text/xml>

=back

=head2 Status codes

Use with HTTP C<Status:> header.

=over 4

=item * $HTTP_INTERNAL_SERVER_ERROR

C<500 Internal Server Error>

=item * $HTTP_NOT_IMPLEMENTED

C<501 Not Implemented>

=item * $HTTP_NOT_FOUND

C<404 Not Found>

=item * $HTTP_BAD_REQUEST

C<400 Bad Request>

=item * $HTTP_OK

C<200 OK>

=back

=head2 :labels

=over 4 

=item * $AVAILABLE_INSTANCES

Title for "Available instances" returned in REST services.

=item * $AVAILABLE_RESOURCES

Title for "Available resources" returned in REST services.

=back

=head2 :data

=over 4

=item * $WWW_DIR

The location of the WWW directory.

=back

=head2 :xslt

=over 4

=item * $CURRENT_PAGE

This is a marker used in XML documents to indicate a link to the current page.
Usually such a link is not desired and XSLT should not make a link if it finds
a C<$CURRENT_PAGE> marker.

=item * $RESOURCES_XSLT

Location of XSLT for listing available resources (Kinetic classes in the data
store).

=item * $SEARCH_XSLT

Location of XSLT for managing searches.

=item * $INSTANCE_XSLT

Location of XSLT for displaying Kinetic instances.

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
