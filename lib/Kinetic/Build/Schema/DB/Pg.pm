package Kinetic::Build::Schema::DB::Pg;

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
use Carp;

=head1 Name

Kinetic::Build::Schema::DB::Pg - Kinetic PostgreSQL data store schema generation

=head1 Synopsis

  use Kinetic::Schema;
  my $kbs = Kinetic::Schema->new;
  $kbs->generate_to_file($file_name);

=head1 Description

This module generates and outputs to a file the schema information necessary
to create a PostgreSQL data store for a Kinetic application. See
L<Kinetic::Build::Schema|Kinetic::Build::Schema> and
L<Kinetic::Build::Schema::DB|Kinetic::Build::Schema::DB> for more information.

=cut

##############################################################################
# Instance Interface
##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 column_type

  my $type = $kbs->column_type($attr);

Pass in a Kinetic::Meta::Attribute::Schema object to get back the PostgreSQL
column type to be used for the attribute. The column types are optimized for
the best correspondence between the attribute types and the types supported by
PostgreSQL, plus data domains where appropriate (e.g., the "state" column type
is defined by a data domain defined by a statement returned by
C<setup_code()>).

=cut

my %types = (
    string   => 'TEXT',
    guid     => 'TEXT',
    boolean  => 'BOOLEAN',
    whole    => 'INTEGER',
    state    => 'STATE',
    datetime => 'TIMESTAMP',
);

sub column_type {
    my ($self, $attr) = @_;
    return "INTEGER" if $attr->references;
    my $type = $attr->type;
    return $types{$type} if $types{$type};
    croak "No such data type: $type" unless Kinetic::Meta->for_key($type);
}

##############################################################################

=head3 pk_column

  my $pk_sql = $kbs->pk_column($class);

Returns the SQL statement to create the primary key column for the table for
the Kinetic::Meta::Class::Schema object passed as its sole argument. If the
class has no concrete parent class, the primary key column expression will
set up a C<DEFAULT> statement to get its value from the "seq_kinetic" sequence.
Otherwise, it will be be a simple column declaration. The primary key constraint
is actually returned by C<constraints_for_class()>, and so is not included in
the expression returned by C<pk_column()>.

=cut

sub pk_column {
    my ($self, $class) = @_;
    return "id INTEGER NOT NULL" if $class->parent;
    return "id INTEGER NOT NULL DEFAULT NEXTVAL('seq_kinetic')";
}

##############################################################################

=head3 column_default

  my $default_sql = $kbs->column_default($attr);

Pass in a Kinetic::Meta::Attribute::Schema object to get back the default
value expression for the column for the attribute. Returns C<undef> (or an
empty list) if there is no default value on the column. Otherwise, it returns
the default value expression. Overrides the parent method to return
PostgreSQL-specific default expressions where appropriate (e.g., for boolean)
columns.

=cut

sub column_default {
    my ($self, $attr) = @_;
    return $self->SUPER::column_default($attr)
      unless $attr->type eq 'boolean';
    my $def = $attr->default;
    return unless defined $def;
    return $def ? 'DEFAULT true' : 'DEFAULT false';
}

##############################################################################

=head2 column_reference

  my $ref_sql = $kbs->column_reference($attr);

Overrides the parent method to return C<undef> (or an empty list). This is
because the column foreign key constraints are named and returned by
C<constraints_for_class()>, instead.

=cut

sub column_reference { return }

##############################################################################

=head3 index_on

  my $column = $kbs->index_on($attr);

Returns the name of the column on which an index will be generated for the
given Kinetic::Meta::Attribute::Schema object. Called by C<index_for_class()>
in the parent class. Overridden here to wrap the name in the PostgreSQL
C<LOWER()> function when the data type is a string.

=cut

sub index_on {
    my ($self, $attr) = @_;
    my $name = $attr->column;
    my $type = $attr->type;
    return "LOWER($name)" if $type eq 'string';
    return $name;
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

A primary key constraint.

=item *

A foreign key constraint from the primary key column to the table for a
concrete parent class.

=item *

Foreign key constraints to the tables for contained (referenced) objects.

=item *

"Once triggers", which prevent a value from being changed in a column after
the first time it has been set to a non-C<NULL> value.

=back

=cut

sub constraints_for_class {
    my ($self, $class) = @_;
    my $key = $class->key;
    my $table = $class->table;
    my $pk = $class->primary_key;

    # We always need a primary key.
    my @cons = (
        "ALTER TABLE $table\n  ADD CONSTRAINT $pk PRIMARY KEY (id);\n"
    );

    # Add a foreign key from the id column to the parent table if this
    # class has a parent table class.
    if (my $parent = $class->parent) {
        my $fk = $class->foreign_key;
        my $fk_table = $parent->table;
        push @cons, "ALTER TABLE $table\n"
          . "  ADD CONSTRAINT $fk FOREIGN KEY (id)\n"
          . "  REFERENCES $fk_table(id) ON DELETE CASCADE;\n";
    }

    # Add foreign keys for any attributes that reference other objects.
    for my $attr ($class->table_attributes) {
        my $ref = $attr->references or next;
        my $fk_table = $ref->table;
        my $del_action = uc $attr->on_delete;
        my $col = $attr->column;
        push @cons, "ALTER TABLE $table\n"
          . "  ADD CONSTRAINT fk_$col FOREIGN KEY ($col)\n"
          . "  REFERENCES $fk_table(id) ON DELETE $del_action;\n";
    }

    # Add any once triggers.
    push @cons, $self->once_triggers($class);

    return join "\n", @cons;
}

##############################################################################

=head3 once_triggers

  my $once_triggers_sql = $kbs->once_triggers($class);

Returns the SQL statements to generate trigger constraints for any "once"
attributes in the Kinetic::Meta::Class::Schema object passed as the sole
argument. The triggers are PL/pgSQL functions that ensure that, if a column
has been set to a non-C<NULL> value, it's value can never be changed again.
Called by C<constraints_for_class()>.

=cut

sub once_triggers {
    my ($self, $class) = @_;
    my @onces = grep { $_->once} $class->table_attributes
      or return;
    my $table = $class->table;
    my $key = $class->key;
    my @trigs;
    for my $attr (@onces) {
        my $col = $attr->column;
        # If the column is required, then the NOT NULL constraint will
        # handle that bit for us--no need to be redundant.
        my $if = $attr->required
          ? "OLD.$col <> NEW.$col OR NEW.$col IS NULL"
          : "OLD.$col IS NOT NULL AND (OLD.$col <> NEW.$col OR NEW.$col IS NULL)";
        push @trigs, qq{CREATE FUNCTION $key\_$col\_once() RETURNS trigger AS '
  BEGIN
    IF $if
        THEN RAISE EXCEPTION ''value of "$col" cannot be changed'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql;

CREATE TRIGGER $key\_$col\_once BEFORE UPDATE ON $table
    FOR EACH ROW EXECUTE PROCEDURE $key\_$col\_once();
};
    }
    return @trigs;
}

##############################################################################

=head3 insert_for_class

  my $insert_rule_sql = $kbs->insert_for_class($class);

Returns a PostgreSQL rule that manages C<INSERT> statements executed against
the view for the class. The rule ensures that the C<INSERT> statement updates
the table for the class as well as any parent classes. Contained objects
are ignored, and should be inserted separately.

=cut

sub insert_for_class {
    my ($self, $class) = @_;
    my $key = $class->key;
    my $func = 'NEXTVAL';

    # Output the INSERT rule.
    my $sql = "CREATE RULE insert_$key AS\n"
      . "ON INSERT TO $key DO INSTEAD (";
    for my $impl (reverse($class->parents), $class) {
        my $table = $impl->table;
        $sql .= "\n  INSERT INTO $table (id, "
          . join(', ', map { $_->column } $impl->table_attributes )
          . ")\n  VALUES ($func('seq_kinetic'), "
          . join(', ', map { "NEW." . $_->view_column } $impl->table_attributes)
          . ");\n";
        $func = 'CURRVAL';
    }

    return $sql . ");\n";
}

##############################################################################

=head3 update_for_class

  my $update_rule_sql = $kbs->update_for_class($class);

Returns a PostgreSQL rule that manages C<UPDATE> statements executed against
the view for the class. The rule ensures that the C<UPDATE> statement updates
the table for the class as well as any parent classes. Contained objects are
ignored, and should be updated separately.

=cut

sub update_for_class {
    my ($self, $class) = @_;
    my $key = $class->key;
    # Output the UPDATE rule.
    my $sql .= "CREATE RULE update_$key AS\n"
      . "ON UPDATE TO $key DO INSTEAD (";
    for my $impl (reverse ($class->parents), $class) {
        my $table = $impl->table;
        $sql .= "\n  UPDATE $table\n  SET    "
          . join(', ',
                 map { sprintf "%s = NEW.%s", $_->column, $_->view_column }
                   $impl->table_attributes)
          . "\n  WHERE  id = OLD.id;\n";
    }
    return $sql . ");\n";
}

##############################################################################

=head3 delete_for_class

  my $delete_rule_sql = $kbs->delete_for_class($class);

Returns a PostgreSQL rule that manages C<DELETE> statements executed against
the view for the class. Deletes simply pass through to the underlying table
for the class; parent object records are left in tact.

=cut

sub delete_for_class {
    my ($self, $class) = @_;
    my $key = $class->key;
    my $table = $class->table;
    # Output the DELETE rule.
    return "CREATE RULE delete_$key AS\n"
      . "ON DELETE TO $key DO INSTEAD (\n"
      . "  DELETE FROM $table\n"
      . "  WHERE  id = OLD.id;\n);\n";
}

##############################################################################

=head3 setup_code

  my $setup_sql = $kbs->setup_code;

Returns any SQL statements that must be executed after the creation of a
database, but before any database objects are created. This implementation
returns statement to perform the following tasks:

=over

=item *

Create a sequence, named "seq_kinetic", to be used for all primary key values
in the database.

=item *

Creates a domain, "state", that can be used as a column type in Kinetic
tables.

=back

=cut

sub setup_code {

'CREATE SEQUENCE seq_kinetic;

CREATE DOMAIN state AS SMALLINT NOT NULL DEFAULT 1
CONSTRAINT ck_state CHECK (
   VALUE BETWEEN -1 AND 2
);
';

}

1;
__END__

##############################################################################

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
