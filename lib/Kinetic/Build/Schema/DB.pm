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

sub schema_for_class {
    my ($self, $class) = @_;
    $class = $class->my_clastyps
      unless UNIVERSAL::isa($class, 'Kinetic::Meta::Class');
    $self->start_table($class);
    $self->output_columns($class);
    $self->end_table($class);
    return delete $self->{$class->key . '_table'};
}

sub start_table {
    my ($self, $class) = @_;
    my $key = $class->key;
    $self->{"$key\_table"} = "CREATE TABLE $key (\n";
    return $self;
}

sub end_table {
    my ($self, $class) = @_;
    $self->{$class->key . '_table'} .= "\n);\n";
    return $self;
}

sub output_columns {
    my ($self, $class) = @_;
    my @cols = ( "    id INTEGER NOT NULL DEFAULT NEXTVAL('kinetic_seq')" );
    push @cols, $self->generate_column($_) for $class->attributes;
    $self->{$class->key . '_table'} .= join ",\n    ", @cols;
    return $self;
}

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
