package Kinetic::Store::DB;

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
use base qw(Kinetic::Store);
use DBI;
use Exception::Class::DBI;

=head1 Name

Kinetic::Store::DB - The Kinetic database store base class

=head1 Synopsis

See L<Kinetic::Store|Kinetic::Store>.

=head1 Description

This class implements the Kinetic storage API using DBI to communicate with an
RDBMS. RDBMS specific behavior is implemented via the
C<Kinetic::Store::DB::Pg> and C<Kinetic::Store::DBI::SQLite> classes.

=cut

sub save {
    my ($class, $object) = @_;
    #return $class unless $object->changed;
    return exists $object->{id}
        ? $class->_update($object)
        : $class->_insert($object);
}

sub _insert {
    my ($class, $object) = @_;
    my $my_class     = $object->my_class;
    my $view         = $my_class->key;
    my @attributes   = $my_class->attributes;
    my $attributes   = join ', ' => map { $_->name } @attributes;
    my $placeholders = join ', ' => (('?') x @attributes);
    my @values       = map { my $attr = $_->name; $class->_get_value($object, $attr) } @attributes;
    my $sql = "INSERT INTO $view ($attributes) VALUES ($placeholders)";
    $class->_do_sql($sql, \@values);
    $class->_set_id($object);
    return $class;
}

# may be overridden in subclasses
sub _set_id {
    my ($class, $object) = @_;
    $object->{id} = $class->_dbh->last_insert_id(undef, undef, undef, undef);
    return $class;
}

sub _update {
    my ($class, $object) = @_;
    my $my_class      = $object->my_class;
    my $view          = $my_class->key;
    my @attributes    = $my_class->attributes;
    my $column_values =
        join ', ' =>
        map { $_->name .' = ?' }
            @attributes;
    my @values = map { my $attr = $_->name; $class->_get_value($object, $attr) } @attributes;
    push @values => $object->guid;
    my $sql = "UPDATE $view SET $column_values WHERE guid = ?";
    $class->_do_sql($sql, \@values);
    return $class;
}

sub _get_value {
    my ($class, $object, $attr) = @_;
    my $value = $object->$attr;
    if (ref $value && $value->isa('Kinetic::Util::State')) {
        $value = int $value;
    }
    return $value;
}

sub _do_sql {
    my ($class, $sql, $bind_params) = @_;
    $class->_dbh->do($sql, undef, @$bind_params); 
    return $class;
}

sub lookup {
    my ($class, $search_class, $property, $value) = @_;
    my $view   = $search_class->view;
    my $sql    = "SELECT * FROM $view WHERE $property = ?";
    # XXX do something if they have more than one result?
    # selectall_hashref had syntax I did not understand
    my $result = $class->_dbh->selectrow_hashref($sql, undef, $value);
    my $ctor   = $search_class->constructors('new');
    my $object = $ctor->call($search_class->package);
    #use Data::Dumper;
    #print Dumper $result;
}

##############################################################################

=begin private

=head1 Private Interface

=head2 Private Instance Methods

=head3 _dbh

  my $dbh = Kinetic::Store->_dbh;

Returns the database handle to be used for all access to the data store.

=cut

sub _dbh { DBI->connect_cached(shift->_dsn) }

1;
__END__

=end private

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
