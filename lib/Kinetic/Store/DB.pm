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
    my %data = (
        names  => [],
        values => [],
        class  => $object->my_class,
    );
    $data{view} = $data{class}->key;
    foreach my $attr ($data{class}->attributes) {
        if ($attr->references) {
            my $attr_name = $attr->name;
            my $contained_object = $object->$attr_name;
            $class->save($contained_object);
        }
        push @{$data{names}}  => $class->_get_name($attr);
        push @{$data{values}} => $class->_get_raw_value($object, $attr);
    }
    return exists $object->{id}
        ? $class->_update($object, \%data)
        : $class->_insert($object, \%data);
}

sub _insert {
    my ($class, $object, $data) = @_;
    my $fields       = join ', ' => @{$data->{names}};
    my $placeholders = join ', ' => (('?') x @{$data->{names}});
    my $sql = "INSERT INTO $data->{view} ($fields) VALUES ($placeholders)";
    $class->_do_sql($sql, $data->{values});
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
    return $attr->raw($object) unless $attr->references;
    my $name = $attr->name;
    my $contained_object = $object->$name;
    return $contained_object->{id};  # this needs to be fixed
}

# may be overridden in subclasses
sub _set_id {
    my ($class, $object) = @_;
    $object->{id} = $class->_dbh->last_insert_id(undef, undef, undef, undef);
    return $class;
}

sub _update {
    my ($class, $object, $data) = @_;
    my $fields = join ', '  => map { "$_ = ?" } @{$data->{names}};
    push @{$data->{values}} => $object->{id};
    my $sql = "UPDATE $data->{view} SET $fields WHERE id = ?";
    $class->_do_sql($sql, $data->{values});
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
    $where_clause = "WHERE $where_clause" if $where_clause;
    my $sql          = "SELECT id, $attributes FROM $view $where_clause";
    $sql .= $class->_constraints($constraints) if $constraints;
    # warn "# *** $sql ***\n";
    # warn "# *** @bind_params ***\n";
    
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
                $sort .= ' ' . uc $sort_order->[$i]->() if defined $sort_order->[$i];
                push @sorts => $sort;
            }
            $sql .= join ', ' => @sorts;
        }
    }
    return $sql;
}

sub _make_where_clause {
    my ($class, $attributes, $constraints) = @_;
    $constraints ||= {};
    my (@where, @bind);
    while (my ($field, $attribute) = splice @$attributes => 0, 2) {
        if ('CODE' eq ref $field) { # handle AND/OR
            # we need to back up one because AND and OR are not preceded
            # by the name of a field:
            # Store->search($class, OR(name => 'foo', desc => 'bar'));
            unshift @$attributes => $attribute;
            $attribute = $field;
            $field     = undef;
        }
        my ($token, $params) = $class->_make_where_token($field, $attribute);
        push @where => $token   if defined $token;
        push @bind  => @$params if defined $params;
    }
    my $join  = $constraints->{negated}
        ? 'OR'
        : 'AND';
    my $where = join(" $join " => @where) || '';
    return $where, @bind;
}

my %COMPARE = (
    EQ          => '=',
    NOT         => '!=',
    LIKE        => 'LIKE',
    MATCH       => '~*', # postgresql specific
    GT          => '>',
    LT          => '<',
    GE          => '>=',
    LE          => '<=',
    NE          => '!=',
    'NOT LIKE'  => 'NOT LIKE',
    'NOT MATCH' => '!~*', # see MATCH
    'NOT EQ'    => '!=',
    'NOT GT'    => '<=',
    'NOT LT'    => '>=',
    'NOT GE'    => '<',
    'NOT LE'    => '>',
);

sub _comparison_operator {
    my ($class, $key) = @_;
    return $COMPARE{$key};
}

sub _make_where_token {
    my ($class, $field, $attribute) = @_;
    my ($comparator, $value) = $class->_expand_attribute($attribute);

               # simple compare         #       NULL            # BETWEEN
    if ((my $op = $class->_comparison_operator($comparator)) && defined $value && ! ref $value) {
        return ("$field $op ?", [$value]);
    }
    elsif (($comparator eq '' || $comparator eq 'NOT')  && 'ARRAY' eq ref $value) {
        return ("$field $comparator BETWEEN ? AND ?", $value);
    }
    elsif ($comparator =~ s/ ?ANY//) {
        my $place_holders = join ', ' => ('?') x @$value;
        return ("$field $comparator IN ($place_holders)", $value);
    }
    elsif ($comparator eq 'AND') {
        my ($where_clause, @bindings) = $class->_make_where_clause($value);
        return ("($where_clause)", \@bindings);
    }
    elsif ($comparator eq 'OR') {
        my ($where_clause, @bindings) = $class->_make_where_clause($value, {negated => 1});
        return ("($where_clause)", \@bindings);
    }
    elsif (! defined $value) {
        # XXX I don't know how we're getting here with an undefined
        # field but it happens with AND/OR searches :/
        return unless defined $field;
        return ("$field IS $comparator NULL", []); 
    }
    elsif ($comparator =~ /LIKE/) {
        return ("$field $comparator ?", [$value]);
    }
    else {
        croak "I don't know how to make a where token from '$field' and '$attribute'";
    }
}

sub _expand_attribute {
    # we assume only two levesl of code refs
    my ($class, $attribute) = @_;
    unless ('CODE' eq ref $attribute) {
        return ('', undef)        unless defined $attribute;
        return ('', $attribute)   if 'ARRAY' eq ref $attribute;
        return ('EQ', $attribute);
    }

    my ($type, $value) = $attribute->();
    unless ('CODE' eq ref $value) {
        return ($type, $value);
    }

    my ($name, $value2) = $value->();
    return ("$type $name", $value2);
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
