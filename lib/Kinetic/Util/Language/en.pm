package Kinetic::Util::Language::en;

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
use base 'Kinetic::Util::Language';
use encoding 'utf8';

=encoding utf8

=head1 Name

Kinetic::Util::Language::en - Kinetic English localization

=head1 Description

This class handles Kinetic English localization. See
L<Kinetic::Util::Language|Kinetic::Util::Language> for a complete description of the
Kinetic localization interface.

=cut

our %Lexicon = (
  # Classes.
  'Kinetic' => 'Kinetic',
  'Class'   => 'Class',
  'Classes' => 'Classes',
  'Party'   => 'Party',
  'Parties' => 'Parties',
  'Person'  => 'Person',
  'Persons' => 'Persons',
  'User'    => 'User',
  'Users'   => 'Users',

  # States.
  'Permanent' => 'Permanent',
  'Active'    => 'Active',
  'Inactive'  => 'Inactive',
  'Deleted'   => 'Deleted',
  'Purged'    => 'Purged',

  # Exceptions.
  'Value "[_1]" is not a valid [_2] object',
  "Value “[_1]” is not a valid [_2] object",

  'Value "[_1]" is not a GUID',
  "Value “[_1]” is not a GUID",

  'Attribute must be defined',
  'Attribute must be defined',

  'Localization for "[_1]" not found',
  "Localization for “[_1]” not found",

  'Cannot assign to read-only attribute "[_1]"',
  "Cannot assign to read-only attribute “[_1]”",

  'Argument "[_1]" is not a code reference',
  "Argument “[_1]” is not a code reference",

  'Argument "[_1]" is not a valid [_2] object',
  "Argument “[_1]” is not a valid[_2] object",

  'Cannot assign permanent state',
  'Cannot assign permanent state',

  'Cannot open file "[_1]": [_2]',
  "Cannot open file “[_1]”: [_2]",

  # Kinetic Attribute labels and tips.
  'GUID' => 'GUID',
  'The globally unique identifier for this object',
  'The globally unique identifier for this object',

  'Name' => 'Name',
  'The name of this object',
  'The name of this object',

  'Description' => 'Description',
  'The description of this object',
  'The description of this object',

  'State' => 'State',
  'The state of this object',
  'The state of this object',

  # Kinetic::Party::Person labels and tips.
  'Last Name' => 'Last Name',
  "The person's last name",
  "The person's last name",

  'First Name' => 'First Name',
  "The person's first name",
  "The person's first name",

  'Middle Name' => 'Middle Name',
  "The person's middle name",
  "The person's middle name",

  'Nickname' => 'Nickname',
  "The person's nickname",
  "The person's nickname",

  'Prefix' => 'Prefix',
  "The prefix to the person's name",
  "The prefix to the person's name, such as “Mr.”, “Ms.”, “Dr.”, etc.",

  'Suffix' => 'Suffix',
  "The suffix to the person's name",
  "The suffix to the person's name, such as “JD”, “PhD”, “MD”, etc.",

  'Generation' => 'Generation',
  "The generation of the person's name",
  "The generation to the person's name, such as “Jr.”, “III”, etc.",

  'strfname_format' => "%p% f% M% l% g%, s",

  # Kinetic::Party::Person::User labels and tips.
  'Username' => 'Username',
  "The user's username",
  "The user's username",

  'Password' => 'Password',
  "The user's password",
  "The user's password",
);

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. <info@kineticode.com>

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