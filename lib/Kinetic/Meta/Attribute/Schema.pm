package Kinetic::Meta::Attribute::Schema;

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
use base 'Kinetic::Meta::Attribute';

=head1 Name

Kinetic::Meta::Attribute::Schema - Kinetic database store builder

=head1 Synopsis

  # Assuming MyThingy was generated by Kinetic::Meta and that we're building
  # a data store schema.
  my $class = MyThingy->my_class;

  print "\nAttributes:\n";
  for my $attr ($class->attributes) {
      print "  o ", $attr->name, $/;
      print "    Column: ", $attr->column, $/;
      if (my $idx = $attr->index) {
          print "    Index: $idx\n";
      }
      if (my $ref = $attr->references) {
          print "    References ", $ref->package, $/;
          print "       On Delete: ", $attr->on_delete, $/;
      }
  }

=head1 Description

This module is provides metadata for all Kinetic class attributes while
building a storage schema. Loading
L<Kinetic::Build::Schema|Kinetic::Build::Schema> causes it to be used instead
of L<Kinetic::Meta::Attribute|Kinetic::Meta::Attribute>. This is so that extra
metadata methods are available that are useful in constructing the schema, but
are not otherwise useful when an application is actually in use.

=cut

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Accessor Methods

=head3 references

  my $references = $attr->references;

If the attribute is a reference to a class of Kinetic object, this method
returns a Kinetic::Meta::Class::Schema object representing that class. This is
useful for creating views that include a referenced object.

=cut

sub references { shift->{references} }

##############################################################################

=head3 on_delete

  my $on_delete = $attr->on_delete;

Returns a string describing what to do with an object that links to another
object when that other object is deleted. This is only relevant when the
attribute object represents that relationship (that is, when C<references()>
returns true). The possible values for this attributes are:

=over

=item CASCADE

=item RESTRICT

=item SET NULL

=item SET DEFAULT

=item NO ACTION

=back

The default is "CASCADE".

=cut

sub on_delete { shift->{on_delete} }

##############################################################################

=head3 column

  my $column = $attr->column;

Returns the name of the database table column for this attribute. The table
column name will generally be the same as the attribute name, but for
contained objects, in which the column is a foreign key column, the name will
be the attribute name plus "_id".

=cut

sub column {
    my $self = shift;
    return $self->name unless $self->references;
    return $self->name . '_id'; # XXX should be '__id'?
}

##############################################################################

=head3 view_column

  my $view_column = $attr->view_column;

Returns the name of the database view column for this attribute. The view
column name will generally be the same as the column name, but for attributes
that reference other objects, the name will be the class key for the contained
object plus "__id". IOW, contained object foreign key columns have a
double-underscore in views and a single underscore in tables.

=cut

sub view_column {
    my $self = shift;
    return $self->name unless $self->references;
    return $self->name . '__id';
}

##############################################################################

=head3 foreign_key

  my $fk = $class->foreign_key;

Attributes that are references to another Kinetic object will need to have a
foreign key constraint. This method returns the name of that constraint, which
starts with "fk_", then the key name the current class, then the name of the
current attribute, followed by '_id'.

For example, the foreign key for the "contact_type" attribute of the "contact"
class is named "fk_contact_contact_type_id" and applies to the "contact" table
and references, of course, the "id" column of the "contact_type" table.

If the C<parent()> method returns a false value, this method returns C<undef>.

=cut

sub foreign_key {
    my $self = shift;
    return unless $self->references;
    return 'fk_' . $self->class->key . '_' . $self->name . '_id';
}

##############################################################################

=head2 Instance Methods

=head3 index

  my $index = $attr->index;
  $idx = $attr->index($class);

Returns the name of an index for the attribute, if the attribute requires an
index. The name of the index is "idx_" plus the class key plus the name of the
attribute. Pass in a Kinetic::Meta::Class object to use its key for the class
key part of the name. This is useful for creating indexes for classes that
inherit from the class for which the attribute was defined, and prevents
duplicately named indexes when more thane one class inherits from a class with
an attribute requiring an index.

=cut

sub index {
    my ($self, $class) = @_;
    return unless $self->indexed || $self->references;
    my $key = $class ? $class->key : $self->class->key;
    my $name = $self->column;
    return "idx_$key\_$name";
}

##############################################################################

=head3 build

This private method overrides the parent C<build()> method in order to gather
extra metadata information necessary for building a data store schema.

=cut

sub build {
    my $self = shift;
    $self->SUPER::build(@_);
    if ($self->{references} = Kinetic::Meta->for_key($self->type)) {
        # XXX We should probably default to RESTRICT here.
        $self->{on_delete} ||= 'CASCADE';
    } else {
        delete $self->{on_delete};
    }
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
