package Kinetic::Meta::DataTypes;

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
use Class::Meta::Type;
use Data::UUID;
use Data::Types;
use Kinetic::DateTime;
use Kinetic::Exceptions qw(throw_invalid);
use Kinetic::Meta::AccessorBuilder;

=head1 Name

Kinetic::Meta::DataTypes - Kinetic data type definition

=head1 Synopsis

  package Kinetic::Foo;
  use strict;
  use base 'Kinetic';

  BEGIN {
      my $cm = Kinetic::Meta->new( key => 'foo );
      $cm->add_attribute( name => 'bar',
                          type => 'bool' );
     $cm->build;
  }

=head1 Description

This module handles the definition of data types used by Kinetic. It should
never be used directly. Consult L<Kinetic::Meta|Kinetic::Meta> and
L<Class::Meta|Class::Meta> for details on creating new Kinetic classes with
attributes of the types defined by this module.

=cut

sub _make_isa_check {
    my $pkg = shift;
    return [ sub {
        return unless defined $_[0];
        UNIVERSAL::isa($_[0], $pkg)
          or throw_invalid(['Value "[_1]" is not a valid [_2] object',
                            $_[0], $pkg]);
    } ];
};

Class::Meta::Type->class_validation_generator(\&_make_isa_check);

##############################################################################

=head1 Data Types

The Data types defined by this module are:

=over 4

=item guid

A globally unique identifier as generated to Data::UUID.

=cut

my $ug = Data::UUID->new;
Class::Meta::Type->add(
    key     => "guid",
    name    => "Globally Unique Identifier",
    builder => 'Kinetic::Meta::AccessorBuilder',
    check   => sub {
        eval { $ug->from_string($_[0]) }
          or throw_invalid(['Value "[_1]" is not a GUID', $_[0]]);
    }
);

=item string

A Perl string, decoded to its internal, utf8 format.

=cut

Class::Meta::Type->add(
    key     => "string",
    name    => "String",
    builder => 'Kinetic::Meta::AccessorBuilder',
    check   => sub {
        return unless defined $_[0] && ref $_[0];
        $_[2]->class->handle_error("Value '$_[0]' is not a valid string");
    }
);

##############################################################################

=item whole

A whole number. Throws a Fatal::Invalid exception if the value is not a whole
number.

=cut

Class::Meta::Type->add(
    key     => "whole",
    name    => "Whole Number",
    builder => 'Kinetic::Meta::AccessorBuilder',
    check   => sub {
        return unless defined $_[0];
        Data::Types::is_whole($_[0])
          or throw_invalid("Value '$_[0]' is not a whole number");
    }
);

##############################################################################

=item bool

A boolean value.

=cut

use Class::Meta::Types::Boolean;

##############################################################################

=item datetime

A Kinetic::DateTime object.

=cut

Class::Meta::Type->add(
    key     => "datetime",
    name    => "DateTime",
    builder => 'Kinetic::Meta::AccessorBuilder',
    check   => 'Kinetic::DateTime',
);

##############################################################################

=item user

A Kinetic::Party::Person::User object.

=cut

Class::Meta::Type->add(
    key     => "user",
    name    => "User",
    builder => 'Kinetic::Meta::AccessorBuilder',
    check   => 'Kinetic::Party::Person::User',
);

##############################################################################

=item state

A Kinetic::State object.

=cut

Class::Meta::Type->add(
    key     => "state",
    name    => "State",
    builder => 'Kinetic::Meta::AccessorBuilder',
    check   => sub {
        UNIVERSAL::isa($_[0], 'Kinetic::State')
            or throw_invalid(['Value "[_1]" is not a valid [_2] object',
                              $_[0], 'Kinetic::State']);
        throw_invalid(['Cannot assign permanent state'])
          if $_[0] == Kinetic::State->PERMANENT;
    }
);

=back

=cut

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
