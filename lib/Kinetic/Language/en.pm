package Kinetic::Language::en;

# $Id$

use strict;
use base 'Kinetic::Language';
use encoding 'utf8';

=encoding utf8

=head1 Name

Kinetic::Language::en - Kinetic English localization

=head1 Description

This class handles Kinetic English localization. See
L<Kinetic::Language|Kinetic::Language> for a complete description of the
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
  'Value "[_1]" is not a [_2] object',
  "Value “[_1]” is not a [_2] object",

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

  'Argument "[_1]" is not a [_2] object',
  "Argument “[_1]” is not a [_2] object",

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

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item L<Kinetic::Language|Kinetic::Language>

The Kinetic localization class.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This Library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
