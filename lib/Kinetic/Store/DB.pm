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

use constant GROUP_OP => qr/^(?:AND|OR)$/;

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
    my ($proto, $object) = @_;
    my $self = $proto->_from_proto;
    #return $class unless $object->changed;
    local $self->{search_class} = $object->my_class;
    local $self->{view}         = $self->{search_class}->key;
    local @{$self}{qw/names values/};
    foreach my $attr ($self->{search_class}->attributes) {
        if ($attr->references) {
            my $attr_name = $attr->name;
            my $contained_object = $object->$attr_name;
            $self->save($contained_object);
        }
        push @{$self->{names}}  => $self->_get_name($attr);
        push @{$self->{values}} => $self->_get_raw_value($object, $attr);
    }
    return exists $object->{id}
        ? $self->_update($object)
        : $self->_insert($object);
}

sub _from_proto {
    my $proto = shift;
    my $self = ref $proto ? $proto : $proto->new;
    return $self;
}

sub _insert {
    my ($self, $object) = @_;
    my $fields       = join ', ' => @{$self->{names}};
    my $placeholders = join ', ' => (('?') x @{$self->{names}});
    my $sql = "INSERT INTO $self->{view} ($fields) VALUES ($placeholders)";
    $self->_do_sql($sql, $self->{values});
    $self->_set_id($object);
    return $self;
}

sub _get_name {
    my ($self, $attr) = @_;
    my $name = $attr->name;
    $name   .= '__id' if $attr->references;
    return $name;
}

sub _get_raw_value {
    my ($self, $object, $attr) = @_;
    return $attr->raw($object) unless $attr->references;
    my $name = $attr->name;
    my $contained_object = $object->$name;
    return $contained_object->{id};  # this needs to be fixed
}

# may be overridden in subclasses
sub _set_id {
    my ($self, $object) = @_;
    $object->{id} = $self->_dbh->last_insert_id(undef, undef, undef, undef);
    return $self;
}

sub _update {
    my ($self, $object) = @_;
    my $fields = join ', '  => map { "$_ = ?" } @{$self->{names}};
    push @{$self->{values}} => $object->{id};
    my $sql = "UPDATE $self->{view} SET $fields WHERE id = ?";
    $self->_do_sql($sql, $self->{values});
    return $self;
}

sub _do_sql {
    my ($self, $sql, $bind_params) = @_;
 
    # XXX this is to prevent the use of
    # uninit values in subroutine entry warnings
    # Is there a better way?
    local $^W;
    $self->_dbh->do($sql, {}, @$bind_params); 
    return $self;
}

# XXX note the encapsulation violation.  This may change in the future.

sub _build_object_from_hashref {
    my ($self, $hashref) = @_;
    $hashref->{state} = $self->_get_kinetic_value('state', $hashref->{state})
        if exists $hashref->{state};
    my %object;
    while (my ($key, $value) = each %$hashref) {
        if ($key =~ /^(.*)__id$/) {
            my $field   = $1;
            my $collection = $self->search(Meta->for_key($field), id => $value);
            $object{$field} = $collection->next;
        }
        else {
            $object{$key} = $value;
        }
    }
    bless \%object => $self->{search_class}->package;
}

sub _get_kinetic_value {
    my ($self, $name, $value) = @_;
    if ('state' eq $name) {
        return State->new($value);
    }
    return $value;
}

##############################################################################

=head3 lookup

  my $object = Store->lookup($class_object, $unique_property, $value);

Returns a single object whose value matches the specified property.  This method
will croak if the property does not exist or if it is not unique.

=cut

sub lookup {
    my ($class, $search_class, $property, $value) = @_;
    my $attr = $search_class->attributes($property);
    croak "No such property ($property) for ".$search_class->package
        unless $attr;
    croak "Property ($property) is not unique" unless $attr->unique;
    my $collection = $class->search($search_class, $property, $value);
    return $collection->next;
}

##############################################################################

=head3 search

  my $iter = $store->search($class_object, @search_params);

Returns a L<Kinetic::Util::Iterator|Kinetic::Util::Iterator> of all object
which match the search params.  See L<Kinetic::Store|Kinetic::Store> for more
information about search params.

=cut

sub search {
    my ($proto, $search_class, @search_params) = @_;
    my $self = $proto->_from_proto;
    local $self->{search_class} = $search_class;
    my $constraints  = pop @search_params if ref $search_params[-1] eq 'HASH';
    my @attributes   = $search_class->attributes;
    my $attributes   = join ', ' => map { $self->_get_name($_) } @attributes;
    my $view         = $search_class->view;
    
    my ($where_clause, $bind_params) = 
        $self->_make_where_clause(\@search_params, $constraints);
    $where_clause = '' if $where_clause eq '()';
    $where_clause = "WHERE $where_clause" if $where_clause;
    my $sql       = "SELECT id, $attributes FROM $view $where_clause";
    $sql .= $self->_constraints($constraints) if $constraints;
    #warn "# *** $sql ***\n";
    #warn "# *** @$bind_params ***\n";
    
    return $self->_get_iterator_for_sql($sql, $bind_params);
}

sub _get_iterator_for_sql {
    my ($self, $sql, $bind_params) = @_;
    my $sth = $self->_dbh->prepare($sql);
    $sth->execute(@$bind_params);
    my @results;
    while (my $result = $sth->fetchrow_hashref) {
        push @results => $self->_build_object_from_hashref($result);
    }
    return Iterator->new(sub {shift @results});
}

sub _make_where_clause {
    my ($self, $attributes)     = @_;
    local $self->{where}        = [];
    local $self->{bind_params}  = [];

    my ($where_token, $bindings);
    my $op = 'AND';
    while (@$attributes) {
        my $curr_attribute = shift @$attributes;
        unless (ref $curr_attribute) {
            # name => 'foo'
            my $value = shift @$attributes;
            ($where_token, $bindings) = $self->_make_where_token($curr_attribute, $value);
        }
        elsif ('ARRAY' eq ref $curr_attribute) {
            # [ name => 'foo', description => 'bar' ]
            ($where_token, $bindings) = $self->_make_where_clause($curr_attribute);
        }
        elsif ('CODE' eq ref $curr_attribute) {
            # OR(name => 'foo') || AND(name => 'foo')
            my $values;
            ($op, $values) = $curr_attribute->();
            unless ($op =~ GROUP_OP) {
                croak("Grouping operators must be AND or OR, not ($op)");
            }
            ($where_token, $bindings) = $self->_make_where_clause($values);
        }
        else {
            croak sprintf "I don't know what to do with a %s for (@{$self->{where}})"
                => ref $curr_attribute;
        }
        $self->_save_where_data($op, $where_token, $bindings);
    }
    my $where = "(".join(' ' => @{ $self->{where} }).")";
    return $where, $self->{bind_params};
}

sub _save_where_data {
    my ($self, $op, $where_token, $bindings) = @_;
    if (@{$self->{where}} && $self->{where}[-1] !~ GROUP_OP) {
        push @{$self->{where}} => $op if $op;
    }
    push @{$self->{where}}        => $where_token;
    push @{$self->{bind_params}}  => @$bindings if @$bindings;
    return $self;
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
    my ($self, $key) = @_;
    return $COMPARE{$key};
}

sub _case_insensitive_types {
    my ($self) = @_;
    return qw/string/;
}

sub _make_where_token {
    my ($self, $field, $attribute) = @_;
    my $case_insensitive = 0;
    if ($self->{search_class} && $field ne 'id') {
        my $type = $self->{search_class}->attributes($field)->type;
        foreach my $ifield ($self->_case_insensitive_types) {
            if ($type eq $ifield) {
                $field = "lower($field)";
                $case_insensitive = 1;
                last;
            }
        }
    }
    
    my ($comparator, $value) = $self->_expand_attribute($attribute);

    my $place_holder = $case_insensitive
        ? 'lower(?)'
        : '?';
                                   # simple compare         #       NULL            # BETWEEN
    if ((my $op = $self->_comparison_operator($comparator)) && defined $value && ! ref $value) {
        return ("$field $op $place_holder", [$value]);
    }
    elsif (($comparator eq '' || $comparator eq 'NOT')  && 'ARRAY' eq ref $value) {
        return ("$field $comparator BETWEEN $place_holder AND $place_holder", $value);
    }
    elsif ($comparator =~ s/ ?ANY//) {
        my $place_holders = join ', ' => ($place_holder) x @$value;
        return ("$field $comparator IN ($place_holders)", $value);
    }
    elsif (! defined $value) {
        return ("$field IS $comparator NULL", []); 
    }
    elsif ($comparator =~ /LIKE/) {
        return ("$field $comparator $place_holder", [$value]);
    }
    else {
        croak "I don't know how to make a where token from '$field' and '$attribute'";
    }
}

sub _expand_attribute {
    # we assume only two levesl of code refs
    my ($self, $attribute) = @_;
    unless ('CODE' eq ref $attribute) {
        return ('', undef)        unless defined $attribute;
        return ('', $attribute)   if 'ARRAY' eq ref $attribute;
        return ('EQ', $attribute);
    }

    my ($type, $value) = $attribute->();
    unless ('CODE' eq ref $value) {
        if ($type =~ GROUP_OP) {
            # need a better error message XXX ?
            croak "($type) cannot be a value.";
        }
        return ($type, $value);
    }

    my ($name, $value2) = $value->();
    if ($name =~ GROUP_OP) {
        # need a better error message XXX ?
        croak "($type $name) has no meaning.";
    }
    return ("$type $name", $value2);
}

sub _constraints {
    my ($self, $constraints) = @_;
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
