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
    boolean  => 'INTEGER',
    whole    => 'INTEGER',
    state    => 'INTEGER',
    datetime => 'TEXT',
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
    if (my $fk_table = $self->{$class->key}{table_data}{parent}) {
        return "id INTEGER NOT NULL PRIMARY KEY REFERENCES $fk_table(id)";
    } else {
        return "id INTEGER NOT NULL PRIMARY KEY";
    }
}

sub generate_insert_rule {
    my ($self, $class) = @_;
    my $key = $class->key;
    # Output the INSERT rule.
    $self->{$key}{buffer} .= "CREATE TRIGGER insert_$key\n"
      . "INSTEAD OF INSERT ON $key\nFOR EACH ROW BEGIN";
    my $pk = '';
    for my $table (@{$self->{table_data}{tables}}) {
        my $cols = $self->{table_data}{colmap}{$table} or next;
        $self->{$key}{buffer} .= "\n  INSERT INTO $table ("
          . ($pk ? 'id, ' : '')
          . join(', ', @$cols) . ")\n  VALUES ($pk"
          . join(', ', map { "NEW.$_" } @$cols) . ");\n";
        $pk ||= 'last_insert_rowid(), ';
    }
    $self->{$key}{buffer} .= "END;\n\n";
    return $self;
}

sub generate_update_rule {
    my ($self, $class) = @_;
    my $key = $class->key;
    # Output the UPDATE rule.
    $self->{$key}{buffer} .= "CREATE TRIGGER update_$key\n"
      . "INSTEAD OF UPDATE ON $key\nFOR EACH ROW BEGIN";
    for my $table (@{$self->{table_data}{tables}}) {
        my $cols = $self->{table_data}{colmap}{$table} or next;
        $self->{$key}{buffer} .= "\n  UPDATE $table\n  SET    "
          . join(', ', map { "$_ = NEW.$_" } @$cols)
          . "\n  WHERE  id = OLD.id;\n";
    }
    $self->{$key}{buffer} .= "END;\n\n";
    return $self;
}

sub generate_delete_rule {
    my ($self, $class) = @_;
    my $key = $class->key;
    # Output the DELETE rule.
    $self->{$key}{buffer} .= "CREATE TRIGGER delete_$key\n"
      . "INSTEAD OF DELETE ON $key\nFOR EACH ROW BEGIN\n"
      . "  DELETE FROM $self->{$key}{table_data}{name}\n"
      . "  WHERE  id = OLD.id;\nEND;\n\n";

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
