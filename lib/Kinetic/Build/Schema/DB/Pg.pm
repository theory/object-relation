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
    boolean  => 'BOOLEAN',
    whole    => 'INTEGER',
    state    => 'STATE',
    datetime => 'TIMESTAMP',
);

sub column_name {
    my ($self, $attr) = @_;
    return $self->SUPER::column_name($attr) if $types{$attr->type};
    # Assume it's an object reference.
    return $attr->name . '_id';
}

sub column_type {
    my ($self, $attr) = @_;
    my $type = $attr->type;
    return $types{$type} if $types{$type};
    croak "No such data type: $type" unless Kinetic::Meta->for_key($type);
    return "INTEGER";
}

sub pk_column {
    my ($self, $class) = @_;
    my $key = $class->key;
    if ($self->{$key}{table_data}{parent}) {
        return "id INTEGER NOT NULL";
    } else {
        return "id INTEGER NOT NULL DEFAULT NEXTVAL('seq_kinetic')";
    }
}

# Pg handles FKs in constraints.
sub column_reference { return }

sub index_on {
    my ($self, $col) = @_;
    my $name = $col->{name};
    return $col->{attr}->type eq 'string' || $col->{attr}->type eq 'guid'
      ? "LOWER($name)"
      : $name;
}

sub generate_constraints {
    my ($self, $class) = @_;
    my $key = $class->key;
    my $table = $self->{$key}{table_data}{name};
    my @cons = ( "ALTER TABLE $table\n"
                 . "  ADD CONSTRAINT pk_$key\_id PRIMARY KEY (id);"
    );

    if (my $fk_table = $self->{$key}{table_data}{parent}) {
        push @cons, "ALTER TABLE $table\n"
          . "  ADD CONSTRAINT pfk_$fk_table\_id FOREIGN KEY (id)\n"
          . "  REFERENCES $fk_table(id) ON DELETE CASCADE;";
    }
    my $cols = $self->{$key}{col_data};
    for my $col (grep { $_->{refs} && $_->{attr}->class->key eq $key} @$cols) {
        my $fk_key = $col->{refs}->key;
        my $fk_table = $self->{$fk_key}{table_data}{name};
        my $del_action = uc $col->{attr}->on_delete;
        push @cons, "ALTER TABLE $table\n"
          . "  ADD CONSTRAINT fk_$fk_key\_id FOREIGN KEY ($fk_key\_id)\n"
          . "  REFERENCES $fk_table(id) ON DELETE $del_action;";
    }

    $self->{$key}{buffer} .= join "\n\n", @cons, '';
    return $self;
}

sub generate_insert_rule {
    my ($self, $class) = @_;
    my $key = $class->key;
    # Output the INSERT rule.
    $self->{$key}{buffer} .= "CREATE RULE insert_$key AS\n"
      . "ON INSERT TO $key DO INSTEAD (";
    my $func = 'NEXTVAL';
    for my $table (@{$self->{table_data}{tables}}) {
        my $cols = $self->{table_data}{colmap}{$table} or next;
        $self->{$key}{buffer} .= "\n  INSERT INTO $table (id, "
          . join(', ', @$cols) . ")\n  VALUES ($func('seq_kinetic'), "
          . join(', ', map { "NEW.$_" } @$cols) . ");\n";
        $func = 'CURRVAL';
    }
    $self->{$key}{buffer} .= ");\n\n";
    return $self;
}

sub generate_update_rule {
    my ($self, $class) = @_;
    my $key = $class->key;
    # Output the UPDATE rule.
    $self->{$key}{buffer} .= "CREATE RULE update_$key AS\n"
      . "ON UPDATE TO $key DO INSTEAD (";
    for my $table (@{$self->{table_data}{tables}}) {
        my $cols = $self->{table_data}{colmap}{$table} or next;
        $self->{$key}{buffer} .= "\n  UPDATE $table\n  SET    "
          . join(', ', map { "$_ = NEW.$_" } @$cols)
          . "\n  WHERE  id = OLD.id;\n";
    }
    $self->{$key}{buffer} .= ");\n\n";
    return $self;
}

sub generate_delete_rule {
    my ($self, $class) = @_;
    my $key = $class->key;
    # Output the DELETE rule.
    $self->{$key}{buffer} .= "CREATE RULE delete_$key AS\n"
      . "ON DELETE TO $key DO INSTEAD (\n"
      . "  DELETE FROM $self->{$key}{table_data}{name}\n"
      . "  WHERE  id = OLD.id;\n);\n\n";

    return $self;
}

sub start_schema {

'
CREATE SEQUENCE seq_kinetic;

CREATE DOMAIN state AS INT2 NOT NULL DEFAULT 1
CHECK(
   VALUE BETWEEN -1 AND 2
);';
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
