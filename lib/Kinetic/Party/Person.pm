package Kinetic::Party::Person;

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

use base qw(Kinetic::Party);
use Kinetic::Util::Context;
use Lingua::Strfname ();
use Kinetic::Util::Config qw(:user);

=head1 Name

Kinetic::::Party::Person - Kinetic person objects

=head1 Description

This class serves as the abstract base class for people in TKP.

=cut

BEGIN {
    my $km = Kinetic::Meta->new(
        key         => 'person',
        name        => 'Person',
        plural_name => 'Persons',
        abstract    => 1,
    );

##############################################################################
# Constructors.
##############################################################################

=head1 Instance Interface

In addition to the interface inherited from L<Kinetic::::|Kinetic> and
L<Kinetic::::Party|Kinetic::::Party>, this class offers a number of its own
attributes.

=head2 Accessors

=head3 last_name

  my $last_name = $person->last_name;
  $person->last_name($last_name);

The person's last name. Also known as a "family name" or a "surname".

=cut

    $km->add_attribute(
        name        => 'last_name',
        label       => 'Last Name',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The person's last name"
        )
    );

##############################################################################

=head3 first_name

  my $first_name = $person->first_name;
  $person->first_name($first_name);

The person's first name. Also known as a "given name".

=cut

    $km->add_attribute(
        name        => 'first_name',
        label       => 'First Name',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The person's first name"
        )
    );

##############################################################################

=head3 middle_name

  my $middle_name = $person->middle_name;
  $person->middle_name($middle_name);

The person's middle name. Also known as a "second name".

=cut

    $km->add_attribute(
        name        => 'middle_name',
        label       => 'Middle Name',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The person's middle name"
        )
    );

##############################################################################

=head3 nickname

  my $nickname = $person->nickname;
  $person->nickname($nickname);

The person's nickname.

=cut

    $km->add_attribute(
        name        => 'nickname',
        label       => 'Nickname',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The person's nickname"
        )
    );

##############################################################################

=head3 prefix

  my $prefix = $person->prefix;
  $person->prefix($prefix);

The prefix to the person's name, such as "Mr.", "Ms.", "Dr.", etc.

=cut

    $km->add_attribute(
        name        => 'prefix',
        label       => 'Prefix',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The prefix to the person's name"
        )
    );

##############################################################################

=head3 suffix

  my $suffix = $person->suffix;
  $person->suffix($suffix);

The suffix to the person's name, such as "JD", "PhD", "MD", etc.

=cut

    $km->add_attribute(
        name        => 'suffix',
        label       => 'Suffix',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The suffix to the person's name"
        )
    );

##############################################################################

=head3 generation

  my $generation = $person->generation;
  $person->generation($generation);

The generation to the person's name, such as "Jr.", "III", etc.

=cut

    $km->add_attribute(
        name        => 'generation',
        label       => 'Generation',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The generation of the person's name"
        )
    );

##############################################################################

=head2 Instance Methods

=head3 name

  my $name = $person->strfname;
  $name = $person->strfname($format);

Returns the person object's name as formatted according to a
L<Linguage::Strfname|Linguage::Strfname> format. Kinetic::::Party::Person uses
defines this method as a read-only attribute.

The default format is specified by the locale returned by the currently
selected langauge. See the L<Linguage::Strfname|Linguage::Strfname>
documentation for details on its formats to pass in custom formats.

=cut

    sub name {
        my ($self, $format) = @_;
        $format ||=
          Kinetic::Util::Language->get_handle->maketext('strfname_format');
        return Lingua::Strfname::strfname(
            $format,
            $self->last_name,
            $self->first_name,
            $self->middle_name,
            $self->prefix,
            $self->suffix,
            $self->generation
        );
    }

    # We want the name method to actually be a read-only attribute.
    $km->add_method(
        name    => 'name',
        label   => 'Name',
        returns => 'string',
    );

    $km->build;
} # BEGIN

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
