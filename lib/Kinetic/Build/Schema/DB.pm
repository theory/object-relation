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

  use Kinetic::Build::Schema;
  my $sg = Kinetic::::Build::Schema->new;
  $sg->write_schema($file_name);

=head1 Description

This is an abstract base class for the generation and output of a database
schema to build a data store for a Kinetic application. See
L<Kinetic::Build::Schema|Kinetic::Build::Schema> for more information
and the subclasses of Kinetic::Schema::DB for database-specific
implementations.

=head1 Naming Conventions

The naming conventions for database objects are defined by the schema meta
classes. See L<Kinetic::Meta::Class::Schema|Kinetic::Meta::Class::Schema> and
L<Kinetic::Meta::Attribute::Schema|Kinetic::Meta::Attribute::Schema> for the
methods that define these names, and documentation for the naming conventions.

=cut

##############################################################################
# Instance Interface
##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 schema_for_class

  my @sql = $kbs->schema_for_class($class);

Returns a list of the SQL statements that can be used to build the tables,
indexes, and constraints necessary to manage a class in a database.

=cut

sub schema_for_class {
    my ($self, $class) = @_;
    return grep { $_ }
      $self->table_for_class($class),
      $self->indexes_for_class($class),
      $self->constraints_for_class($class),
      $self->view_for_class($class),
      $self->insert_for_class($class),
      $self->update_for_class($class),
      $self->delete_for_class($class);
}

##############################################################################

=head3 behaviors_for_class

  my @behaviors = $self->behaviors_for_class($class);

Takes a class object.  Returns a list of SQL statements for:

=over 4

=item * indexes

  $kbs->indexes_for_class($class);

=item * constraints

  $kbs->constraints_for_class($class);

=item * view

  $kbs->view_for_class($class);

=item * inserts

  $kbs->insert_for_class($class);

=item * updates

  $kbs->update_for_class($class);

=item * deletes

  $kbs->delete_for_class($class);

=back

This is primarily a handy wrapper method for fetching these values all at once
when a schema is being created in a new database.

=cut

sub behaviors_for_class {
    my ($self, $class) = @_;
    return 
      $self->indexes_for_class($class),
      $self->constraints_for_class($class),
      $self->view_for_class($class),
      $self->insert_for_class($class),
      $self->update_for_class($class),
      $self->delete_for_class($class);
}

##############################################################################

=head3 table_for_class

  $kbs->table_for_class($class);

This method takes a class object.  It returns a C<CREATE TABLE> sql statement
for the class;

=cut

sub table_for_class {
    my ($self, $class) = @_;
    my $sql = $self->start_table($class);
    $sql .= "    " . join ",\n    ", $self->columns_for_class($class);
    return $sql . $self->end_table($class);
}

##############################################################################

=head3 start_table

  $kbs->start_table($class);

This method is called by C<table_for_class()> to generate the opening
statement for creating a table.

=cut

sub start_table {
    my ($self, $class) = @_;
    my $table = $class->table;
    return "CREATE TABLE $table (\n";
}

##############################################################################

=head3 end_table

  $kbs->end_table($class);

This method is called by C<table_for_class()> to generate the closing
statement for creating a table.

=cut

sub end_table {
    return "\n);\n";
}

##############################################################################

=head3 output_columns

  $kbs->output_columns($class);

This method outputs all of the columns necessary to represent a class in a
table.

=cut

sub columns_for_class {
    my ($self, $class) = @_;
    return (
        $self->pk_column($class),
        map { $self->generate_column($class, $_) }
          $class->table_attributes
    );
}

##############################################################################

=head3 generate_column

  my $sql = $kbs->generate_column($class, $attr);

This method returns the SQL representing a single column declaration in a
table, where the column holds data represented by the
C<Kinetic::Meta::Attribute> object passed to the method.

=cut

sub generate_column {
    my ($self, $class, $attr) = @_;
    my $null = $self->column_null($attr);
    my $def  = $self->column_default($attr);
    my $fk   = $self->column_reference($attr);
    my $type = $self->column_type($attr);
    my $name = $attr->column;
    return "$name $type"
      . ($null ? " $null" : '')
      . ($def ? " $def" : '')
      . ($fk ? " $fk" : '')
}

sub column_type { return "TEXT" }

sub column_null {
    my ($self, $attr) = @_;
    return "NOT NULL" if $attr->required;
    return '';
}

my %num_types = (
    integer => 1,
    whole   => 1,
    boolean => 1,
);

sub column_default {
    my ($self, $attr) = @_;
    my $def = $attr->{default};
    return unless defined $def && ref $def ne 'CODE';
    my $type = $attr->type;

    # Return the raw value for numeric data types.
    return "DEFAULT $def" if $num_types{$type};
    return "DEFAULT " . ($def + 0) if $type eq 'state';

    # Otherwise, assume that it's a string.
    $def =~ s/'/''/g;
    return "DEFAULT '$def'";
}

sub column_reference {
    my ($self, $attr) = @_;
    my $ref = $attr->references or return;
    my $fk_table = $ref->table;
    return "REFERENCES $fk_table(id) ON DELETE " . uc $attr->on_delete;
}

sub pk_column {
    my ($self, $class) = @_;
    if (my $parent = $class->parent) {
        my $fk_table = $parent->table;
        return "id INTEGER NOT NULL PRIMARY KEY REFERENCES $fk_table(id) "
          . "ON DELETE CASCADE";
    }
    return "id INTEGER NOT NULL PRIMARY KEY";
}

sub indexes_for_class {
    my ($self, $class) = @_;
    my $table = $class->table;
    my $sql;
    for my $attr (grep { $_->index } $class->table_attributes) {
        my $unique = $attr->unique ? ' UNIQUE' : '';
        my $name = $attr->index($class);
        my $on = $self->index_on($attr);
        $sql .= "CREATE$unique INDEX $name ON $table ($on);\n";
    }
    return $sql;
}

sub index_on { pop->column }

sub constraints_for_class {
    my ($self, $class) = @_;
    return;
}

sub view_for_class {
    my ($self, $class) = @_;
    my $key = $class->key;
    my $table = $class->table;

    my (@tables, @cols, @wheres);
    if (my @parents = reverse $class->parents) {
        my $last;
        for my $parent (@parents) {
            push @tables, $parent->key;
            push @wheres, "$last.id = $tables[-1].id" if $last;
            $last = $tables[-1];
            push @cols,
              $self->view_columns($last, \@tables, \@wheres,
                                  $class->parent_attributes($parent));

        }
        unshift @cols, "$tables[0].id";
        push @wheres, "$last.id = $table.id";
    } else {
        @cols = ("$table.id");
    }
    push @tables, $class->table;
    push @cols, $self->view_columns($table, \@tables, \@wheres,
                                    $class->table_attributes);

    my $cols = join ', ', @cols;
    my $from = join ', ', @tables;
    my $where = join ' AND ', @wheres;
    my $name = $class->key;

    # Output the view.
    return "CREATE VIEW $name AS\n"
      . "  SELECT $cols\n"
      . "  FROM   $from"
      . ($where ?  "\n  WHERE  $where;" : (';'))
      . "\n";
}

sub view_columns {
    my ($self, $table, $tables, $wheres) = (shift, shift, shift, shift);
    my @cols;
    for my $attr (@_) {
        my $col = $attr->column;
        if (my $ref = $attr->references) {
            my $key = $ref->key;
            if ($attr->required) {
                push @$tables, $key;
                push @$wheres, "$table.$col = $key.id";
            } else {
                my $join = "$table LEFT JOIN $key ON $table.$col = $key.id";
                # Either change the existing table name to the join table
                # syntax, or, if it is already joined to another table (and
                # therefore is not the whole string), then push the new join
                # string onto the table list.
                unless (grep { s/^$table$/$join/} @$tables) {
                    push @$tables, $join;
                }
            }
            push @cols, "$table.$col", $self->map_ref_columns($ref, $key);
        } else {
            push @cols, "$table.$col";
        }
    }
    return @cols;
}

sub map_ref_columns {
    my ($self, $class, $key, @keys) = @_;
    my @cols;
    my ($ckey, $q) = @keys ? (join ('.', @keys, ''), '"') : ('', '');
    for my $attr ($class->attributes) {
        my $col = $attr->column;
        push @cols, qq{$key.$q$ckey$col$q AS "$key.$ckey$col"};
        if (my $ref = $attr->references) {
            push @cols, $self->map_ref_columns($ref, $key, @keys, $ref->key);
        }
    }
    return @cols;
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
