package Kinetic::Build::Schema::DB::SQLite;

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
use base 'Kinetic::Build::Schema::DB';
use Kinetic::Meta;
use Carp;

=head1 Name

Kinetic::Build::Schema::DB::SQLite - Kinetic SQLite data store schema generation

=head1 Synopsis

  use Kinetic::Schema;
  my $sg = Kinetic::Schema->new;
  $sg->generate_to_file($file_name);

=head1 Description

This module generates and outputs to a file the schema information necessary
to create a PostgreSQL data store for a Kinetic application. See
L<Kinetic::Build::Schema|Kinetic::Build::Schema> and
L<Kinetic::Build::Schema::DB|Kinetic::Build::Schema::DB> for more
information.

=cut

my %types = (
    string   => 'TEXT',
    guid     => 'TEXT',
    boolean  => 'SMALLINT',
    whole    => 'INTEGER',
    state    => 'INTEGER',
    datetime => 'TEXT',
);

sub column_type {
    my ($self, $attr) = @_;
    my $type = $attr->type;
    return $types{$type} if $types{$type};
    croak "No such data type: $type" unless Kinetic::Meta->for_key($type);
    return "INTEGER";
}

sub constraints_for_class {
    my ($self, $class) = @_;
    my $key = $class->key;
    my $table = $class->table;

    # Start with a state trigger, if there is a state column, and a boolean
    # trigger, if there is a boolean column.
    my @cons = ($self->state_trigger($class), $self->boolean_trigger($class));

    # Add a foreign key from the id column to the parent table if this
    # class has a parent table class.
    if (my $parent = $class->parent) {
        push @cons, $self->generate_fk($class, 'id', $parent)
    }

    # Add foreign keys for any attributes that reference other objects.
    for my $attr ($class->table_attributes) {
        my $ref = $attr->references or next;
        push @cons, $self->generate_fk($class, $attr->column, $ref);
    }

    return join "\n", @cons;
}

sub generate_fk {
    my ($self, $class, $col, $fk_class) = @_;
    my $key = $class->key;
    my $table = $class->table;
    my $fk_key = $fk_class->key;
    my $fk_table = $fk_class->table;
    my $prefix = $col eq 'id' ? 'pfk' : 'fk';
    return (qq{CREATE TRIGGER ${prefix}i_$key\_$col
BEFORE INSERT ON $table
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT id FROM $fk_table WHERE id = NEW.$col) IS NULL
    THEN RAISE(ABORT, 'insert on table "$table" violates foreign key constraint "$prefix\_$key\_$col"')
  END;
END;
},

      qq{CREATE TRIGGER ${prefix}u_$key\_$col
BEFORE UPDATE ON $table
FOR EACH ROW BEGIN
  SELECT CASE WHEN (SELECT id FROM $fk_table WHERE id = NEW.$col) IS NULL
    THEN RAISE(ABORT, 'update on table "$table" violates foreign key constraint "$prefix\_$key\_$col"')
  END;
END;
},

      qq{CREATE TRIGGER ${prefix}d_$key\_$col
BEFORE DELETE ON $fk_table
FOR EACH ROW BEGIN
    DELETE from $table WHERE $col = OLD.id;
END;
});
}

sub state_trigger {
    my ($self, $class) = @_;
    my @states = grep { $_->type eq 'state'} $class->table_attributes
      or return;
    my $table = $class->table;
    my $key = $class->key;
    my @trigs;
    for my $attr (@states) {
        my $col = $attr->column;
        push @trigs,
            "CREATE TRIGGER ck_$key\_$col\n"
          . "BEFORE INSERT on $table\n"
          . "FOR EACH ROW BEGIN\n"
          . "  SELECT CASE\n"
          . "    WHEN NEW.$col NOT BETWEEN -1 AND 2\n"
          . "    THEN RAISE(ABORT, 'value for domain state violates "
          .                      qq{check constraint "ck_state"')\n}
          . "  END;\n"
          . "END;\n";
    }
    return join "\n", @trigs;
}

sub boolean_trigger {
    my ($self, $class) = @_;
    my @bools = grep { $_->type eq 'boolean'} $class->table_attributes
      or return;
    my $table = $class->table;
    my $key = $class->key;
    my @trigs;
    for my $attr (@bools) {
        my $col = $attr->column;
        push @trigs,
            "CREATE TRIGGER ck_$key\_$col\n"
          . "BEFORE INSERT on $table\n"
          . "FOR EACH ROW BEGIN\n"
          . "  SELECT CASE\n"
          . "    WHEN NEW.$col NOT IN (1, 0)\n"
          . "    THEN RAISE(ABORT, 'value for domain boolean violates "
          .                      qq{check constraint "ck_boolean"')\n}
          . "  END;\n"
          . "END;\n";
    }
    return join "\n", @trigs;
}

sub insert_for_class {
    my ($self, $class) = @_;
    my $key = $class->key;

    # Output the INSERT trigger.
    my $sql = "CREATE TRIGGER insert_$key\n"
      . "INSTEAD OF INSERT ON $key\nFOR EACH ROW BEGIN";
    my $pk = '';
    for my $impl (reverse($class->parents), $class) {
        my $table = $impl->table;
        $sql .= "\n  INSERT INTO $table ("
          . ($pk ? 'id, ' : '')
          . join(', ', map { $_->column } $impl->table_attributes )
          . ")\n  VALUES ($pk"
          . join(', ', map { "NEW." . $_->column } $impl->table_attributes)
          . ");\n";
        $pk ||= 'last_insert_rowid(), ';
    }

    return $sql . "END;\n";

}

sub update_for_class {
    my ($self, $class) = @_;
    my $key = $class->key;
    # Output the UPDATE trigger.
    my $sql .= "CREATE TRIGGER update_$key\n"
      . "INSTEAD OF UPDATE ON $key\nFOR EACH ROW BEGIN";
    for my $impl (reverse ($class->parents), $class) {
        my $table = $impl->table;
        $sql .= "\n  UPDATE $table\n  SET    "
          . join(', ', map { "$_ = NEW.$_" } map { $_->column } $impl->table_attributes)
          . "\n  WHERE  id = OLD.id;\n";
    }
    return $sql . "END;\n";
}

sub delete_for_class {
    my ($self, $class) = @_;
    my $key = $class->key;
    my $table = $class->table;
    # Output the DELETE rule.
    return "CREATE TRIGGER delete_$key\n"
      . "INSTEAD OF DELETE ON $key\n"
      . "FOR EACH ROW BEGIN\n"
      . "  DELETE FROM $table\n"
      . "  WHERE  id = OLD.id;\n"
      . "END;\n";
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
