package Kinetic::Meta::Class::Schema;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use base 'Kinetic::Meta::Class';

=head1 Name

Kinetic::Meta::Class::Schema - Kinetic database store builder

=head1 Synopsis

See L<Kinetic::Meta::Class|Kinetic::Meta::Class>.

=head1 Description

This module is provides metadata for all Kinetic classes while building a
storage schema. Loading L<Kinetic::Store::Schema|Kinetic::Store::Schema>
causes it to be used instead of
L<Kinetic::Meta::Class|Kinetic::Meta::Class>. This is so that extra metadata
methods are available that are useful in constructing the schema, but are not
otherwise useful when an application is actually in use.

At this point, those attributes tend to be database-specific. Once other types
of data stores are added (XML, LDAP, etc.), other attributes may be added to
allow their schemas to be built, as well.

=cut

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 parent

  my $parent = $class->parent;

Returns the L<Class::Meta::Class|Class::Meta::Class> object representing the
immediate parent class of the class, provided that that parent is a concrete
class rather than an abstract class. Classes for which the parent is abstract
will return C<undef>.

=cut

sub parent { shift->{parent} }

##############################################################################

=head3 parents

  my @parents = $class->parents;

Overrides the C<parents()> method in L<Class::Meta|Class::Meta> to return only
concrete parents, since abstract parents aren't really relevant for building a
data store schema.

=cut

sub parents { @{shift->{parents}} }

##############################################################################

=head3 table

  my $table = $class->table;

Returns the name of the table to be used for this class in the database.

Classes with no concrete parent class will be named for the key name of the
classes they represent, prepended by an underscore, such as "_party". Classes
that inherit from a concrete class will be named for their inheritance
relationship, such as "party_person" for the person class.

=cut

sub table { shift->{table} }

##############################################################################

=head3 view

  my $view = $class->view;

Returns the name of the database view to be used for this class. Views, which
represent a class of objects and often build up their representations from a
number of different tables, shall be named for the key names of the classes
they represent. Typical names include "party", "usr", "person",
"contact_type", etc.

=cut

sub view { shift->key }

##############################################################################

=head3 primary_key

  my $pk = $class->primary_key;

Primary key constraints are named for the class key preceded by "pk_". For
example, the primary key for the "person" class shall be named "pk_person" and
the primary key for the "party" class shall be named "pk_party".

=cut

sub primary_key { 'pk_' . shift->key }

##############################################################################

=head3 foreign_key

  my $fk = $class->foreign_key;

For classes that inherit from another concrete class, their primary ID column
will also be a foreign key to primary ID column in the parent class' table.
This method returns the name of the foreign key constraint for such classes.
The foreign key constraint name starts with "pfk_", then the key name of the
parent class, then the key name of the current class, and ends with "_id".

For example, the foreign key applied to the primary key column created for the
"person" class to point to the primary key for the "party" class (the class
from which "person" inherits) shall be named "pfk_person_party_id", apply to
the "id" column of the "party_person" table, and refer to the "id" column of
the "_party" table.

If the C<parent()> method returns a false value, this method returns C<undef>.

=cut

sub foreign_key {
    my $self = shift;
    my $parent = $self->parent or return;
    return 'pfk_' . $parent->key . '_' . $self->key . '_id';
}

##############################################################################

=head3 table_attributes

  my @attrs = $class->table_attributes;

Returns the
L<Kinetic::Meta::Attribute::Schema|Kinetic::Meta::Attribute::Schema> objects
for the attributes that correspond to columns in the table used for the class.
Thus, it excludes attributes from concrete parent classes and from any
extended classes, since they're implemented in their own tables. See
C<parent_attributes()> to get a list of the attributes of concrete parent
classes and C<view_attributes()> for a list of table attributes I<and>
extended class attributes. It also excludes the C<id> attribute, since it just
gets in the way when building schemas.

=cut

sub table_attributes {
    my $self = shift;
    grep { ! $_->collection_of } @{$self->{cols}}
}

##############################################################################

=head3 persistent_attributes

  my @attrs = $class->persistent_attributes;

Overrides the parent version to exclude the C<id> attribute, since it just
gets in the way when building schemas.

=cut

sub persistent_attributes {
    grep { $_->name ne 'id' } shift->SUPER::persistent_attributes(@_)
}

##############################################################################

=head3 direct_attributes

  my @attrs = $class->direct_attributes;

Overrides the parent version to exclude the C<id> attribute, since it just
gets in the way when building schemas.

=cut

sub direct_attributes {
    grep { $_->name ne 'id' } shift->SUPER::direct_attributes(@_)
}

##############################################################################

=head2 Instance Methods

=head3 parent_attributes

  my $attrs = $class->parent_attributes($class);

Pass the Kinetic::Meta::Class::Schema object of a concrete parent class to get
back a list of the attributes for that class. This is useful for constructing
views to represent inherited classes.

=cut

sub parent_attributes {
    my ($self, $class) = @_;
    my $key = $class->key;
    return unless $self->{parent_attrs}{$key};
    return @{$self->{parent_attrs}{$key}};
}

##############################################################################

=head3 build

This private method overrides the parent C<build()> method in order to gather
extra metadata information necessary for building a data store schema.

=cut

sub build {
    my $self = shift;
    $self->SUPER::build(@_);
    my $key = $self->key;
    $self->{table} = "_$key";

    my (@cols, %parent_attrs);
    my ($root, @parents) = grep { !$_->abstract }
      reverse $self->SUPER::parents;

    if ($root) {
        # There are concrete parent classes from which we need to inherit.
        my $table = $root->key;
        $self->{parent} = $root;
        $parent_attrs{$table} = [_col_attrs($root)];

        for my $impl (@parents, $self) {
            my $impl_key    = $impl->key;
            $self->{parent} = $impl unless $impl_key eq $key;
            $table         .= "_$impl_key";
            @cols = grep { $_->class->key eq $impl_key } _col_attrs($impl);
            # Copy @cols to prevent spillover into subclasses.
            $parent_attrs{$impl_key} = [@cols];
        }

        $self->{table} = $table;
        unshift @parents, $root;
    } else {
        # It has no parent class, so its column attributes are all of its
        # attributes.
        @cols = _col_attrs($self);
    }

    $self->{cols}         = \@cols;
    $self->{parent_attrs} = \%parent_attrs;
    $self->{parents}      = \@parents;

    return $self;
}

=begin private

=head1 Private Interface

=head2 Private Functions

=head3 _col_attrs

  my @col_attrs = _col_attrs($class);

Returns a list of perstent attributes that are not the "id" attribute and that
do not delegate to another object attribute.

=cut

sub _col_attrs {
    my $class = shift;
    # Skip over ID and attributes that delegate to another class.
    return grep {
        !$_->delegates_to && $_->name ne 'id'
    } $class->persistent_attributes
}

1;
__END__

##############################################################################

=end private

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
