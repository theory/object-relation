package Kinetic::Meta::Class::Schema;

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
use base 'Kinetic::Meta::Class';

=head1 Name

Kinetic::Meta::Class::Schema - Kinetic database store builder

=head1 Synopsis

See L<Kinetic::Meta::Class|Kinetic::Meta::Class>.

=head1 Description

This module is provides metadata for all Kinetic classes while building a
storage schema. Loading L<Kinetic::Build::Schema|Kinetic::Build::Schema>
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

Classes will no concrete parent class will be named for the key name of the
classes they represent, prepended by an undderscore, such as "_party". Classes
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

Primary key constraints are named for the class key plus "_id" (the primary
key column name), and be preceded by "pk_". For example, the primary key for
the "person" class shall be named "pk_person_id" and the primary key for the
"party" class shall be named "pk_party_id".

=cut

sub primary_key { 'pk_' . shift->key . '_id' }

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
for the attributes the correspond to columns in the table used for the
class. Thus, it excludes attributes from concrete parent classe, since they're
implemented in their own tables. See C<parent_attributes()> to get a list of
the attributes of concrete parent classes.

=cut

sub table_attributes { @{shift->{cols}} }

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
        $parent_attrs{$table} = [$root->attributes];

        for my $impl (@parents, $self) {
            my $impl_key = $impl->key;
            $self->{parent} = $impl unless $impl_key eq $key;
            $table .= "_$impl_key";
            @cols = grep { $_->class->key eq $impl_key } $impl->attributes;
            $parent_attrs{$impl_key} = [@cols];
        }

        $self->{table} = $table;
        unshift @parents, $root;
    } else {
        # It has no parent class, so its column attributes are all of its
        # attributes.
        @cols = $self->attributes;
    }

    $self->{cols} = \@cols;
    $self->{parent_attrs} = \%parent_attrs;
    $self->{parents} = \@parents;
    return $self;
}


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
