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
use Carp qw/croak/;

use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Util::Iterator';
use aliased 'Kinetic::Util::State';

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
    foreach my $attr ($object->my_class->attributes) {
        if ($attr->references) {
            my $attr_name = $attr->name;
            my $contained_object = $object->$attr_name;
            $class->save($contained_object);
        }
    }
    return exists $object->{id}
        ? $class->_update($object)
        : $class->_insert($object);
}

sub _insert {
    my ($class, $object) = @_;
    my $my_class     = $object->my_class;
    my $view         = $my_class->key;
    my @attributes   = $my_class->attributes; #$class->_fetch_attributes($object, $my_class);
    my $attributes   = join ', ' => map { $class->_get_name($_) } @attributes;
    my $placeholders = join ', ' => (('?') x @attributes);
    my @values       = map { $class->_get_raw_value($object, $_) } @attributes;
    my $sql = "INSERT INTO $view ($attributes) VALUES ($placeholders)";
    $class->_do_sql($sql, \@values);
    $class->_set_id($object);
    return $class;
}

sub _get_name {
    my ($class, $attr) = @_;
    my $name = $attr->name;
    $name   .= '__id' if $attr->references;
    return $name;
}

sub _get_raw_value {
    my ($class, $object, $attr) = @_;
    my $raw_value;
    if ($attr->references) {
        my $name = $attr->name;
        my $contained_object = $object->$name;
        $raw_value = $contained_object->{id};  # this needs to be fixed
    }
    else {
        my $attr_name = $class->_get_name($attr);
        $raw_value = $object->$attr_name;
        if (ref $raw_value && $raw_value->isa(State)) {
            $raw_value = int $raw_value;
        }
    }
    return $raw_value;
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
        map { $class->_get_name($_) .' = ?' }
            @attributes;
    my @values = map { $class->_get_raw_value($object, $_) } @attributes;
    push @values => $object->{id};
    my $sql = "UPDATE $view SET $column_values WHERE id = ?";
    $class->_do_sql($sql, \@values);
    return $class;
}

sub _do_sql {
    my ($class, $sql, $bind_params) = @_;
    
    # XXX this is to prevent the use of
    # uninit values in subroutine entry warnings
    # Is there a better way?
    local $^W;
    $class->_dbh->do($sql, {}, @$bind_params); 
    return $class;
}

# XXX note the encapsulation violation.  This may change in the future.

sub _build_object_from_hashref {
    my ($class, $search_class, $hashref) = @_;
    $hashref->{state} = $class->_get_kinetic_value('state', $hashref->{state})
        if exists $hashref->{state};
    my %object;
    while (my ($key, $value) = each %$hashref) {
        if ($key =~ /^(.*)__id$/) {
            my $field   = $1;
            my $collection = $class->search(Meta->for_key($field), id => $value);
            $object{$field} = $collection->next;
        }
        else {
            $object{$key} = $value;
        }
    }
    bless \%object => $search_class->package;
}

sub _get_kinetic_value {
    my ($class, $name, $value) = @_;
    if ('state' eq $name) {
        return State->new($value);
    }
    return $value;
}

sub lookup {
    my ($class, $search_class, $property, $value) = @_;
    my $attr = $search_class->attributes($property);
    croak "No such property ($property) for ".$search_class->package
        unless $attr;
    croak "Property ($property) is not unique" unless $attr->unique;
    my $collection = $class->search($search_class, $property, $value);
    return $collection->next;
}

sub search {
    my ($class, $search_class, @search_params) = @_;
    my $constraints  = pop @search_params if ref $search_params[-1] eq 'HASH';
    my @attributes   = $search_class->attributes;
    my $attributes   = join ', ' => map { $class->_get_name($_) } @attributes;
    my $view         = $search_class->view;
    
    my ($where_clause, @bind_params) = 
        $class->_make_where_clause(\@search_params, $constraints);
    my $sql          = "SELECT id, $attributes FROM $view $where_clause";
    if ($ENV{DEBUG}) {
        warn "Calling sql ($sql) with (@bind_params)";
    }
    $sql .= $class->_constraints($constraints) if $constraints;
    my @results;
    my $sth = $class->_dbh->prepare($sql);
    $sth->execute(@bind_params);
    while (my $result = $sth->fetchrow_hashref) {
        push @results => $class->_build_object_from_hashref($search_class, $result);
    }
    return Iterator->new(sub {shift @results});
}

sub _constraints {
    my ($class, $constraints) = @_;
    my $sql = ' ';
    while (my ($constraint, $value) = each %$constraints) {
        if ('order_by' eq $constraint) {
            $sql .= 'ORDER BY ';
            my $sort_order = $constraints->{sort_order};
            $value      = [$value]      unless 'ARRAY' eq ref $value;
            $sort_order = [$sort_order] unless 'ARRAY' eq ref $sort_order;
            my @sorts;
            for my $i (0 .. $#$value) {
                my $sort = $value->[$i];
                $sort .= ' ' . uc $sort_order->[$i] if defined $sort_order->[$i];
                push @sorts => $sort;
            }
            $sql .= join ', ' => @sorts;
        }
    }
    return $sql;
}

sub _make_where_clause {
    my ($class, $attributes, $constraints) = @_;
    my (@where, @bind);
    while (my ($field, $attribute) = splice @$attributes => 0, 2) {
        my ($token, @params) = $class->_make_where_token($field, $attribute);
        push @where => $token;
        push @bind  => @params;
    }
    return '' unless @where;
    my $where = 'WHERE ' . join ' AND ' => @where;
    return $where, @bind;
}

# this may have to go into subclasses
# at some point
my %term_map = (
    EQ    => '=',
    NOT   => '!=',
    LIKE  => 'LIKE',
    GT    => '>',
    LT    => '<',
    GE    => '>=',
    LE    => '<=',
);
sub _make_where_token {
    my ($class, $field, $attribute) = @_;
    # maybe a switch at some point
    my $compared_to;
    if ('ARRAY' eq ref $attribute) {
        return $class->_make_range_token($field, $attribute);
    }
    elsif ('CODE' eq ref $attribute) {
        my ($name, $value) = $attribute->();
        $compared_to = $term_map{$name} or die "No such search operator: $name";
        $attribute   = $value;
    }
    unless ($compared_to) {
        $compared_to = $attribute =~ /%/ ? 'LIKE' : '=';
    }
    return "$field $compared_to ?", $attribute;
}

sub _make_range_token {
    my ($class, $field, $attribute) = @_;
    croak "Ranged searches must not have more than two elements"
        if @$attribute > 2;
    return "$field BETWEEN ? AND ?", @$attribute; 
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
