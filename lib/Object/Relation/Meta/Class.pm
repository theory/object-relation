package Object::Relation::Meta::Class;

# $Id$

use strict;

our $VERSION = '0.11';

use base 'Class::Meta::Class';
use Object::Relation::Exceptions qw/throw_fatal/;
use List::Util qw(first);
use aliased 'Object::Relation::Language';

=head1 Name

Object::Relation::Meta::Class - Object::Relation class metadata class.

=head1 Synopsis

  my $class = MyThingy->my_class;
  my $thingy = MyThingy->new;

  print "Examining object of ", ($class->abstract ? "abstract " : ''),
    "class ", $class->package, $/;

  print "\nConstructors:\n";
  for my $ctor ($class->constructors) {
      print "  o ", $ctor->name, $/;
  }

  print "\nAttributes:\n";
  for my $attr ($class->attributes) {
      print "  o ", $attr->name, " => ", $attr->get($thingy) $/;
  }

  print "\nMethods:\n";
  for my $meth ($class->methods) {
      print "  o ", $meth->name, $/;
  }

=head1 Description

This class inherits from L<Class::Meta::Class|Class::Meta::Class> to provide
class metadata for Object::Relation classes. See the L<Class::Meta|Class::Meta>
documentation for details on meta classes. See the L<"Accessor Methods"> for
the additional attributes.

=cut

=for private

The C<import()> method is merely a placeholder to ensure that
L<Object::Relation::Meta|Object::Relation::Meta> can dispatch its import symbols to a variety
of classes and "just work".  This class is specifically documented as accepting
those symbols.  See the documentation for L<Object::Relation::Meta|Object::Relation::Meta> for
more information.

=cut

sub import {
    my ( $pkg, $symbol ) = @_;
    return unless $symbol;

    # currently a no-op
    return if ( ':with_dbstore_api' eq $symbol );
    throw_fatal [ 'Unknown import symbol "[_1]"', shift ];
}

##############################################################################
# Constructor.
##############################################################################

=head1 Class Interface

=head2 Constructor

=head3 new

This constructor overrides the parent class constructor from
L<Class::Meta::Class|Class::Meta::Class> in order to check for C<extends>,
C<type_of>, and C<mediates> parameters and, if any is present, convert it from
a class key to the corresponding class object.

=cut

sub new {
    my $self = shift->SUPER::new(@_);
    for my $rel (qw(extends type_of mediates)) {
        if (my $ref = $self->{$rel}) {
            $self->{$rel} = Object::Relation::Meta->for_key($ref) unless ref $ref;
        }
    }

    unless ($self->{plural_key} && $self->{plural_name}) {
        require Lingua::EN::Inflect;
        $self->{plural_key}  ||= Lingua::EN::Inflect::PL( $self->key  );
        $self->{plural_name} ||= Lingua::EN::Inflect::PL( $self->SUPER::name );
    }

    $self->{contained_in} ||= {};
    return $self;
}

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Accessor Methods

=head3 plural_key

  my $plural_key = $class->plural_key;

The pluralized form of the C<key> attribute, such as "thingies".

=cut

sub plural_key { shift->{plural_key} }

##############################################################################

=head3 name

  my $name = $class->name;

Returns the localized form of the name of the class, such as "Thingy".

=cut

sub name {
    Language->get_handle->maketext( shift->SUPER::name );
}

##############################################################################

=head3 plural_name

  my $plural_name = $class->plural_name;

Returns the localized plural form of the name of the class, such as
"Thingies".

=cut

sub plural_name {
    Language->get_handle->maketext( shift->{plural_name} );
}

##############################################################################

=head3 sort_by

  my $sort_by  = $class->sort_by;
  my @sort_bys = $class->sort_by;

Returns the name of the attribute to use when sorting a list of objects of
this class. If more than one attribute has been specified for sorting, they
can all be retrieved by calling C<sort_by()> in an list context.

=cut

sub sort_by {
    my $self = shift;
    return wantarray ? @{ $self->{sort_by} } : $self->{sort_by}[0];
}

##############################################################################

=head3 extends

  my $extends  = $class->extends;

Returns a Object::Relation::Meta::Class object representing a class that this class
extends. Extension is different than inheritance, in that the object in the
extended class can correspond to one or more instances of objects in the
extending class.

=cut

sub extends { shift->{extends} }

##############################################################################

=head3 type_of

  my $type_of  = $class->type_of;

Returns a Object::Relation::Meta::Class object representing a class that this
class is a type of.

=cut

sub type_of { shift->{type_of} }

##############################################################################

=head3 mediates

  my $mediates  = $class->mediates;

Returns a Object::Relation::Meta::Class object representing a class that this
class mediates.

=cut

sub mediates { shift->{mediates} }

##############################################################################

=head2 Instance Methods

=head3 ref_attributes

  my @ref_attrs = $class->ref_attributes;

Returns a list of attributes that reference other Object::Relation::Meta
objects. Equivalent to

  my @ref_attrs = grep { $_->references } $self->attributes;

only more efficient, thanks to build-time caching.

=cut

sub ref_attributes { @{ shift->{ref_attrs} } }

##############################################################################

=head3 direct_attributes

  my @direct_attrs = $class->direct_attributes;

Returns a list of attributes that do not reference other
Object::Relation::Meta objects. Equivalent to

  my @direct_attrs = grep { ! $_->references } $self->attributes;

only more efficient, thanks to build-time caching.

=cut

sub direct_attributes { @{ shift->{direct_attrs} } }

##############################################################################

=head3 persistent_attributes

  my @persistent_attrs = $class->persistent_attributes;

Returns a list of persistent attributes -- that is, those that should be
stored in a data store, as opposed to used arbitrarily in the class.
Equivalent to

  my @persistent_attrs = grep { $_->persistent } $self->attributes;

only more efficient, thanks to build-time caching.

=cut

sub persistent_attributes { @{ shift->{persistent_attrs} } }

##############################################################################

=head3 collection_attributes

  my @collection_attrs = $class->collection_attributes;

Returns a list of collection attributes -- that is, attributes that are
collections of objects. Equivalent to

  my @collection_attrs = grep { $_->collection_of } $self->attributes;

only more efficient, thanks to build-time caching.

=cut

sub collection_attributes { @{ shift->{collection_attrs} } }

##############################################################################

=head3 contained_in

  my @containers = $class->contained_in;

  if ( my $container = $class->contained_in($key) ) {
      ...
  }

If instances of this class are available in collections of other classes, this
method will return all of those classes, sorted by key. If given a specific
key, returns the class for that key, if the current class can be contained in
the key class. Otherwise, returns false.

=cut

sub contained_in {
    my $self = shift;
    my $contained_in = $self->{contained_in};
    return $contained_in->{+shift} if @_;
    return map { $contained_in->{$_} } sort keys %$contained_in unless @_;
}

##############################################################################

=head3 build

This private method overrides the parent C<build()> method in order to cache
the a list of the referenced attributes for use by C<ref_attributes()>.

=cut

sub build {
    my $self = shift->SUPER::build(@_);

    # Organize attrs into categories.
    my (@ref, @direct, @persist, @colls);
    FAKE: {
        # Fake out Object::Relation::Handle so that we can get at trusted attributes.
        package Object::Relation::Handle;
        for my $attr ($self->attributes) {
            push @persist, $attr if $attr->persistent;
            push @colls,   $attr if $attr->collection_of;
            if ($attr->references) {
                push @ref, $attr;
            } else {
                push @direct, $attr;
            }
        }
    }

    # Cache categories for fast method calls.
    $self->{ref_attrs}        = \@ref;
    $self->{direct_attrs}     = \@direct;
    $self->{persistent_attrs} = \@persist;
    $self->{collection_attrs} = \@colls;

    if (my $sort_by = $self->{sort_by}) {
        $sort_by = [$sort_by] unless ref $sort_by;
        my %attrs = map { $_->name => $_ } @{ $self->{direct_attrs} };
        my @sort_attrs;
        for my $attr ( @{ $sort_by } ) {
            throw_fatal [ 'No direct attribute "[_1]" to sort by', $attr ]
                unless exists $attrs{$attr};
            push @sort_attrs, $attrs{$attr};
        }
        $self->{sort_by} = \@sort_attrs;
    } else {
        $self->{sort_by} = [
            first {
                $_->package ne 'Object::Relation::Base' && $_->name ne 'id'
            } @direct
        ];
    }
    return $self;
}

##############################################################################

=begin private

=head2 Private Instance Methods

=head3 _add_container

  $class->_add_container($key);

This trusted method is should be called from an attribute class such as
C<Object::Relation::Meta::Attribute> to add a new container object for the current
class.  See C<contained_in>.

=cut

sub _add_container {
    my ( $self, $key ) = @_;
    $self->{contained_in}{$key} ||= Object::Relation::Meta->for_key($key);
    return $self;
}

=end private

=cut

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
