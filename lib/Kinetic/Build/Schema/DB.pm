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

=head1 Naming Conventions

The rules for naming database objects are as follows.

=over

=item Classes

All objects that represent a class of objects shall be named for the key names
of the classes they represent. The objects that represent classes will
typically be either tables or views. Typical names include "party", "usr",
"person", "contact_type", etc.

=item Tables

Tables will either be named for the key name of the classes they represent,
such as "party", or will be named for their inheritance relationship, such as
"party_person". Any class that has attributes that are actually other objects
such as a "contact" class having a "contact_type" attribute, the table will be
named with a preceding underscore, e.g., "_contact".

=item Indexes

Indexes shall be named for the class key name plus the column(s) that they put
an index one. They shall be preceded with the string "idx_" or, for unique
indexes, "udx_". For example, an index for the "last_name" attribute of the
"person" class would be named "idx_person_last_name" and be applied to the
"party_person" table. A unique index on the GUID attribute of the "party"
class would be named "udx_party_guid".

=item Primary Keys

For database platforms that support naming primary keys, they shall be named
for the class key plus "_id" (the primary key column name), and be preceded by
"pk_". For example, the primary key for the "person" class shall be named
"pk_person_id" and be applied to the "party_person" table. The primary key for
the "party" class shall be named "pk_party_id" and be applied to the "party"
table.

=item Foreign Keys

For database platforms that support the naming of foreign keys, they shall be
named for the class and attribute they reference, and be preceded by "fk_".
For example, the foreign key for the "contact_type" attribute of the "contact"
class shall be named "fk_contact_type_id" and be applied to the "contact"
table and referencing, of course, the "id" column of the "contact_type" table.

=item Foreign Keys on Primary Key Columns

For database platforms that support the naming of foreign keys, the foreign
keys created to point to the primary key of a parent table, and therefore
applied to the primary key of the referring table, shall be named for the
class that they refer to. They will also be preceeded by the string "pfk_".

For example, the foreign key applied to the primary key column created for the
"person" class to point to the primary key for the "party" class (the class
from which "person" inherits) shall be named "pfk_party_id", apply to the "id"
column of the "party_person" table, and refer to the "id" column of the party
table. For multiple inheritance, the foreign key shall use the key name of the
class from which it inherits, but will of course point to the "id" column of
the base (concrete) class. For example, the foreign key for "usr" class, which
inherits from the "person" class, shall be named "pfk_person_id" but actually
point to the "id" column of the "party" table.

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
    return join "\n",
      grep { $_ }
      $self->table_for_class($class),
      $self->indexes_for_class($class),
      $self->constraints_for_class($class),
      $self->view_for_class($class),
      $self->insert_for_class($class),
      $self->update_for_class($class),
      $self->delete_for_class($class);
}

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

sub column_default {
    my ($self, $attr) = @_;
    my $def = $attr->{default};
    return unless defined $def && ref $def ne 'CODE';
    my $type = $attr->type;

    # Return the raw value for numeric data types.
    return "DEFAULT $def" if $type eq 'integer' || $type eq 'whole';
    return "DEFAULT " . ($def + 0) if $type eq 'state';

    # Otherwise, assume that it's a string.
    $def =~ s/'/''/g;
    return "DEFAULT '$def'";
}

sub column_reference {
    my ($self, $attr) = @_;
    my $ref = $attr->references or return;
    my $fk_table = $ref->table;
    return "REFERENCES $fk_table(id)";
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
            push @$tables, $key;
            push @$wheres, "$table.$col = $key.id";
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
