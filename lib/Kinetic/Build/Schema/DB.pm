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

    $self->prepare_class_data($class);
    # Generate the table.
    $self->generate_table($class);
    # Generate the indexes.
    $self->generate_indexes($class);
    # Generate the constraints.
    $self->generate_constraints($class);
    $self->generate_view($class);
    return $self->{$key}{buffer};
}

##############################################################################

sub prepare_class_data {
    my ($self, $class) = @_;
    my $key = $class->key;
    my $table_data = {
        name => $key,
    };

    my @cols;
    my ($root, @parents) = grep { !$_->abstract } reverse $class->parents;

    if ($root) {
        # There are concrete parent classes from which we need to inherit.
        my $table = $root->key;
        $table_data->{parent} = $table;
        push @cols, $self->prepare_column($root, $_, $table)
          for $root->attributes;

        for my $impl (@parents, $class) {
            my $impl_key = $impl->key;
            $table_data->{parent} = $impl_key unless $impl_key eq $key;
            $table .= "_$impl_key";
            push @cols, $self->prepare_column($impl, $_, $table)
              for grep { $_->class->key eq $impl_key } $impl->attributes;
        }
        $table_data->{name} = $table;
    } else {
        push @cols, $self->prepare_column($class, $_, $key)
          for $class->attributes;
        if (grep { $_->{refs} } @cols) {
            $table_data->{name} = "_$key";
            $table_data->{refs} = 1;
            $_->{table} = $table_data->{name} for @cols;
        }
    }

    $self->{$key} = {
        table_data => $table_data,
        col_data   => \@cols
    };
    return $self;
}

sub prepare_column {
    my ($self, $class, $attr, $table) = @_;
    return {
        attr  => $attr,
        table => $table,
        class => $class,
        name  => $self->column_name($attr),
        type  => $self->column_type($attr),
        refs  => $self->column_references($attr),
    };
}

sub pk_column { "id INTEGER PRIMARY KEY NOT NULL" }

sub column_references {
    my ($self, $attr) = @_;
    return Kinetic::Meta->for_key($attr->type);
}

##############################################################################

sub generate_table {
    my ($self, $class) = @_;
    $self->start_table($class);
    $self->generate_columns($class);
    $self->end_table($class);
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
    my $table = $self->{$key}{table_data}{name};
    $self->{$key}{buffer} .= "CREATE TABLE $table (\n";
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
    $self->{$class->key}{buffer} .= "\n);\n\n";
    return $self;
}

##############################################################################

=head3 output_columns

  $kbs->output_columns($class);

This method outputs all of the columns necessary to represent a class in a
table.

=cut

sub generate_columns {
    my ($self, $class) = @_;
    my $key = $class->key;
    my $col_data = $self->{$key}{col_data};
    $self->{$key}{buffer} .= join ",\n    ",
      "    " . $self->pk_column($class),
      map  { $self->declare_column($class, $_) }
      grep { $_->{class}->key eq $key } @$col_data;
    return $self;
}

##############################################################################

=head3 generate_column

  my $sql = $kbs->generate_column($attr);

This method returns the SQL representing a single column declaration in a
table, where the column holds data represented by the
C<Kinetic::Meta::Attribute> object passed to the method.

=cut

sub declare_column {
    my ($self, $class, $col) = @_;
    my $null = $self->column_null($col->{attr});
    my $def  = $self->column_default($col->{attr});
    return "    $col->{name} $col->{type}"
      . ($null ? " $null" : '')
      . ($def ? " $def" : '')
}

sub column_name {
    my ($self, $attr) = @_;
    return $attr->name;
}

sub column_type { return "TEXT" }
sub column_null {
    my ($self, $attr) = @_;
    return "NOT NULL" if $attr->required;
    return '';
}

sub column_default {
    my ($self, $attr) = @_;
    my $def = $attr->store_default;
    return defined $def ? "DEFAULT '$def'" : '';
}

sub generate_indexes {
    my ($self, $class) = @_;
    my $key = $class->key;
    my $col_data = $self->{$key}{col_data};
    my @idxs =
      map  { $self->generate_index($_) }
      grep { $_->{class}->key eq $key} @$col_data;
    return $self unless @idxs;
    $self->{$key}{buffer} .= join "\n", @idxs, "\n";
    return $self;
}

sub generate_index {
    my ($self, $col) = @_;
    return unless $col->{attr}->indexed || $col->{attr}->unique
      || $col->{refs};
    my $name = $self->index_name($col);
    my $on = $self->index_on($col);
    my $unique = $col->{attr}->unique ? ' UNIQUE' : '';
    return "CREATE$unique INDEX $name ON $col->{table} ($on);";
}

sub index_name {
    my ($self, $col) = @_;
    my $tname = $col->{class}->key;
    return ($col->{attr}->unique ? 'u' : 'i')
      . "dx_$tname\_$col->{name}";
}

sub index_on {
    my ($self, $col) = @_;
    return $col->{attr}->name;
}

sub generate_constraints { shift }

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
