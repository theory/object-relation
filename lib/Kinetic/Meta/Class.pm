package Kinetic::Meta::Class;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use base 'Class::Meta::Class';
use Kinetic::Util::Context;
use Kinetic::Util::Exceptions qw/throw_fatal/;
use List::Util qw(first);

=head1 Name

Kinetic::Meta::Class - Kinetic class metadata class.

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
class metadata for Kinetic classes. See the L<Class::Meta|Class::Meta>
documentation for details on meta classes. See the L<"Accessor Methods"> for
the additional attributes.

=cut

=for private

The C<import()> method is merely a placeholder to ensure that
L<Kinetic::Meta|Kinetic::Meta> can dispatch its import symbols to a variety
of classes and "just work".  This class is specifically documented as accepting
those symbols.  See the documentation for L<Kinetic::Meta|Kinetic::Meta> for
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
            $self->{$rel} = Kinetic::Meta->for_key($ref) unless ref $ref;
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
    Kinetic::Util::Context->language->maketext( shift->SUPER::name );
}

##############################################################################

=head3 plural_name

  my $plural_name = $class->plural_name;

Returns the localized plural form of the name of the class, such as
"Thingies".

=cut

sub plural_name {
    Kinetic::Util::Context->language->maketext( shift->{plural_name} );
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

Returns a Kinetic::Meta::Class object representing a class that this class
extends. Extension is different than inheritance, in that the object in the
extended class can correspond to one or more instances of objects in the
extending class.

=cut

sub extends { shift->{extends} }

##############################################################################

=head3 type_of

  my $type_of  = $class->type_of;

Returns a Kinetic::Meta::Class object representing a class that this class is
a type of.

=cut

sub type_of { shift->{type_of} }

##############################################################################

=head3 mediates

  my $mediates  = $class->mediates;

Returns a Kinetic::Meta::Class object representing a class that this class
mediates.

=cut

sub mediates { shift->{mediates} }

##############################################################################

=head2 Instance Methods

=head3 ref_attributes

  my @ref_attrs = $class->ref_attributes;

Returns a list of attributes that reference other Kinetic::Meta objects.
Equivalent to

  my @ref_attrs = grep { $_->references } $self->attributes;

only more efficient, thanks to build-time caching.

=cut

sub ref_attributes { @{ shift->{ref_attrs} } }

##############################################################################

=head3 direct_attributes

  my @direct_attrs = $class->direct_attributes;

Returns a list of attributes that do not reference other Kinetic::Meta
objects. Equivalent to

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
        # Fake out Kinetic::Store so that we can get at trusted attributes.
        package Kinetic::Store;
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
            first { $_->package ne 'Kinetic' } @{ $self->{direct_attrs} }
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
C<Kinetic::Meta::Attribute> to add a new container object for the current
class.  See C<contained_in>.

=cut

sub _add_container {
    my ( $self, $key ) = @_;
    $self->{contained_in}{$key} ||= Kinetic::Meta->for_key($key);
    return $self;
}

=end private

=cut

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

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
