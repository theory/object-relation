package Kinetic::Build::Schema::DB;

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
use base 'Kinetic::Build::Schema';

=head1 Name

Kinetic::Build::Schema::DB - Kinetic database data store schema generation

=head1 Synopsis

  use Kinetic::Schema;
  my $sg = Kinetic::Schema->new;
  $sg->generate_to_file($file_name);

=head1 Description

This is an abstract base class for the generation and output of a database
schema to build a data store for a Kinetic application. See
L<Kinetic::Build::Schema|Kinetic::Build::Schema> for more information
and the subclasses of Kinetic::Schema::DB for database-specific
implementations.

=cut

##############################################################################
# Instance Interface
##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 schema_for_class

  my $sql = $kbs->schema_for_class($class);

Returns a string with the SQL statements that can be used to build the tables,
indexes, and constraints necessary to manage a clas in a database.

=cut

sub schema_for_class {
    my ($self, $class) = @_;
    $class = $class->my_class
      unless UNIVERSAL::isa($class, 'Kinetic::Meta::Class');
    my $key = $class->key;

    # Prepare the attributes.
    $self->prepare_attributes($class);
    # Generate the table.
    $self->table_for_class($class);
    # Generate the indexes.
    $self->output_indexes($class);
    # Generate the constraints.
    $self->output_constraints($class);

    return delete($self->{"$key\_table"})
      . ($self->{"$key\_indexes"}
           ?  "\n" . delete($self->{$class->key . '_indexes'}) . "\n"
           : '')
      . ($self->{"$key\_constraints"}
           ?  "\n" . delete($self->{$class->key . '_constraints'}) . "\n"
           : '');
}

##############################################################################

=head3 table_for_class

  $kbs->table_for_class($class);

Called by C<schema_for_class()> this method uses a number of other methods to
generate the SQL for the main table for a class. The SQL will be stored in the
C<Kinetic::Build::Schema> object under the class key plus the string "_table".

=cut

sub table_for_class {
    my ($self, $class) = @_;
    $self->start_table($class);
    $self->output_columns($class);
    $self->end_table($class);
}

sub prepare_attributes {
    my ($self, $class) = @_;
    my $key = $class->key;
    if (my @parents = grep { ! $_->abstract } $class->parents) {
        # This class inherits from one or more other classes.
        # XXX This is probably naive.
        $self->{"$key\_pk_fk_class"} = $parents[-1];
        $self->{"$key\_attrs"} =
          [ grep { $_->class->key eq $key } $class->attributes ];
    } else {
        $self->{"$key\_attrs"} = [ $class->attributes ];
    }

}

sub pk_column {
    my ($self, $class) = @_;
    if (my $fk_class = $self->{$class->key . "_pk_fk_class"}) {
        my $table = $fk_class->key;
        push @{$self->{$class->key . '_fk_classes'}}, $fk_class;
        return "$table\_id INTEGER NOT NULL PRIMARY KEY";
    } else {
        return "id INTEGER NOT NULL PRIMARY KEY DEFAULT NEXTVAL('seq_kinetic')";
    }
}

##############################################################################

=head3 start_table

  $kbs->start_table($class);

This method is called by C<table_for_class()> to generate the opening
statement for creating a table.

=cut

sub start_table {
    my ($self, $class) = @_;
    my $key = $class->key;
    $self->{"$key\_table"} = "CREATE TABLE $key (\n";
    return $self;
}

##############################################################################

=head3 end_table

  $kbs->end_table($class);

This method is called by C<table_for_class()> to generate the closing
statement for creating a table.

=cut

sub end_table {
    my ($self, $class) = @_;
    $self->{$class->key . '_table'} .= "\n);\n";
    return $self;
}

##############################################################################

=head3 output_columns

  $kbs->output_columns($class);

This method outputs all of the columns necessary to represent a class in a
table.

=cut

sub output_columns {
    my ($self, $class) = @_;
    my $key = $class->key;
    $self->{"$key\_table"} .= join ",\n    ",
      "    " . $self->pk_column($class),
      map { $self->generate_column($_) } @{$self->{"$key\_attrs"}};
    return $self;
}

##############################################################################

=head3 generate_column

  my $sql = $kbs->generate_column($attr);

This method returns the SQL representing a single column declaration in a
table, where the column holds data represented by the
C<Kinetic::Meta::Attribute> object passed to the method.

=cut

sub generate_column {
    my ($self, $attr, $buffers) = @_;
    return $self->column_name($attr)
      . $self->column_type($attr)
      . $self->column_null($attr)
      . $self->column_default($attr);
}

sub column_name {
    my ($self, $attr) = @_;
    return "    " . $attr->name;
}

sub column_type { return " TEXT" }
sub column_null {
    my ($self, $attr) = @_;
    return " NOT NULL" if $attr->required;
    return '';
}

sub column_default {
    my ($self, $attr) = @_;
    my $def = $attr->store_default;
    return defined $def ? " DEFAULT '$def'" : '';
}

sub output_indexes {
    my ($self, $class) = @_;
    my $key = $class->key;
    $self->{"$key\_indexes"} =
      join "\n", map { $self->output_index($key, $_) } @{$self->{"$key\_attrs"}};
    return $self;
}

sub output_index {
    my ($self, $table, $attr) = @_;
    return unless $attr->indexed || $attr->unique;
    my $name = $self->index_name($table, $attr);
    my $on = $self->index_on($attr);
    my $unique = $attr->unique ? ' UNIQUE' : '';
    return "CREATE$unique INDEX $name ON $table ($on);";
}

sub index_name {
    my ($self, $table, $attr) = @_;
    return ($attr->unique ? 'u' : 'i')
      . "dx_$table\_" . $attr->name;
}

sub index_on {
    my ($self, $attr) = @_;
    return $attr->name;
}

sub output_constraints { return }

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
