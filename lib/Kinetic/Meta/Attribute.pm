package Kinetic::Meta::Attribute;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use base 'Class::Meta::Attribute';
use Kinetic::Util::Context;
use Kinetic::Meta::Type;
use Kinetic::Util::Constants qw($OBJECT_DELIMITER);
use Widget::Meta;
use aliased 'Kinetic::Util::Collection';
use aliased 'Kinetic::Util::Iterator';

=head1 Name

Kinetic::Meta::Attribute - Kinetic object attribute introspection

=head1 Synopsis

  # Assuming MyThingy was generated by Kinetic::Meta.
  my $class = MyThingy->my_class;
  my $thingy = MyThingy->new;

  print "\nAttributes:\n";
  for my $attr ($class->attributes) {
      print "  o ", $attr->name, " => ", $attr->get($thingy), $/;
      if ($attr->authz >= Class::Meta::SET && $attr->type eq 'string') {
          $attr->get($thingy, 'hey there!');
          print "    Changed to: ", $attr->get($thingy) $/;
      }
  }

=head1 Description

This class inherits from L<Class::Meta::Attribute|Class::Meta::Attribute> to
provide attribute metadata for Kinetic classes. See the
L<Class::Meta|Class:Meta> documentation for details on meta classes. See the
L<"Instance Interface"> section for the attributes added to
Kinetic::Meta::Attribute in addition to those defined by
Class::Meta::Attribute.

=head1 Dynamic APIs

This class supports the dynamic loading of extra methods specifically designed
to be used with particular Kinetic data store implementations. See
L<Kinetic::Meta|Kinetic::Meta> for details. The supported labels are:

=over

=item :with_dbstore_api

Adds a _column() and _view_column() methods to return the names of table and
view columns in the database.

=back

=cut

sub import {
    my ($pkg, $api_label) = @_;
    return unless $api_label;
    if ($api_label eq ':with_dbstore_api') {
        return if defined(&_column);
        # Create methods specific to database stores.
        no strict 'refs';
        *{__PACKAGE__ . '::_column'} = sub {
              my $self = shift;
              if (my $acts_as = $self->acts_as) {
                  return $acts_as->column;
              }
              return $self->name unless $self->references;
              return $self->name . '_id';
        };

        *{__PACKAGE__ . '::_view_column'} = sub {
            my $self = shift;
            if (my $acts_as = $self->acts_as) {
                my $key = $self->delegates_to->key;
                return $key . $OBJECT_DELIMITER . $acts_as->name
                    . ($acts_as->references ? $OBJECT_DELIMITER . 'id' : '');
            }
            return $self->name unless $self->references;
            return $self->name . $OBJECT_DELIMITER . 'id';
        };
    }
}

##############################################################################

=head1 Class Interface

=head2 Constructor

=head3 new

This constructor overrides the parent class constructor from
L<Class::Meta::Attribute|Class::Meta::Attribute> and adds the following
behaviors:

=over

=item *

Makes sure that distinct attributes are also unique.

=item *

Makes sure that unique attributes are always indexed.

=item

Ensures that the C<relationship> parameter is either undefined or one of a
valid list of values. See L<relationship|"relationship"> for a list of valid
relationships.

=item *

Sets the C<index> attribute to a true value if the C<unique> attribute is set.

=item *

Sets the C<persistent> attribute to true if it has not been specified.

=back

=cut

my %RELATIONSHIPS = (
    has             => undef,
    type_of         => undef,
    part_of         => undef,
    references      => undef,
    extends         => undef,
    child_of        => undef,
    mediates        => undef,
    has_many        => 1,     # one-to-many
    references_many => 1,     # many-to-many
    part_of_many    => 1,     # many-to-many
);

sub new {
    my ($class, $containing_class, @args) = @_;
    @args = $class->_prepare_kinetic($containing_class, @args);
    my $self = $class->SUPER::new($containing_class, @args);
    $self->{unique}      ||= $self->{distinct};
    $self->{indexed}     ||= $self->{unique};
    $self->{persistent}    = 1 unless defined $self->{persistent};
    $self->{widget_meta} ||= Kinetic::Meta::Widget->new( type => 'text' );

    if (exists $self->{relationship}) {
        $self->class->handle_error(
           qq{I don't know what a "$self->{relationship}" relationship is} # "
        ) unless exists $RELATIONSHIPS{$self->{relationship}}
    }

    return $self;
}

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Accessor Methods

=head3 label

  my $label = $attr->label;

Returns the localized form of the label for the attribute, such as "Name".

=cut

sub label {
    Kinetic::Util::Context->language->maketext(shift->SUPER::label);
}

##############################################################################

=head3 widget_meta

  my $wm = $attr->widget_meta;

Returns a L<Widget::Meta|Widget::Meta> object describing the type of widget to
be used to allow input for an attribute. If no widget is provided, then no
field is required.

=cut

sub widget_meta { shift->{widget_meta} }

##############################################################################

=head3 unique

  my $unique = $attr->unique;

Returns true if an attribute is unique across all objects of a class, as long
as its state is greater than DELETED--that is, INACTIVE, ACTIVE, or PERMANENT.
In other words, An object with a unique attribute may have an value for that
attribute that is the same as the value of the same attribute in one or more
deleted objects.

=cut

sub unique { shift->{unique} }

##############################################################################

=head3 distinct

  my $distinct = $attr->distinct;

Returns true if an attribute is distinct across all objects of a class. This
differs from the C<unique> attribute in ensuring that, regardless of an
object's state, only one instance of a value for the attribute can exist in
the data store.

=cut

sub distinct { shift->{distinct} }

##############################################################################

=head3 indexed

  my $indexed = $attr->indexed;

Returns true if an attribute is indexed in the data store, and false if it is
not. Note that this is a suggestion only, since not all data stores
necessarily support indexes. Always returns a true value if the C<unique>
attribute is set to a true value.

=cut

sub indexed { shift->{indexed} }

##############################################################################

=head3 persistent

  my $persistent = $attr->persistent;

Returns true if an attribute is persistent--that is, stored by the data store.
This attribute is true by default, and can only be set to false in the call to
the constructor.

=cut

sub persistent { shift->{persistent} }

##############################################################################

=head3 references

  my $references = $attr->references;

If the attribute is a reference to a class of Kinetic object, this method
returns a Kinetic::Meta::Class::Schema object representing that class. This is
useful for creating views that include a referenced object.

=cut

sub references { shift->{references} }

##############################################################################

=head3 delegates_to

  my $delegates_to = $attr->delegates_to;

If the attribute transparently delegates to an object of another class, this
method will return the Kinetic::Meta::Class object describing that class. This
attribute is implicitly set by Kinetic::Meta for classes that either extend
another class or reference other classes via the "type_of" relationship. In
those cases, Kinetic::Meta will create extra attributes to delegate to the
attributes of the referenced or extended classes, and those attributes will
have their C<delegates_to> attributes set accordingly.

=cut

sub delegates_to { shift->{delegates_to} }

##############################################################################

=head3 acts_as

  my $acts_as = $attr->acts_as;

If C<delegates_to()> returns a Kinetic::Meta::Class object representing the
class of object to which the attribute delegates, C<acts_as()> returns the
Kinetic::Meta::Attribute object to which this attribute corresponds. That is,
this attribute I<acts as> the attribute returned here.

=cut

sub acts_as { shift->{acts_as} }

##############################################################################

=head3 relationship

  my $relationship = $attr->relationship;

This attribute describes the relationship of a referencing attribute and the
class that references it. At an abstract level, there are fundamentally two
different types of relationships: A relationship to a single object and a
relationship to a collection of objects. However, these two broad categories
break down into subcategories that might affect the API of a class. For
example, a simple "has" or "references" relationship is just that, simple: the
contained object can be fetched using the accessor, and then the attributes of
that object can be accessed directly. An "extends" or "type_of" relationship
is more complex. In these cases, the containing class will have extra
accessors that delegate to the contained object, thereby making the containing
class essentially an extension of the contained class.

In all cases, the permissions that a user has to access a contained object or
collection of contained objects will be evaluated independent of the
permissions she has to the containing object. Delegated accessors may provide
independent implicit access to the contained object, but access to the
contained object itself (fetched via its attribute accessor) will be evaluated
on its own.

For attributes that reference other attributes, the default relationship will
be "has". Returns C<undef> for attributes that do not reference other Kinetic
objects.

The supported relationships are:

=over

=item has

Defines a simple "has a" relationship. The contained object and its attributes
will only be available via the attribute accessor method. No other accessors
will be generated. For all practical purposes "has" objects should be
considered to be a part of the whole object that contains them.

=for StoreComment

View triggers should detect when the has ID is NULL and do an insert when it
is and an update when it isn't. Hrm...will need to figure out how to handle
populating IDs, then...

=item type_of

Since objects of one class can be types of only one other class, this
relationship can only be specified when creating the new class:

  my $km = Kinetic::Meta->new(
          key => 'contact',
      type_of => 'contact_type'
  );

An attribute will automatically be created that defines the type of the
containing object. Given the above example, a Kinetic::Contact object has an
attribute for the Kinetic::Type::Contact object that defines its type. The
attributes of the type object will be available to users via read-only
accessors (such as C<name()> or, if the contact class inherits from another
class that defines a C<name()> attribute, C<contact_type_name()>). In this
way, a user has read permission to see the attributes of the type object only
via the read-only delegated accessors, but not necessarily to the contained
type object itself (since permission to access that object is evaluated
independently of the containing object).

=for StoreComment

These objects should be saved independent of their containing objects, since
they will usually not be changed.

=item part_of

The current object is a part of the contained object. For example, a document
is a part of one and only one site. The contained object and its attributes
will only be available via the attribute accessor method. No other accessors
will be generated.

=for StoreComment

These objects should be saved independent of their containing objects, since
they will usually not be changed.

=item references

A simple reference. The contained object is simply referenced by the
containing object. For example, an element object may reference another
element object. In other words, relationship has no inherent meaning, it
simply I<is>. The contained object and its attributes will only be available
via the attribute accessor method. No other accessors will be generated.

=for StoreComment

These objects should be saved independent of their containing objects, since
they will usually not be changed.

=item extends

A class can optionally extend one other class, but can do so only when
creating the new class:

  my $km = Kinetic::Meta->new(
          key => 'usr',
      extends => 'person'
  );

The containing object extends the contained object. In this example,
Kinetic::Party::User extends Kinetic::Party::Person. This is similar in
principal to inheritance, but uses composition to prevent overly complex
inheritance relationships. It also allows more than one containing object to
refer to the same contained object. The "extends" relationship assumes that
the attribute will be set once and only once (that is, the C<once> attribute
of the attribute object will be true).

The attributes of the contained objects will be available via read/write
accessors in the containing class that will simply delegate to the contained
object. Likewise, the methods of the contained objects will be available via
delegating methods in the containing class. The naming conventions for each
apply as described for the delegating accessors and methods in "type_of"
relationships. Thus a user will have implicit read/write access to an extended
object via the delegated accessors and methods (assuming that she has
read/write permission to the extending object, of course), but the user's
permission to access the contained object itself will be managed independent
of the user's permissions to the containing object.

=for StoreComment

The insert view trigger will need to detect if the contained object ID is
NULL, and do an insert it if isn't and an update if it is. The update view
trigger can always just do an update.

=item child_of

The containing object is a child of the contained object. For example, a
category will always be a child a parent category. The contained object and
its attributes will only be accessible by fetching the contained object from
its attribute accessor object, or by a L<Class::Path|Class::Path> method.

=for StoreComment

Database relationships of tree structures TBD.

=item mediates

The containing object mediates a relationship for the contained object. This
is specifically for managing "has_many" or "references_many" relationships,
where the objects being referenced need to have extra metadata associated with
their relationship. For example, a Subelement object mediates the relationship
between a parent element and a subelement. Like "extends", the "mediates"
relationship assumes "once".

The attributes of the contained object will be accessible via read/write
delegation methods. Likewise, the methods of the contained objects will be
available via delegating methods in the containing class. The naming
conventions for each apply as described for the delegating accessors and
methods in "type_of" relationships. The permissions evaluated for the
contained object will implicitly be applied to the mediating object, as well,
since it functions as an stand-in for the contained object. This design is
similar in principal to "extends", but exists solely for the purpose of
mediating specific relationships.

=for StoreComment

The insert view trigger will need to detect if the contained object ID is
NULL, and do an insert it if isn't and an update if it is. The update view
trigger can always just do an update.

=item has_many

The contained object is a collection of objects that are directly related to
the containing object. For example, Kinetic::Party has many Kinetic::Contact
objects. The accessor will return a
L<Kinetic::Util::Collection|Kinetic::Util::Collection> of the contained
objects. The permissions applied to the containing object will extend to the
contained objects, as well, since they are considered to be a part of the
containing object.

=for StoreComment

The schema for the many relationships is TBD, and depends on whether they're
relating to objects or mediators.

=item references_many

The containing object references a collection of contained objects. This
relationship differs from that of "has_many" in that the "has_many" objects
are only associated with the object that they are a part of, while the objects
associated via a "references_many" relationship can be referenced by many
different objects. For example, a document can reference one or more
categories. Thus, the permissions to access each of the contained objects will
be evaluated independent of the permission granted to the containing object.

=item part_of_many

The containing object is a part of any number of contained objects of the
specified type. For example, a document type may be a part of many different
sites. The permissions to access each of the contained objects will be
evaluated independent of the permission granted to the containing object.

=back

=cut

sub relationship { shift->{relationship} }

##############################################################################

=head3 collection_of

  my $collection = $attr->collection_of;

If an attribute represents a collection, this method will return the class
object for that collection.

=cut

sub collection_of { shift->{collection} }

##############################################################################

=head3 collection_view

  my $view_name = $attr->collection_view;

If an attribute represents a collection, this method will return the name of
the view for that collection.

=cut

sub collection_view { shift->{coll_view} }

##############################################################################

=head3 collection_table

  my $table_name = $attr->collection_table;

If an attribute represents a collection, this method will return the name of
the table for that collection.

=cut

sub collection_table { '_' . shift->{coll_view} }

##############################################################################

=head2 Instance methods

=head3 raw

  my $raw_value = $attr->raw($thingy);

This method returns the raw value of an attribute. This value will most often
be the same as that returned by C<get()>, but when the attribute fetched is an
object, it might return a raw value suitable for serialization or storage in a
database. For example, if the attribute was a
L<Kinetic::DataType::DateTime|Kinetic::DataType::DateTime> object, the
C<get()> method will return the object, but the C<raw()> method might return an
ISO-8601 formatted string using the UTC time zone, instead.

=cut

sub raw {
    my $self = shift;
    my $code = $self->{_raw} or $self->class->handle_error(
        sprintf 'Cannot get raw value for attribute "%s"', $self->name
    );
    goto &$code;
}

##############################################################################

=head3 store_raw

  my $store_raw_value = $attr->store_raw($thingy);

This method returns the raw value of an attribute properly formatted for
serialization to the current data store. This value will most often be the
same as that returned by C<raw()>, but different data stores require different
formats, C<store_raw()> will return the representation appropriate for the
current data store. For example, if the attribute was a
L<Kinetic::DataType::Duration|Kinetic::DataType::Duration> object, C<get()>
would of course return the object, C<raw()> would return an ISO-8601 string
representation, and C<store_raw()> would return one string representation for
the PostgreSQL data store, and a 0-padded ISO-8601 string for all other data
stores.

=cut

sub store_raw {
    my $self = shift;
    my $code = $self->{_store_raw} or $self->class->handle_error(
        sprintf 'Cannot get store raw value for attribute "%s"', $self->name
    );
    goto &$code;
}

##############################################################################

=head3 bake

  $attr->bake($thingy, $value);

Similar to C<raw()>, this method is the corresponding mutator.  This should
always work:

  $attr->bake($thing, $attr->raw($thing));

=cut

sub bake {
    my $self = shift;
    my $code = $self->{_bake} or $self->class->handle_error(
        sprintf 'Cannot set bake value for attribute "%s"', $self->name
    );
    goto &$code;
}

##############################################################################

=head3 build

This private method overrides the parent C<build()> method in order to set up
the C<raw()> and C<store_raw()> accessor values.

=cut

sub build {
    my $self = shift;

    $self->SUPER::build(@_);

    my $type = Kinetic::Meta::Type->new($self->type);

    # Create the attribute object raw(), store_raw(), and bake() code
    # references.
    if ($self->authz >= Class::Meta::READ) {
        my $get = $type->make_attr_get($self);
        if (my $raw = $type->raw) {
            $self->{_raw} = sub { $raw->($get->(shift)) };
        } else {
            $self->{_raw} = $get;
        }
        if (my $store_raw = $type->store_raw) {
            $self->{_store_raw} = sub { $store_raw->($get->(shift)) };
        } else {
            $self->{_store_raw} = $self->{_raw};
        }

        if ($self->authz >= Class::Meta::WRITE) {
            my $set = $type->make_attr_set($self);
            if (my $bake = $type->bake) {
                $self->{_bake} = sub { $set->($_[0], $bake->($_[1])) };
            } else {
                $self->{_bake} = $set;
            }
        }
    }

    return $self;
}

##############################################################################

=begin private

=head1 Private Interface

=head2 Private Instance Methods

=head3 _prepare_kinetic

 sub new {
     my ($class, $containing_class, @args) = @_;
     @args = $class->_prepare_kinetic( $containing_class, @args );
     $class->SUPER::new(@args);
     ...
 }

When creating a new C<Kinetic::Meta::Attribute> object, some attributes of the
object are Kinetic specific. The handling of these attributes should generally
be done prior to the SUPER constructor being called. Returns the new arguments
for the parent constructor.

=cut

sub _prepare_kinetic {
    my ( $class, $containing_class, %arg_for ) = @_;

    # Figure out if the attribute is a reference to another object in a
    # Kinetic::Meta class. Use Class::Meta->for_key to avoid
    # Kinetic::Meta->for_key's exception.
    if ($arg_for{references} = Class::Meta->for_key($arg_for{type})) {
        my $rel = $arg_for{relationship} ||= 'has';
        $arg_for{once} = 1 if $rel eq 'extends' || $rel eq 'mediates';
    } else {
        delete $arg_for{relationship};
    }

    # Just return unless there is a many relationship.
    return %arg_for
        unless exists $arg_for{relationship}
        && $RELATIONSHIPS{$arg_for{relationship}};

    my $class_key        = $containing_class->key;
    $arg_for{collection} = delete $arg_for{references};
    $arg_for{coll_view}  = "$class_key\_coll_$arg_for{name}";

    # The contained class must know which classes contain it.
    Kinetic::Meta->for_key($arg_for{type})->_add_container($class_key);

    # Dynamically create collection subclass if it does't already exist.
    my $coll_pkg = Collection;
    (my $coll = $arg_for{type})
        =~ s{^(?<!$coll_pkg\::)([[:word:]]+)}{$coll_pkg\::\u$1};
    my $type = $1;
    $arg_for{type} = "collection_$type";
    unless (eval { $coll->isa($coll_pkg) }) {
        NOSTRICT: {
            no strict 'refs';
            @{"$coll\::ISA"} = $coll_pkg;
        }

        Kinetic::Meta::Type->add(
            key     => $arg_for{type},
            name    => "\u$type collection",
            builder => 'Kinetic::Meta::AccessorBuilder',
            check   => $coll,
        );
    }
    $arg_for{default} ||= eval "sub { $coll->empty }";
    return %arg_for;
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
