package Kinetic::Language;

# $Id$

use strict;
use version;
use base qw(Locale::Maketext);

=encoding utf8

=head1 Name

Kinetic::Language - Kinetic localization class

=head1 Synopsis

  use Kinetic::Language;
  my $lang = Kinetic::Language->get_handle;
  print $lang->maketext($msg);

=head1 Description

This class handles Kinetic localization. It subclasses
L<Locale::Maketext|Locale::Maketext> to offer this functionality.

=cut

##############################################################################
# This is the default lexicon from which all other languages inherit.
##############################################################################

our %Lexicon = (
  # Classes.
  'Kinetic' => 'Kinetic',
  'Class' => 'Class',
  'Classes' => 'Classes',
  'Party' => 'Party',
  'Parties', 'Parties',
  'Person' => 'Person',
  'Persons' => 'Persons',
  'User' => 'User',
  'Users' => 'Users',

  # Exceptions.
  'Value "[_1]" is not a [_2] object' => 'Value \x{201c}[_1]\x{201d} is not a [_2] object',
  'Value "[_1]" is not a GUID' => 'Value \x{201c}[_1]\x{201d} is not a GUID',
  'Attribute must be defined' => 'Attribute must be defined',
  'Localization for "[_1]" not found' => 'Localization for \x{201c}[_0]\x{201d} not found',
  'Cannot assign to read-only attribute "[_1]"' => 'Cannot assign to read-only attribute \x{201c}[_1]\x{201d}',
  'Argument "[_1]" is not a code reference' => 'Argument \x{201c}[_1]\x{201d} is not a code reference',
  'Argument "[_1]" is not a [_2] object' => 'Argument \x{201c}[_1]\x{201d} is not a [_2] object',
  'Cannot assign permanent state' => 'Cannot assign permanent state',
  'Cannot open file "[_1]": [_2]' => 'Cannot open file \x{201c}[_1]\x{201d}: [_2]',

  # States.
  'Permanent' => 'Permanent',
  'Active' => 'Active',
  'Inactive' => 'Inactive',
  'Deleted' => 'Deleted',
  'Purged' => 'Purged',

  # Priorities.
  'Lowest' => 'Lowest',
  'Low' => 'Low',
  'Normal' => 'Normal',
  'High' => 'High',
  'Highest' => 'Highest',

  # Kinetic Attribute labels and tips.
  'GUID' => 'GUID',
  'The globally unique identifier for this object' => 'The globally unique identifier for this object',
  'Name' => 'Name',
  'The name of this object' => 'The name of this object',
  'Description' => 'Description',
  'The description of this object' => 'The description of this object',
  'State' => 'State',
  'The state of this object' => 'The state of this object',

  # Kinetic::Party::Person labels and tips.
  'Last Name' => 'Last Name',
  "The person's last name" => "The person's last name",
  'First Name', => 'First Name',
  "The person's first name" => "The person's first name",
  'Middle Name', => 'Middle Name',
  "The person's middle name" => "The person's middle name",
  'Nickname', => 'Nickname',
  "The person's nickname" => "The person's nickname",
  'Prefix' => 'Prefix',
  "The prefix to the person's name" => "The prefix to the person's name, such as \x{201c}Mr.\x{201d}, \x{201c}Ms.\x{201d}, \x{201c}Dr.\x{201d}, etc.",
  'Suffix' => 'Suffix',
  "The suffix to the person's name" => "The suffix to the person's name, such as \x{201c}JD\x{201d}, \x{201c}PhD\x{201d}, \x{201c}MD\x{201d}, etc.",
  'Generation' => 'Generation',
  "The generation of the person's name" => "The generation to the person's name, such as \x{201c}Jr.\x{201d}, \x{201c}III\x{201d}, etc.",
  'strfname_format' => "%p% f% M% l% g%, s",

  # Kinetic::Party::Person::User labels and tips.
  'Username' => 'Username',
  "The user's username" => "The user's username",
  'Password' => 'Password',
  "The user's password" => "The user's password",
);

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 get_handle

  my $lang = Kinetic::Language->get_handle;

Returns a Kinetic::Language subclass object for a particular language.
See L<Locale::Maketext|Locale::Maketext> for a complete description of its
interface. Kinetic::Language overrides the Locale::Maketext
implementation of this method to add special error handling that will throw
Kinetic exceptions. It is otherwise exactly the same as the C<get_handle>
method of Locale::Maketext.

=cut

my $fail_with = sub {
    my ($lang, $key) = @_;
    require Kinetic::Exceptions;
    Kinetic::Exception::Fatal::Language->throw(
        ['Localization for "[_1]" not found', $key]
    );
};

sub get_handle {
    my $handle = shift->SUPER::get_handle(@_);
    $handle->fail_with($fail_with);
    return $handle;
}

1;
__END__

##############################################################################

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item L<Kinetic|Kinetic>

The Kinetic base class.

=item L<Locale::Maketext|Locale::Maketext>

The Perl localization class, from which Kinetic::Language inherits
most of its interface.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This Library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
