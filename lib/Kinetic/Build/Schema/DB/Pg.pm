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
    return "    " . $attr->name . "_id";
}

sub column_type {
    my ($self, $class, $attr) = @_;
    my $type = $attr->type;
    return " $types{$type}" if $types{$type};
    my $fk_class = Kinetic::Meta->for_key($type)
      or croak "No such data type: $type";
    # We need to note that an FK constraint needs to be added to refer to the
    # table of this object.
    push @{$self->{$class->key}{fk_classes}}, $fk_class;
    return " INTEGER";
}

sub index_on {
    my ($self, $attr) = @_;
    my $col = $attr->name;
    return $attr->type eq 'string' || $attr->type eq 'guid'
      ? "LOWER($col)"
      : $col;
}

sub output_constraints {
    my ($self, $class) = @_;
    my $key = $class->key;
    my $table = $self->{$key}{attrs}[-1][0];
    my @fks;
    if (@{$self->{$key}{attrs}} > 1) {
        my $fk_table = $self->{$key}{attrs}[-2][0];
        push @fks, "ALTER TABLE $table\n"
          . "  ADD CONSTRAINT pfk_$fk_table\_id FOREIGN KEY (id)\n"
          . "  REFERENCES $fk_table(id) ON DELETE CASCADE;";
    }
    for my $fk_class (@{$self->{$key}{fk_classes}}) {
        my $fk_key = $fk_class->key;
        my $fk_table = $self->{$fk_key}{tablename};
        push @fks, "ALTER TABLE $table\n"
          . "  ADD CONSTRAINT fk_$fk_table\_id FOREIGN KEY ($fk_key\_id)\n"
          . "  REFERENCES $fk_table(id) ON DELETE CASCADE;";
    }
    $self->{$key}{constraints} = join "\n\n", @fks;
}

sub start_schema {

'CREATE DOMAIN state AS INT2 NOT NULL DEFAULT 1
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
