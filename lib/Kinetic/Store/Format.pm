package Kinetic::Store::Format;

# $Id$

use strict;
use warnings;

use version;
our $VERSION = version->new('0.0.2');

use Scalar::Util 'blessed';
use aliased 'Kinetic::Store::Meta';
use Kinetic::Util::Exceptions qw/
  throw_fatal
  throw_invalid_class
  throw_unimplemented
  /;

=head1 Name

Kinetic::Store::Format - The Kinetic serialization class

=head1 Synopsis

  use Kinetic::Store::Format;
  my $formatter = Kinetic::Store::Format->new( { format => 'json' } );
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

  my $xml = Kinetic::Store::Format->new({ format => 'json' });

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
    my ( $self, $format ) = @_;
    $self->_verify_usage;
    return $self->_hashref_to_obj( $self->format_to_ref($format) );
}

##############################################################################

=head3 content_type

  my $content_type = $formatter->content_type;

This method must be overridden in a subclass.

This method returns the MIME content type of the format.

=cut

sub content_type {
    throw_unimplemented [ '"[_1]" must be overridden in a subclass',
        'content_type' ];
}

##############################################################################

=head3 ref_to_format

  my $format = $formatter->ref_to_format($reference);

This method must be overridden in a subclass.

Given an array or hash reference, this method must render it in the correct
format.

=cut

sub ref_to_format {
    throw_unimplemented [ '"[_1]" must be overridden in a subclass',
        'ref_to_format' ];
}

##############################################################################

=head3 format_to_ref

  my $ref = $formatter->format_to_ref($format);

This method must be overridden in a subclass.

Given a format, this method must render it in the correct array or hash
format.

=cut

sub format_to_ref {
    throw_unimplemented [ '"[_1]" must be overridden in a subclass',
        'format_to_ref' ];
}

##############################################################################

=head3 _obj_to_hashref

  my $hashref = $formatter->_obj_to_hashref($object);

Protected method to be used by subclasses, this method should take a
L<Kinetic|Kinetic> object and render it as a hashref.  Only publicly exposed
data will be returned in the hash ref.  Each key will be an attribute name and
the value should be the value of the key, if any.

One special key, C<Key>, will be the class key for the L<Kinetic|Kinetic>
object.

=cut

sub _obj_to_hashref {
    my ( $self, $object ) = @_;
    my %value_for;
    foreach my $attr ( $object->my_class->attributes ) {
        if ( $attr->references ) {
            my $contained = $attr->get($object);
            $value_for{ $attr->name } = $self->_obj_to_hashref($contained);
        }
        else {
            my $value = $attr->raw($object);
            # we're forcing string context here but if it's undef, leave it
            # like that.
            $value = "$value" if defined $value;
            $value_for{ $attr->name } = $value;
        }
    }
    $value_for{Key} = $object->my_class->key;
    return \%value_for;
}

##############################################################################

=head3 _hashref_to_obj

  my $object = $formatter->_hashref_to_obj($hashref);

Protected method to be used by subclasses. Given an hash reference in the
format returned by C<_obj_to_hashref>, this method will return a
L<Kinetic|Kinetic> object for it.

=cut

sub _hashref_to_obj {
    my ( $self, $value_for ) = @_;
    my $class  = Meta->for_key( delete $value_for->{Key} );
    my $object = $class->package->new;
    while ( my ( $attr, $value ) = each %$value_for ) {
        next unless defined $value;
        if ( my $attribute = $class->attributes($attr) ) {
            next unless $attribute->persistent;
            $object->{$attr} = $attribute->references
                ? $self->_hashref_to_obj($value)
                : $value;
        }
    }
    return $object;
}

sub _verify_usage {
    my $self = shift;
    if ( __PACKAGE__ eq ref $self ) {
        throw_fatal [
            'Abstract class "[_1]" must not be used directly',
            __PACKAGE__,
        ];
    }
}

##############################################################################

=head3 expand_ref

  my $ref = $formatter->expand_ref($reference);

Given an arbitrary data structure, this method will walk the structure and
expand the Kinetic object founds into hash references.

Current understands array refs, hashrefs, Kinetic objects and Iterators.

=cut

sub expand_ref {
    my ( $self, $ref ) = @_;
    if ( blessed $ref) {
        if ( $ref->isa('Kinetic') ) {
            return $self->_obj_to_hashref($ref);
        }
        elsif ( $ref->isa('Kinetic::Util::Iterator') ) {
            my @ref;
            while ( my $object = $ref->next ) {
                push @ref => $object;
            }
            $ref = \@ref;
            return $self->expand_ref($ref);
        }
    }

    if ( 'ARRAY' eq ref $ref ) {
        $_ = $self->expand_ref($_) foreach @$ref;
    }
    elsif ( 'HASH' eq ref $ref ) {
        $_ = $self->expand_ref($_) foreach values %$ref;
    }
    return $ref;
}

1;

__END__

=head1 IMPLEMENTING A NEW FORMAT

Adding a new format is as simple as implementing the format with the format
name as the class name upper case, appended to C<Kinetic::Store::Format>:

 package Kinetic::Store::Format::JSON;
 package Kinetic::Store::Format::XML;
 package Kinetic::Store::Format::YAML;

Factory classes must meet the following conditions:

=over 4

=item * Inherit from L<Kinetic::Store::Format>.

The factory class should inherit from C<Kinetic::Store::Format>. 

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

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
