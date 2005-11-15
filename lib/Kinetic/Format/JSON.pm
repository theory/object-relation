package Kinetic::Format::JSON;

use strict;
use warnings;
use JSON ();
use Hash::Merge;
use Class::Delegator
  send => [qw/objToJson jsonToObj/],
  to   => '{json}';

use version;
our $VERSION = version->new('0.0.1');

use aliased 'Kinetic::Meta';

# $Id: JSON.pm 2190 2005-11-08 02:05:10Z curtis $

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

=head1 Name

Kinetic::Format::JSON - The Kinetic JSON serialization class

=head1 Synopsis

  use Kinetic::Format::JSON;
  my $formatter = Kinetic::Format::JSON->new;
  my $json      = $formatter->render($kinetic_object);
  my $object    = $formatter->restore($json);

=head1 Description

This class is used for serializing and deserializing Kinetic objects to and 
from JSON.  New objects may be created or existing objects may be updated using
this class.

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

  my $xml = Kinetic::Format::JSON->new;
  # or
  my $xml = Kinetic::Format::JSON->new({
    pretty => 1,
    indent => 2,
  });

Creates and returns a new JSON format  object.  It optionally takes a
L<Kinetic|Kinetic> object as an argument.  This is equivalent to:

If preferred, a hashref may be passed as an argument.  Keys are:

=over 4

=item * pretty

Whether to use newlines between JSON elements.

=item * indent

Indentation level (in spaces) for nested JSON elements.

=back

As a general rule, you will want to call C<new> without arguments.  This
ensures a more compact JSON representation, thus saving bandwidth.

=cut

sub new {
    my $class = shift;
    return bless $class->_init(shift) => $class;
}

sub _init {
    my ( $class, $arg_for ) = @_;
    $arg_for ||= {};
    my $json = JSON->new(%$arg_for);
    $json->unmapping(1)
      ;    # return 'null' as undef instead of a JSON::NotString object
    $arg_for->{json} = $json;
    return $arg_for;
}

##############################################################################

=head3 render

  my $json = $formatter->render($object);

Render the L<Kinetic|Kinetic> object as JSON.

=cut

sub render {
    my ( $self, $object ) = @_;
    my %value_for;
    foreach my $attr ( $object->my_class->attributes ) {
        $value_for{ $attr->name } = $attr->raw($object);
    }
    $value_for{_key} = $object->my_class->key;
    return $self->objToJson( \%value_for );
}

##############################################################################

=head3 restore

   my $object = $formatter->restore($json);

Restore the object from JSON.

=cut

sub restore {
    my ( $self, $json ) = @_;
    my $value_for = $self->jsonToObj($json);
    my $class     = Meta->for_key( delete $value_for->{_key} );
    my $object    = $class->package->new;
    while ( my ( $attr, $value ) = each %$value_for ) {
        next unless defined $value;
        if ( my $attribute = $class->attributes($attr) ) {
            $attribute->bake( $object, $value );
        }
    }
    return $object;
}

##############################################################################

=head3 save

  $formatter->save($json);

Given JSON, this method finds the appropriate object in the datastore and
updates it.  Will create a new object if the UUID cannot be found.

Returns the created from the JSON, not the C<$formatter> object.

=cut

sub save {
    my ( $self, $json ) = @_;
    my $object = $self->restore($json);
    my $stored = $object->my_class->package->lookup( uuid => $object->uuid );
    if ($stored) {
        foreach my $attr ( $object->my_class->attributes ) {
            my $attr_name = $attr->name;
            $stored->$attr_name( $object->$attr_name );
        }
        $stored->save;
        return $stored;
    }
    else {
        $object->save;
        return $object;
    }
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
