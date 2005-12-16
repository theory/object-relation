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

use version;
our $VERSION = version->new('0.0.1');

use base 'Kinetic::Util::Language';
use encoding 'utf8';

=encoding utf8

=head1 Name

Kinetic::Util::Language::en - Kinetic English localization

=head1 Description

This class handles Kinetic English localization. See
L<Kinetic::Util::Language|Kinetic::Util::Language> for a complete description
of the Kinetic localization interface.

=cut

our %Lexicon;
{
    my %classes = (
        'Kinetic' => 'Kinetic',
        'Class'   => 'Class',
        'Classes' => 'Classes',
        'Party'   => 'Party',
        'Parties' => 'Parties',
        'Person'  => 'Person',
        'Persons' => 'Persons',
        'User'    => 'User',
        'Users'   => 'Users',
    );

    my %kinetic_object_states = (
        'Permanent' => 'Permanent',
        'Active'    => 'Active',
        'Inactive'  => 'Inactive',
        'Deleted'   => 'Deleted',
        'Purged'    => 'Purged',
    );

    my %lexer_parser_messages = (
        'Could not lex search request.  Found bad tokens ([_1])',
        'Could not lex search request. Found bad tokens ([_1])',

        'I don\'t know how to lex a "[_1]"',
        'I don\'t know how to lex a “[_1]”',

        'Could not parse search request:  [_1]',
        'Could not parse search request:  [_1]',

        'Could not parse search request',
        'Could not parse search request',

        q{Don't know how to search for ([_1] [_2] [_3] [_4]): [_5]},
        'Don’t know how to search for ([_1] [_2] [_3] [_4]): [_5]',

        'Object key "[_1]" must point to an object, not a scalar "[_1]"',
'Object key “[_1]” must point to an object, not a scalar “[_2]”',
    );

    my %search_messages = (
        'BETWEEN searches may only take two values.  You have [_1]',
        'BETWEEN searches may only take two values. You have [_1]',

        'Odd number of constraints in string search:  "[_1]"',
        'Odd number of constraints in string search “[_1]”',

        'Failed to convert IR to where clause.  This should not happen.',
        'Failed to convert IR to where clause. This should not happen.',

        '[_1] does not support full-text searches',
        '[_1] does not support full-text searches',

        'MATCH:  [_1] does not support regular expressions',
        'MATCH: [_1] does not support regular expressions',

        'You cannot do GT or LT type searches with non-contiguous dates',
        'You cannot do GT or LT type searches with non-contiguous dates',

        'You cannot do range searches with non-contiguous dates',
        'You cannot do range searches with non-contiguous dates',

        'BETWEEN search dates must have identical segments defined',
        'BETWEEN search dates must have identical segments defined',

        'All types to an ANY search must match',
        'All types to an ANY search must match',

'BETWEEN searches must be between identical types. You have ([_1]) and ([_2])',
'BETWEEN searches must be between identical types. You have ([_1]) and ([_2])',

        'BETWEEN searches should have two terms. You have [_1] term(s).',
        'BETWEEN searches should have two terms. You have [_1] term(s).',

        'PANIC: ANY search data is not an array ref. This should never happen.',
        'PANIC: ANY search data is not an array ref. This should never happen.',

'PANIC: BETWEEN search data is not an array ref. This should never happen.',
'PANIC: BETWEEN search data is not an array ref. This should never happen.',

        'PANIC: lookup([_1], [_2], [_3]) returned more than one result.',
        'PANIC: lookup([_1], [_2], [_3]) returned more than one result.',

        'Unknown column "[_1]"',
        'Unknown column “[_1]”',
    );

    my %rest_messages = (
        'The first method in a chain must return objects. You used "[_1]"',
        'The first method in a chain must return objects. You used “[_1]”',

        'No resource available to handle "[_1]"',
        'No resource available to handle “[_1]”',
    );

    %Lexicon = (
        %classes,
        %kinetic_object_states,
        %lexer_parser_messages,
        %search_messages,
        %rest_messages,

        # Exceptions.
        'Value "[_1]" is not a valid [_2] object',
        'Value “[_1]” is not a valid [_2] object',

        'Value "[_1]" is not a UUID',
        'Value “[_1]” is not a UUID',

        'Could not determine widget type handler for "[_1]"',
        'Could not determine widget type handler for “[_1]”',

        'Attribute must be defined',
        'Attribute must be defined',

        'Localization for "[_1]" not found',
        'Localization for “[_1]” not found',

        'File "[_1]" not found',
        'File “[_1]” not found',

        'Cannot assign to read-only attribute "[_1]"',
        'Cannot assign to read-only attribute “[_1]”',

        'Argument "[_1]" is not a code reference',
        'Argument “[_1]” is not a code reference',

        'Argument "[_1]" is not a valid [_2] object',
        'Argument “[_1]” is not a valid [_2] object',

        'Argument "[_1]" is not a valid [_2] class',
        'Argument “[_1]” is not a valid [_2] class',

        'Value "[_1]" is not a string',
        'Value “[_1]” is not a string',

        'Value "[_1]" is not a whole number',
        'Value “[_1]” is not a whole number',

        'Cannot assign permanent state',
        'Cannot assign permanent state',

        'Cannot open file "[_1]": [_2]',
        'Cannot open file “[_1]”: [_2]',

        'Required argument "[_1]" to [_2] not found',
        'Required argument “[_1]” to [_2] not found',

        'Required attribute "[_1]" not set',
        'Required attribute “[_1]” not set',

        'XML must have a version number.',
        'XML must have a version number.',

        'I could not find the class for key "[_1]"',
        'I could not find the class for key “[_1]”',

        'You must supply a name for the "[_1]"',
        'You must supply a name for the “[_1]”',

        'Writing XML failed: [_1]',
        'Writing XML failed: [_1]',

        'No such attribute "[_1]" for [_2]',
        'No such attribute “[_1]” for [_2]',

        'Attribute "[_1]" is not unique',
        'Attribute “[_1]” is not unique',

        'Error saving to data store: [_1]',
        'Error saving to data store: [_1]',

        'Non-persistent temporary object storage',
        'Non-persistent temporary object storage',

        'I could not find uuid "[_1]" in data store for the [_2] class',
        'I could not find UUID “[_1]” in the data store for the [_2] class',

        'I could not load the class "[_1]": [_2]',
        'I could not load the class “[_1]”: [_2]',

        'Abstract class "[_1]" must not be used directly',
        'Abstract class “[_1]” must not be used directly',

        '"[_1]" must be overridden in a subclass',
        '“[_1]” must be overridden in a subclass',

        'Unknown import symbol "[_1]"',
        'Unknown import symbol “[_1]”',

        'Unknown attributes to [_1]: [_2]',
        'Unknown attributes to [_1]: [_2]',

        'Bad type for [_1].  Should be [_2].',
        'Bad type for [_1]. Should be [_2].',

        'Unknown stylesheet requested: [_1]',
        'Unknown stylesheet requested: [_1]',

        'Invalid method "[_1]"',
        'Invalid method “[_1]”',

        # Kinetic::Meta::Class error.
        'No direct attribute "[_1]" to sort by',
        'No direct attribute “[_1]” to sort by',

        # Kinetic Attribute labels and tips.
        'UUID' => 'UUID',
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
        q{The person's last name},
        'The person’s last name',

        'First Name' => 'First Name',
        q{The person's first name},
        'The person’s first name',

        'Middle Name' => 'Middle Name',
        q{The person's middle name},
        'The person’s middle name',

        'Nickname' => 'Nickname',
        q{The person's nickname},
        'The person’s nickname',

        'Prefix' => 'Prefix',
        q{The prefix to the person's name},
'The prefix to the person’s name, such as “Mr.”, “Ms.”, “Dr.”, etc.',

        'Suffix' => 'Suffix',
        q{The suffix to the person's name},
'The suffix to the person’s name, such as “JD”, “PhD”, “MD”, etc.',

        'Generation' => 'Generation',
        q{The generation of the person's name},
'The generation to the person’s name, such as “Jr.”, “III”, etc.',

        'strfname_format' => '%p% f% M% l% g%, s',

        # Kinetic::Party::Person::User labels and tips.
        'Username' => 'Username',
        q{The user's username},
        'The user’s username',

        'Password' => 'Password',
        q{The user's password},
        'The user’s password',
    );
}

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
