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

use version;
our $VERSION = version->new('0.0.1');

use base 'Kinetic::Build::Schema::DB';
use Kinetic::Meta;
use List::Util qw(first);
use Carp;

=head1 Name

Kinetic::Build::Schema::DB::SQLite - Kinetic SQLite data store schema generation

=head1 Synopsis

  use Kinetic::Schema;
  my $kbs = Kinetic::Schema->new;
  $kbs->generate_to_file($file_name);

=head1 Description

This module generates and outputs to a file the schema information necessary
to create a SQLite data store for a Kinetic application. See
L<Kinetic::Build::Schema|Kinetic::Build::Schema> and
L<Kinetic::Build::Schema::DB|Kinetic::Build::Schema::DB> for more information.

=cut

##############################################################################

##############################################################################
# Instance Interface
##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 column_type

  my $type = $kbs->column_type($attr);

Pass in a Kinetic::Meta::Attribute::Schema object to get back the SQLite
column type to be used for the attribute. The column types are optimized for
the best correspondence between the attribute types and the types supported by
SQLite (relatively speaking, of course, since SQLite's data types are actually
dynamic).

=cut

my %types = (
    string   => 'TEXT COLLATE nocase',
    uuid     => 'TEXT',
    boolean  => 'SMALLINT',
    whole    => 'INTEGER',
    state    => 'INTEGER',
    datetime => 'DATETIME',
);

sub column_type {
    my ($self, $attr) = @_;
    my $type = $attr->type;
    return $types{$type} if $types{$type};
    croak "No such data type: $type" unless Kinetic::Meta->for_key($type);
    return "INTEGER";
}

##############################################################################

=head3 index_for_attr

  my $index = $kbs->index_for_attr($class, $attr);

Returns the SQL that declares an SQL index. This implementation overrides that
in L<Kinetic::Build::Schema::DB|Kinetic::Build::Schema::DB> to remove the
C<UNIQUE> keyword from the declaration if the attribute in question is unique
but not distinct. The difference is that a unique attribute is unique only
relative to the C<state> attribute. A unique attribute can have more than one
instance of a given value as long as no more than one of them also has a state
greater than -1. For SQLite, this is handled by triggers.

=cut

sub index_for_attr {
    my ($self, $class, $attr) = @_;
    my $sql = $self->SUPER::index_for_attr($class => $attr);
    return $sql if $attr->distinct || !$attr->unique;
    # UNIQUE is handled by a constraint.
    $sql =~ s/UNIQUE\s+//;
    return $sql;
}


##############################################################################

=head3 constraints_for_class

  my $constraint_sql = $kbs->constraints_for_class($class);

Returns the SQL statements to create all of the constraints for the class
described by the Kinetic::Meta::Class::Schema object passed as the sole
argument. All of the constraint declaration statements will be returned in a
single string, each separated by a double "\n\n".

The constraint statements returned may include one or more of the following:

=over

=item *

A trigger to ensure that the value of a C<state> attribute is a valid state.

=item *

"Once triggers", which prevent a value from being changed in a column after
the first time it has been set to a non-C<NULL> value.

=item *

"Boolean triggers", which ensures that the value of a boolean column is either
0 or 1.

=item *

A foreign key constraint from the primary key column to the table for a
concrete parent class.

=item *

Foreign key constraints to the tables for contained (referenced) objects.

=back

=cut

sub constraints_for_class {
    my ($self, $class) = @_;
    my $key = $class->key;
    my $table = $class->table;

    # Start with any state, boolean, once, and unique triggers.
    my @cons = (
        $self->state_trigger(    $class ),
        $self->boolean_triggers( $class ),
        $self->once_triggers(    $class ),
        $self->unique_triggers(  $class ),
   );

    # Add FK constraint for subclases from id column to the parent table.
    if (my $parent = $class->parent) {
        push @cons, $self->_generate_fk($class, 'id', $parent)
    }

    # Add foreign keys for any attributes that reference other objects.
    for my $attr ($class->table_attributes) {
        my $ref = $attr->references or next;
        push @cons, $self->_generate_fk($class, $attr, $ref);
    }

    return join "\n", @cons;
}

##############################################################################

=head3 state_trigger

  my $state_trigger_sql = $kbs->state_trigger($class);

Returns an SQLite trigger to validate that the value of a state column in the
table representing the contents of the class represented by the
Kinetic::Meta::Class::Schema object passed as the sole argument. If the class
does not have a state attribute (because it inherits the state from a concrete
parent class), C<state_trigger()> will return C<undef> (or an empty list).

Called by C<constraints_for_class()>.

=cut

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
            "CREATE TRIGGER cki_$key\_$col\n"
          . "BEFORE INSERT ON $table\n"
          . "FOR EACH ROW BEGIN\n"
          . "    SELECT RAISE(ABORT, 'value for domain state violates "
          .                        qq{check constraint "ck_state"')\n}
          . "    WHERE  NEW.$col NOT BETWEEN -1 AND 2;\n"
          . "END;\n",
            "CREATE TRIGGER cku_$key\_$col\n"
          . "BEFORE UPDATE OF $col ON $table\n"
          . "FOR EACH ROW BEGIN\n"
          . "    SELECT RAISE(ABORT, 'value for domain state violates "
          .                        qq{check constraint "ck_state"')\n}
          . "    WHERE  NEW.$col NOT BETWEEN -1 AND 2;\n"
          . "END;\n";
    }
    return join "\n", @trigs;
}

##############################################################################

=head3 boolean_triggers

  my $boolean_trigger_sql = $kbs->boolean_triggers($class);

Returns the SQLite triggers to validate the values of any boolean type
attributes in the class are stored as either 0 or 1 (zero or one) in their
columns in the databse. If the class has no boolean attributes
C<boolean_triggers()> will return C<undef> (or an empty list).

Called by C<constraints_for_class()>.

=cut

sub boolean_triggers {
    my ($self, $class) = @_;
    my @bools = grep { $_->type eq 'boolean'} $class->table_attributes
      or return;
    my $table = $class->table;
    my $key = $class->key;
    my @trigs;
    for my $attr (@bools) {
        my $col = $attr->column;
        push @trigs,
            "CREATE TRIGGER cki_$key\_$col\n"
          . "BEFORE INSERT ON $table\n"
          . "FOR EACH ROW BEGIN\n"
          . "    SELECT RAISE(ABORT, 'value for domain boolean violates "
          .                        qq{check constraint "ck_boolean"')\n}
          . "    WHERE  NEW.$col NOT IN (1, 0);\n"
          . "END;\n",
            "CREATE TRIGGER cku_$key\_$col\n"
          . "BEFORE UPDATE OF $col ON $table\n"
          . "FOR EACH ROW BEGIN\n"
          . "    SELECT RAISE(ABORT, 'value for domain boolean violates "
          .                        qq{check constraint "ck_boolean"')\n}
          . "    WHERE  NEW.$col NOT IN (1, 0);\n"
          . "END;\n";
    }
    return join "\n", @trigs;
}

##############################################################################

=head3 once_triggers_sql

  my $once_triggers_sql_body = $kbs->once_triggers_sql(
    $key, $col, $table, $constraint
  );

This method is called by C<once_triggers()> to generate database specific
rules, functions, triggers, etc., to ensure that a column, once set to a
non-null value, can never be changed.

=cut

sub once_triggers_sql {
    my ($self, $key, $col, $table, $when) = @_;
    return "CREATE TRIGGER ck_$key\_$col\_once\n"
          . "BEFORE UPDATE ON $table\n"
          . "FOR EACH ROW BEGIN\n"
        . qq{    SELECT RAISE(ABORT, 'value of "$col" cannot be changed')\n}
          . "    WHERE  $when;\n"
          . "END;\n";
}

##############################################################################

=head3 unique_triggers

  my $unique_trigger_sql = $kbs->unique_triggers($class);

Returns the SQLite triggers to validate the values of any "unique" attributes
in the table representing the contents of the class represented by the
Kinetic::Meta::Class::Schema object passed as the sole argument. If the class
has no unique attributes C<unique_triggers()> will return C<undef> (or an
empty list).

Called by C<constraints_for_class()>.

=cut

sub unique_triggers {
    my ($self, $class) = @_;
    my @uniques = grep { $_->unique && !$_->distinct } $class->table_attributes
        or return;
    my $table       = $class->table;
    my $key         = $class->key;
    my $state_class = first { grep { $_->name eq 'state'} $_->table_attributes }
        reverse( $class->parents );
    my @trigs;
    if (!$state_class || $state_class eq $class) {
        # The unique cols are in the same table as state. Simple triggers.
        for my $attr (@uniques) {
            my $col = $attr->column;
            push @trigs,
                "CREATE TRIGGER cki_$key\_$col\_unique\n"
              . "BEFORE INSERT ON $table\n"
              . "FOR EACH ROW BEGIN\n"
              . "    SELECT RAISE (ABORT, 'column $col is not unique')\n"
              . "    WHERE  (\n"
              . "               SELECT 1\n"
              . "               FROM   $table\n"
              . "               WHERE  state > -1 AND $col = NEW.$col\n"
              . "               LIMIT  1\n"
              . "           );\n"
              . "END;\n",

                "CREATE TRIGGER cku_$key\_$col\_unique\n"
              . "BEFORE UPDATE ON $table\n"
              . "FOR EACH ROW BEGIN\n"
              . "    SELECT RAISE (ABORT, 'column $col is not unique')\n"
              . "    WHERE  (NEW.name <> OLD.name OR (\n"
              . "                NEW.state > -1 AND OLD.state < 0\n"
              . "            )) AND (\n"
              . "               SELECT 1 from $table\n"
              . "               WHERE  id <> NEW.id\n"
              . "                      AND $col = NEW.$col\n"
              . "                      AND state > -1\n"
              . "               LIMIT 1\n"
              . "           );\n"
              . "END;\n";
        }
    } else {
        # The state attribute is in a different table. Complex triggers.
        my $parent_table = $state_class->table;
        for my $attr (@uniques) {
            my $col = $attr->column;
            push @trigs,
                "CREATE TRIGGER cki_$key\_$col\_unique\n"
              . "BEFORE INSERT ON $table\n"
              . "FOR EACH ROW BEGIN\n"
              . "    SELECT RAISE (ABORT, 'column $col is not unique')\n"
              . "    WHERE  (\n"
              . "               SELECT 1\n"
              . "               FROM   $parent_table, $table\n"
              . "               WHERE  $parent_table.id = $table.id\n"
              . "                      AND $parent_table.state > -1\n"
              . "                      AND $table.$col = NEW.$col\n"
              . "               LIMIT  1\n"
              . "           );\n"
              . "END;\n",
                "CREATE TRIGGER cku_$key\_$col\_unique\n"
              . "BEFORE UPDATE ON $table\n"
              . "FOR EACH ROW BEGIN\n"
              . "    SELECT RAISE (ABORT, 'column $col is not unique')\n"
              . "    WHERE  NEW.$col <> OLD.$col AND (\n"
              . "               SELECT 1\n"
              . "               FROM   $parent_table, $table\n"
              . "               WHERE  $parent_table.id = $table.id\n"
              . "                      AND $parent_table.id <> NEW.id\n"
              . "                      AND $parent_table.state > -1\n"
              . "                      AND $table.$col = NEW.$col\n"
              . "               LIMIT  1\n"
              . "           );\n"
              . "END;\n",
                "CREATE TRIGGER ckp_$key\_$col\_unique\n"
              . "BEFORE UPDATE ON $parent_table\n"
              . "FOR EACH ROW BEGIN\n"
              . "    SELECT RAISE (ABORT, 'column $col is not unique')\n"
              . "    WHERE  NEW.state > -1 AND OLD.state < 0\n"
              . "           AND (SELECT 1 FROM $table WHERE id = NEW.id)\n"
              . "           AND (\n"
              . "               SELECT COUNT($col)\n"
              . "               FROM   $table\n"
              . "               WHERE  $col = (\n"
              . "                   SELECT $col FROM $table\n"
              . "                   WHERE id = NEW.id\n"
              . "               )\n"
              . "           ) > 1;\n"
              . "END;\n";
        }
    }
    return join "\n", @trigs;
}

##############################################################################

=head3 insert_for_class

  my $insert_trigger_sql = $kbs->insert_for_class($class);

Returns an SQLite trigger that manages C<INSERT> statements executed against
the view for the class. The trigger ensures that the C<INSERT> statement
updates the table for the class as well as any parent classes. Contained
objects are ignored, and should be inserted separately.

=cut

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
          . join(', ', map {
              if (my $def = $self->column_default($_)) {
                  $def =~ s/DEFAULT\s+//;
                  'COALESCE(NEW.' . $_->view_column . ", $def)";
              } elsif ($_->type eq 'uuid') {
                  'COALESCE(NEW.' . $_->view_column . ", UUID_V4())";
              } else {
                  'NEW.' . $_->view_column;
              }
          } $impl->table_attributes)
          . ");\n";
        $pk ||= 'last_insert_rowid(), ';
    }

    return $sql . "END;\n";

}

##############################################################################

=head3 update_for_class

  my $update_trigger_sql = $kbs->update_for_class($class);

Returns an SQLite trigger that manages C<UPDATE> statements executed against
the view for the class. The trigger ensures that the C<UPDATE> statement
updates the table for the class as well as any parent classes. Contained
objects are ignored, and should be updated separately.

=cut

sub update_for_class {
    my ($self, $class) = @_;
    my $key = $class->key;
    # Output the UPDATE trigger.
    my $sql .= "CREATE TRIGGER update_$key\n"
      . "INSTEAD OF UPDATE ON $key\nFOR EACH ROW BEGIN";
    for my $impl (reverse ($class->parents), $class) {
        my $table = $impl->table;
        $sql .= "\n  UPDATE $table\n  SET    "
          . join(
              ', ',
              map { sprintf "%s = NEW.%s", $_->column, $_->view_column }
              grep { $_->type ne 'uuid' } $impl->table_attributes
            )
          . "\n  WHERE  id = OLD.id;\n";
    }
    return $sql . "END;\n";
}

##############################################################################

=head3 delete_for_class

  my $delete_rule_sql = $kbs->delete_for_class($class);

Returns an SQLite rule that manages C<DELETE> statements executed against the
view for the class. Deletes simply pass through to the underlying table for
the class; parent object records are left in tact.

=cut

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

##############################################################################

=begin private

=head1 Private Interface

=head2 Private Instance Methods

=head3 _generate_fk

  my $fk_trigger_sql = $kbs->_generate_fk($class, $attr, $fk_class);

=cut

sub _generate_fk {
    my ($self, $class, $attr, $fk_class) = @_;
    my $key      = $class->key;
    my $table    = $class->table;
    my $fk_key   = $fk_class->key;
    my $fk_table = $fk_class->table;
    my ($fk, $col, $cascade) = ref $attr
      ? ($attr->foreign_key, $attr->column, uc $attr->on_delete eq 'CASCADE')
      : ($class->foreign_key, 'id', 1);
    my $null = ref $attr && $attr->required ? '' : "NEW.$col IS NOT NULL AND ";

    # We actually have three different triggers for each foreign key, so we
    # have to give each one a slightly different name.
    (my $fki = $fk) =~ s/_/i_/;
    (my $fku = $fk) =~ s/_/u_/;
    (my $fkd = $fk) =~ s/_/d_/;

    return (qq{CREATE TRIGGER $fki
BEFORE INSERT ON $table
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'insert on table "$table" violates foreign key constraint "$fk"')
    WHERE  $null(SELECT id FROM $fk_table WHERE id = NEW.$col) IS NULL;
END;
},

      qq{CREATE TRIGGER $fku
BEFORE UPDATE ON $table
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'update on table "$table" violates foreign key constraint "$fk"')
    WHERE  $null(SELECT id FROM $fk_table WHERE id = NEW.$col) IS NULL;
END;
},
      ($cascade
         ? qq{CREATE TRIGGER $fkd
BEFORE DELETE ON $fk_table
FOR EACH ROW BEGIN
  DELETE from $table WHERE $col = OLD.id;
END;
}
         : qq{CREATE TRIGGER $fkd
BEFORE DELETE ON $fk_table
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'delete on table "$fk_table" violates foreign key constraint "$fk"')
    WHERE  (SELECT $col FROM $table WHERE $col = OLD.id) IS NOT NULL;
END;
})
  );
}

1;
__END__

##############################################################################

=end private

=head1 Copyright and License

Copyright (c) 2004-2005 Kineticode, Inc. <info@kineticode.com>

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
