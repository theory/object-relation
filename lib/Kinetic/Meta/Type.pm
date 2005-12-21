package Kinetic::Meta::Type;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or derivatives to
# this work, or any other work intended for use with the Kinetic framework, to
# Kineticode, Inc., you confirm that you are the copyright holder for those
# contributions and you grant Kineticode, Inc.  a nonexclusive, worldwide,
# irrevocable, royalty-free, perpetual license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute those
# contributions and any derivatives thereof.

use strict;

use version;
our $VERSION = version->new('0.0.1');

use base 'Class::Meta::Type';
use Kinetic::Meta::AccessorBuilder;
__PACKAGE__->default_builder('Kinetic::Meta::AccessorBuilder');

=head1 Name

Kinetic::Meta::Type - Kinetic Data type validation and accessor building

=head1 Synopsis

  Kinetic::Meta::Type->add(
      key     => "state",
      name    => "State",
      builder => 'Kinetic::Meta::AccessorBuilder',
      raw     => sub { shift->value },
      check   => sub {
          UNIVERSAL::isa($_[0], 'Kinetic::Util::State')
              or throw_invalid(['Value "[_1]" is not a valid [_2] object',
                                $_[0], 'Kinetic::Util::State']);
          throw_invalid(['Cannot assign permanent state'])
            if $_[0] == Kinetic::Util::State->PERMANENT;
      }
  );

=head1 Description

This class subclasses L<Class::Meta::Type|Class::Meta::Type> to provide an
additional accessor, C<raw>. This attribute can optionally be set via the call
to C<new()>. It is a code reference that returns the raw value of an attribute
as opposed to the standard value. The raw value is a value suitable for
serializing to a database.

The code reference should simply expect the value returned by the C<get>
accessor as its sole argument. It can then take whatever steps are necssary to
return a serializable value. For example, if for a C<DateTime> data type, we
might want to get back a string in ISO-8601 format in the UTC time zone. The
raw code reference to do so might look like this:

  sub { shift->clone->set_time_zone('UTC')->iso8601 }

=head1 Dynamic APIs

This class supports the dynamic loading of extra methods specifically designed
to be used with particular Kinetic data store implementations. See
L<Kinetic::Meta|Kinetic::Meta> for details. The supported labels are:

=over

=item :with_dbstore_api

Adds a new() constructor to overload the parent. The purpose is to add a raw()
accessor that returns the database ID of an referenced object, rather than the
object itself.

=begin comment

=item new

Allow POD coverage tests to pass.

=end comment

=back

=cut

sub import {
    my ($pkg, $api_label) = @_;
    return unless $api_label;
    if ($api_label eq ':with_dbstore_api') {
        return if defined(&new);
        # Create methods specific to database stores.
        no strict 'refs';
        *{__PACKAGE__ . '::new'} = sub {
            my $self = shift->SUPER::new(@_);
            # Set the raw method to return the object ID. Use
            # Class::Meta->for_key to avoid Kinetic::Meta->for_key's
            # exception.
            $self->{raw} ||= sub {
                my $obj = shift or return undef;
                return $obj->id;
            } if Class::Meta->for_key($self->key);
            return $self;
        };
    }
}

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 raw

  my $code = $type->raw;

Returns a code reference to get the raw value of a type. Used internally by
L<Kinetic::Meta::Attribute|Kinetic::Meta::Attribute>.

=cut

sub raw { shift->{raw} }

##############################################################################

=head3 bake

  my $code = $type->bake;

Returns a code reference to set the raw value of a type without actually
needing to set an object value. Used internally by
L<Kinetic::Meta::Attribute|Kinetic::Meta::Attribute>.

=cut

sub bake { shift->{bake} }

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
