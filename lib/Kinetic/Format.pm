package Kinetic::Format;

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

use strict;
use warnings;

use version;
our $VERSION = version->new('0.0.1');

use Scalar::Util 'blessed';
use aliased 'Kinetic::Meta';
use Kinetic::Util::Exceptions qw/
  throw_fatal
  throw_invalid_class
  throw_unimplemented
  /;

=head1 Name

Kinetic::Format - The Kinetic serialization class

=head1 Synopsis

  use Kinetic::Format;
  my $formatter = Kinetic::Format->new( { format => 'json' } );
  my $json      = $formatter->serialize($kinetic_object);
  my $object    = $formatter->deserialize($json);

=head1 Description

This class is used for serializing and deserializing Kinetic objects to and
from a specified format.  New objects may be created or existing objects may
be updated using this class.

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

  my $xml = Kinetic::Format::JSON->new({ format => 'json' });

Creates and returns a new format object.  Requires a hashref as an argument.
The key C<format> in the hashref must be a valid format with the Kinetic
Platform supports.  Currently supported formats are:

=over 4 

=item * json

=item * xml

=back

=cut

sub new {
    my $class = shift;
    my ( $arg_for, $factory ) = $class->_init(shift);
    if ($factory) {

        # XXX allows the factory class's _init to be called
        return $factory->new($arg_for);
    }
    else {
        return bless $arg_for, $class;
    }
}

sub _init {
    my ( $class, $arg_for ) = @_;
    unless ( exists $arg_for->{format} ) {
        throw_fatal [
            'Required argument "[_1]" to [_2] not found',
            'format', __PACKAGE__ . '::new '
        ];
    }
    my $format        = uc $arg_for->{format};
    my $factory_class = __PACKAGE__ . "::$format";
    eval "use $factory_class;";
    if ( my $error = $@ ) {
        throw_invalid_class [ 'I could not load the class "[_1]": [_2]',
            $factory_class, $error ];
    }
    return ( $arg_for, $factory_class );
}

##############################################################################

=head3 format

  my $format = $formatter->format;

Returns the format for the class.

=cut

sub format { shift->{format} }

##############################################################################

=head3 serialize

  my $format = $formatter->serialize($object);

Render the L<Kinetic|Kinetic> object in the desired format.

=cut

sub serialize {
    my ( $self, $object ) = @_;
    $self->_verify_usage;
    return $self->ref_to_format( $self->_obj_to_hashref($object) );
}

##############################################################################

=head3 deserialize

   my $object = $formatter->deserialize($format);

Restore the object from the desired format.

=cut

sub deserialize {
    my ( $self, $json ) = @_;
    $self->_verify_usage;
    return $self->_hashref_to_obj( $self->format_to_ref($json) );
}

##############################################################################

=head3 ref_to_format

  my $format = $formatter->ref_to_format($reference);

This method must be overridden in a subclass.

Given an array or hash reference, this method must render it in the correct
format.

=cut

sub ref_to_format {
    throw_unimplemented "This must be overridden in a subclass";
}

##############################################################################

=head3 format_to_ref

  my $ref = $formatter->format_to_ref($format);

This method must be overridden in a subclass.

Given a format, this method must render it in the correct array or hash
format.

=cut

sub format_to_ref {
    throw_unimplemented "This must be overridden in a subclass";
}

##############################################################################

=head3 _obj_to_hashref

  my $hashref = $formatter->_obj_to_hashref($object);

Protected method to be used by subclasses, this method should take a
L<Kinetic|Kinetic> object and render it as a hashref.  Only publicly exposed
data will be returned in the hash ref.  Each key will be an attribute name and
the value should be the value of the key, if any.

One special key, C<_key>, will be the class key for the L<Kinetic|Kinetic>
object.

=cut

sub _obj_to_hashref {
    my ( $self, $object ) = @_;
    my %value_for;
    foreach my $attr ( $object->my_class->attributes ) {
        if ( $attr->references ) {
            my $contained = $attr->get($object);
            $value_for{ $attr->name } = $self->serialize($contained);
        }
        else {
            $value_for{ $attr->name } = $attr->raw($object);
        }
    }
    $value_for{_key} = $object->my_class->key;
    return \%value_for;
}

##############################################################################

=head3 _hashref_to_obj

  my $object = $formatter->_hashref_to_obj($hashref);

Protected method to be used by subclasses.  Given an hashreference in the
format returned by C<_obj_to_hashref>, this method will return a
L<Kinetic|Kinetic> object for it.

=cut

sub _hashref_to_obj {
    my ( $self, $value_for ) = @_;
    my $class  = Meta->for_key( delete $value_for->{_key} );
    my $object = $class->package->new;
    while ( my ( $attr, $value ) = each %$value_for ) {
        next unless defined $value;
        if ( my $attribute = $class->attributes($attr) ) {
            next unless $attribute->persistent;
            if ( $attribute->references ) {
                my $contained = $self->deserialize($value);
                $object->$attr($contained);
            }
            else {
                $attribute->bake( $object, $value );
            }
        }
    }
    return $object;
}

sub _verify_usage {
    my $self = shift;
    if ( __PACKAGE__ eq ref $self ) {
        throw_fatal [ 'Abstract class "[_1]" must not be used directly',
            __PACKAGE__ ];
    }
}

##############################################################################

=head3 expand_ref

  my $ref = $formatter->expand_ref($reference);

Given an arbitrary data structure, this method will walk the structure and
expand the Kinetic object founds in to hash references.

=cut

sub expand_ref {
    my ($self, $ref) = @_;
    if (blessed $ref && $ref->isa('Kinetic')) {
        return $self->_obj_to_hashref($ref);
    }
    elsif ('ARRAY' eq ref $ref) {
        $_ = $self->expand_ref($_) foreach @$ref;
    }
    elsif ('HASH' eq ref $ref) {
        $_ = $self->expand_ref($_) foreach values %$ref;
    }
    return $ref;
}

1;

__END__

=head1 IMPLEMENTING A NEW FORMAT

Adding a new format is as simple as implementing the format with the format
name as the class name upper case, appended to C<Kinetic::Format>:

 package Kinetic::Format::JSON;
 package Kinetic::Format::XML;
 package Kinetic::Format::YAML;

Factory classes must meet the following conditions:

=over 4

=item * Inherit from L<Kinetic::Format>.

The factory class should inherit from C<Kinetic::Format>. 

=item * C<new> is optional.

A constructor should not be supplied, but if it is, it should be named C<new>
and should call the super class constructor.

=item * Implement C<_init> method.

It should have an C<_init> method which sets up special properties, if any, of
the class.  If an init method is present, it should accept an optional hash
reference of properties necessary for the class and return a single argument.

=item * Implement C<format_to_ref> and C<ref_to_format> methods.

The input and output is described in this document.  Implementation behavior
is up to the implementor.

=back

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
