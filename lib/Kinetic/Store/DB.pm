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
use Scalar::Util qw/blessed/;
use Carp qw/croak/;

use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Util::Iterator';
use aliased 'Kinetic::Util::State';
use aliased 'Kinetic::DateTime::Incomplete';
use aliased 'Kinetic::Store::Search';

use constant GROUP_OP => qr/^(?:AND|OR)$/;
use constant OBJECT_DELIMITER => '__';

=head1 Name

Kinetic::Store::DB - The Kinetic database store base class

=head1 Synopsis

See L<Kinetic::Store|Kinetic::Store>.

=head1 Description

This class implements the Kinetic storage API using DBI to communicate with an
RDBMS. RDBMS specific behavior is implemented via the
C<Kinetic::Store::DB::Pg> and C<Kinetic::Store::DBI::SQLite> classes.

=cut

##############################################################################

=head2 Public methods

It should be noted that although many methods in this class may be called as
class methods, instances are used internally for bookkeeping while parsing the
data and assembling information necessary to respond to user messages.  Thus,
many public class methods instantiate an object prior to doing work.

=cut

##############################################################################

=head3 save

  $store->save($object);

This method saves an object to the data store. It also saves all contained
objects to the data store at the same time, all in a single transaction.

=cut

sub save {
    my $self = shift->_from_proto;
    # XXX Cache the database handle only for the duration of a single call to
    # save(). We can change this if DBI is ever changed so that
    # connect_cached() stops resetting AutoCommit.
    $self->{dbh} = $self->_dbh;
    $self->{dbh}->begin_work;
    eval {
        $self->_save(@_);
        delete($self->{dbh})->commit;
    };
    if (my $err = $@) {
        delete($self->{dbh})->rollback;
        die $err;
    }
    return $self;
}

sub _save {
    my ($self, $object) = @_;
    # XXX So this is something we need to get implemented.
    #return $class unless $object->changed;
    local $self->{search_class} = $object->my_class;
    local $self->{view}         = $self->{search_class}->key;
    local @{$self}{qw/names values/};
    foreach my $attr ($self->{search_class}->attributes) {
        $self->_save($attr->get($object)) if $attr->references;
        push @{$self->{names}}  => $self->_get_name($attr);
        push @{$self->{values}} => $self->_get_raw_value($object, $attr);
    }
    return exists $object->{id}
        ? $self->_update($object)
        : $self->_insert($object);
}

##############################################################################

=head3 search_class

  my $search_class = $store->search_class;
  $store->search_class($search_class);

This is an accessor method for the class object representing the latest
search. Returns C<$self> if used to set the search class.

Generally the programmer will know which search class she is working with, but
if not, this method is avaible. Note that it is only available externally if
the programmer first creates an instances of store prior to doing a search.

 my $store = Kinetic::Store->new;
 my $iter  = $store->search($some_class, name => 'foo');
 my $class = $store->search_class; # returns $some_class

=cut

sub search_class {
    my $self = shift;
    return $self->{search_class} unless @_;
    $self->{search_class} = shift;
    return $self;
}

##############################################################################

=head3 lookup

  my $object = Store->lookup($class_object, $unique_property, $value);

Returns a single object whose value matches the specified property.  This method
will croak if the property does not exist or if it is not unique.

=cut

sub lookup {
    my ($proto, $search_class, $property, $value) = @_;
    my $self = $proto->_from_proto;
    my $attr = $search_class->attributes($property);
    croak qq{No such property "$property" for } . $search_class->package
        unless $attr;
    croak qq{Property "$property" is not unique} unless $attr->unique;
    $self->_cache_statement(1);
    $self->_create_iterator(0);
    local $self->{search_class} = $search_class;
    my $results = $self->_search($property, $value);
    if (@$results > 1) {
        my $package = $search_class->package;
        croak "Panic:  lookup($package, $property, $value) returned more than one result."
    }
    return $results->[0];
}

##############################################################################

=head3 search

  my $iter = Store->search($class_object, @search_params);

Returns a L<Kinetic::Util::Iterator|Kinetic::Util::Iterator> object containing
all objects that match the search params. See L<Kinetic::Store|Kinetic::Store>
for more information about search params.

=begin private

See notes for C<_set_search_data> and C<_build_object_from_hashref> for more
information about how this method works internally. For a given search, all
objects and their contained objects are fetched with a single SQL statement.
While this complicates the code, it is far more efficient than issuing
multiple SQL calls to assemble the data.

=end private

=cut

sub search {
    my ($proto, $search_class, @search_params) = @_;
    my $self = $proto->_from_proto;
    $self->_cache_statement(0);
    $self->_create_iterator(1);
    local $self->{search_class} = $search_class;
    $self->_search(@search_params);
}

sub _search {
    my ($self, @search_params) = @_;
    return $self->_full_text_search(@search_params) 
        if 1 == @search_params && ! ref $search_params[0];
    $self->_set_search_data unless exists $self->{search_data};
    my $attributes = join ', ' => @{$self->{search_data}{fields}};
    my ($sql, $bind_params) = $self->_get_select_sql_and_bind_params(
        $attributes,
        \@search_params
    );
    return $self->_get_sql_results($sql, $bind_params);
}

##############################################################################

=head3 search_guids

  my @guids = Store->search_guids($search_class, \@attributes, \%constraints);
  my $guids = Store->search_guids($search_class, \@attributes, \%constraints);

This method will return a list of guids matching the listed criteria.  It takes
the same arguments as C<search>.  In list context it returns a list.  In scalar
context it returns an array reference.

=cut

sub search_guids {
    my ($proto, $search_class, @search_params) = @_;
    my $self = $proto->_from_proto;
    $self->_cache_statement(0);
    $self->_create_iterator(0);
    local $self->{search_class} = $search_class;
    $self->_set_search_data;
    my $attributes = join ', ' => @{$self->{search_data}{fields}};
    my ($sql, $bind_params) = $self->_get_select_sql_and_bind_params(
        "guid",
        \@search_params
    );
    my $guids = $self->_dbh->selectcol_arrayref($sql, undef, @$bind_params);
    return wantarray ? @$guids : $guids;
}

##############################################################################

=head3 count

  my $count = Store->count($class_object, @search_params);

This method takes the same arguments as C<search>.  Returns a count of how
many rows a similar C<search> will return.

Any final constraints (such as "LIMIT" or "ORDER BY") will be discarded.

=cut

sub count {
    my ($proto, $search_class, @search_params) = @_;
    pop @search_params if 'HASH' eq ref $search_params[-1];
    my $self = $proto->_from_proto;
    $self->_cache_statement(0);
    local $self->{search_class} = $search_class;
    $self->_set_search_data unless exists $self->{search_data};
    my ($sql, $bind_params) = $self->_get_select_sql_and_bind_params(
        'count(*)',
        \@search_params
    );
    my ($count)   = $self->_dbh->selectrow_array($sql, undef, @$bind_params);
    return $count;
}

##############################################################################

=head3 date_handler

  $store->date_handler($date);

This method is used for returning the proper SQL and bind params for handling
incomplete dates.  This must be overridden in a subclass.

=cut

sub date_handler {
    croak "You must override date_handler in a subclass";
}

sub _get_select_sql_and_bind_params {
    my ($self, $fields, $params) = @_;
    my $constraints = pop @$params if 'HASH' eq ref $params->[-1];
    my $view        = $self->search_class->key;
    my ($where_clause, $bind_params) = $self->_make_where_clause($params);
    $where_clause = "WHERE $where_clause" if $where_clause;
    my $sql       = "SELECT $fields FROM $view $where_clause";
    $sql         .= $self->_constraints($constraints) if $constraints;
    return ($sql, $bind_params);
}
##############################################################################

=begin private

=head2 Private methods

All private methods are considered instance methods.

=cut

##############################################################################

=head3 _from_proto

  my $self = $proto->_from_proto;

Returns a new instance of a $store object regardless of whether the method
called was called as a class or an instance. This is used because many methods
can be called as class methods but use instances internally to maintain state
through recursive calls.

=cut

sub _from_proto {
    my $proto = shift;
    return ref $proto ? $proto : $proto->new;
}

##############################################################################

=head3 _insert

  $store->_insert($object);

This should only be called by C<save>.

Creates and executes an C<INSERT> sql statement for the given object.  This
assumes we have a new object with no C<id> stored internally.  Adds the ID
to the object hash.

Please note that the C<id> is only used for internal bookkeepping.  The objects
themselves are unaware of their C<id> and this should not be use externally for
any purpose.

=cut

sub _insert {
    my ($self, $object) = @_;
    my $fields       = join ', ' => @{$self->{names}};
    my $placeholders = join ', ' => (('?') x @{$self->{names}});
    my $sql = "INSERT INTO $self->{view} ($fields) VALUES ($placeholders)";
    $self->_cache_statement(1);
    $self->_do_sql($sql, $self->{values});
    $self->_set_id($object);
    return $self;
}

##############################################################################

=head3 _get_name

  my $name = $store->_get_name($attribute);

Given an attribute object, C<_get_name> will return the SQL column name.

=cut

sub _get_name {
    my ($self, $attr) = @_;
    my $name = $attr->name;
    $name   .= OBJECT_DELIMITER.'id' if $attr->references;
    return $name;
}

##############################################################################

=head3 _get_raw_value

  my $value = $store->_get_raw_value($object, $attribute);

Returns the raw value of a given attribute.  If the attribute references
another object, it returns the contained object.

=cut

sub _get_raw_value {
    my ($self, $object, $attr) = @_;
    return $attr->raw($object) unless $attr->references;
    return $attr->get($object)->{id}; # this needs to be fixed
}

##############################################################################

=head3 _set_id

  $store->_set_id($object);

This method is used by C<_insert> to set the C<id> of an object.  This is
frequently database specific, so this method may have to be overridden in a
subclass.  See C<_insert> for caveats about object C<id>s.

=cut

sub _set_id {
    my ($self, $object) = @_;
    # XXX This won't work for PostgreSQL, so be sure to override it.
    $object->{id} = $self->_dbh->last_insert_id(undef, undef, undef, undef);
    return $self;
}

##############################################################################

=head3 _update

  $store->_update($object);

This should only be called by C<save>.

Creates and executes an C<UPDATE> sql statement for the given object.

=cut

sub _update {
    my ($self, $object) = @_;
    my $fields = join ', '  => map { "$_ = ?" } @{$self->{names}};
    push @{$self->{values}} => $object->{id};
    my $sql = "UPDATE $self->{view} SET $fields WHERE id = ?";
    $self->_cache_statement(1);
    $self->_do_sql($sql, $self->{values});
    return $self;
}

##############################################################################

=head3 _do_sql

  $store->_do_sql($sql, \@bind_params);

Executes the given sql with the supplied bind params.  Returns the store
object.  Used for sql that is not expected to return data.

=cut

sub _do_sql {
    my ($self, $sql, $bind_params) = @_;
    my $dbi_method = $self->_cache_statement
        ? 'prepare_cached'
        : 'prepare';
    my $sth = $self->_dbh->$dbi_method($sql);
    no warnings 'uninitialized';
    $sth->execute(@$bind_params);
    return $self;
}

##############################################################################

=head3 _cache_statement

  $store->_cache_statement(1);
  if ($store->_cache_statement) {
    # use prepare_cached
  }

This getter/setter directs the module to use C<DBI::prepare_cached> when
creating statement handles.

=cut

sub _cache_statement {
    my $self = shift;
    if (@_) {
        $self->{cache_statement} = shift;
        return $self;
    }
    return $self->{cache_statement};
}

##############################################################################

=head3 _create_iterator

  $store->_create_iterator(1);
  if ($store->_create_iterator) {
    # use prepare_cached
  }

This getter/setter tells C<_get_sql_results> whether or not to use an iterator.

=cut

sub _create_iterator {
    my $self = shift;
    if (@_) {
        $self->{create_iterator} = shift;
        return $self;
    }
    return $self->{create_iterator};
}

##############################################################################

=head3 _get_sql_results

  my $iter = $store->_get_sql_results($sql, \@bind_params);

Returns a L<Kinetic::Util::Iterator|Kinetic::Util::Iterator> representing the
results of a given C<search>.

=cut

sub _get_sql_results {
    my ($self, $sql, $bind_params) = @_;
    my $dbi_method = $self->_cache_statement
        ? 'prepare_cached'
        : 'prepare';
    my $sth = $self->_dbh->$dbi_method($sql);
    $sth->execute(@$bind_params);
    my @results;
    # XXX Fetching directly into the appropriate data structure would be
    # faster, but so would an array ref, since you aren't really using
    # the hash keys.
    while (my $result = $sth->fetchrow_hashref) {
        push @results => $self->_build_object_from_hashref($result);
    }
    return $self->_create_iterator
        ? Iterator->new(sub {shift @results})
        : \@results;
}

##############################################################################

=head3 _build_object_from_hashref

  my $object = $store->_build_object_from_hashref($hashref);

For a given hashref returned by C<$sth-E<gt>fetchrow_hashref>, this method will
return an object representing that row.  Note that the hashref may represent
multiple objects because an object can contain other objects.
C<_build_object_from_hashref> resolves this by utilizing the metadata assembled
by C<_set_search_data> to match the fields for each object and pull them off of
the hashref with hash slices.

=cut

sub _build_object_from_hashref {
    my ($self, $hashref) = @_;
    my %objects;
    my $metadata = $self->{search_data}{metadata};
    while (my ($package, $data) = each %$metadata) {
        my $fields = $data->{fields};
        # XXX Is the distinction here due to IDs?
        my @sql_fields    = keys %$fields;
        my @object_fields = @{$fields}{@sql_fields};
        my %object;
        # XXX Isn't this where one could use an array, since the columns should
        # be in the same order as the attributes? Oh, does field eq attribute
        # && field eq column?
        @object{@object_fields} = @{$hashref}{@sql_fields};
        # XXX ugh.  I hate doing this :(
        $object{state} = State->new($object{state}) if exists $object{state};
        $objects{$package} = bless \%object => $package;
    }
    # XXX Aack!  This is fugly.
    while (my ($package, $data) = each %$metadata) {
        if (defined (my $contains = $data->{contains})) {
            while (my ($key, $contained) = each %$contains) {
                delete $objects{$package}{$key};
                my $contained_package = $contained->package;
                my $view = $contained->key;
                $objects{$package}{$view} = $objects{$contained_package};
            }
        }
    }
    return $objects{$self->search_class->package};
}

##############################################################################

=head3 _set_search_data

 $store->_set_search_data;

This method sets the search data used for the current search.  Since this is
expensive, we cache search data for each search class.  The search data
consists of the sql fields that will be used in the search sql and metadata
that C<_build_object_from_hashref> will use to break the returned sql data down
into objects and its contained subobjects.

=cut

# XXX This is the information it'd be great to compile in at build time.
# Maybe a utility object to track all of this data would be useful...

my %SEARCH_DATA;
sub _set_search_data {
    my ($self) = @_;
    my $package = $self->search_class->package;
    unless (exists $SEARCH_DATA{$package}) {
        my @fields   = 'id'; # ID of main view
        my %packages = (
            $package => {
                fields => { id => 'id' }
            }
        );
        my @classes_to_process = {
            class  => $self->search_class,
            prefix => '',
        };
        while (@classes_to_process) {
            foreach my $data (splice @classes_to_process, 0) {
                my $package = $data->{class}->package;
                foreach my $attr ($data->{class}->attributes) {
                    my $name     = $self->_get_name($attr);
                    my $field    = "$data->{prefix}$name";
                    push @fields => $field;
                    $packages{$package}{fields}{$field} = $name;
                    if (my $class = $attr->references) {
                        $packages{$class->package}{fields}{$field} = 'id';
                        push @classes_to_process => {
                            class  => $class,
                            prefix => $class->key . OBJECT_DELIMITER,
                        };
                        $packages{$package}{contains}{$name} = $class;
                    }
                }
            }
        }
        $SEARCH_DATA{$package}{fields}   = \@fields;
        $SEARCH_DATA{$package}{metadata} = \%packages;
    }
    $self->_search_data($SEARCH_DATA{$package});
    return $self;
}

##############################################################################

=head3 _search_data

  $store->_search_data($search_data); # returns $self
  my $search_data = $store->_search_data;

Getter/setter for search data generated by C<_set_search_data>.

Returns C<$self> if used as a setter.

=cut

sub _search_data {
    my $self = shift;
    return $self->{search_data} unless @_;
    $self->{search_data} = shift;
    return $self;
}

##############################################################################

=head3 _make_where_clause

 my ($where_clause, $bind_params) = $self->_make_where_clause(\@search_params);

This method returns a where clause and an arrayref of any appropriate bind
params for that where clause. Returns an empty string if no where clause can
be generated.

This is merely a wrapper around C<_make_where_clause_recursive>.

=cut

sub _make_where_clause {
    my ($self, $search_paramss) = @_;
    my ($where_clause, $bind_params) = $self->_make_where_clause_recursive($search_paramss);
    $where_clause = '' if '()' eq $where_clause;
    return ($where_clause, $bind_params);
}

##############################################################################

=head3 _make_where_clause_recursive

  my ($where_clause, $bind_params) =
     $store->_make_where_clause_recursive(\@search_params);

This method returns a where clause and an arrayref of any appropriate bind
params for that where clause.  Due to its recursive nature, it returns a pair
of empty parentheses "()" if no where clause can be generated, hence the
C<_make_where_clause> wrapper.

This method is essentially a data structure parser for the small search
language outlined in L<Kinetic::Store|Kinetic::Store>

=cut

sub _make_where_clause_recursive {
    my ($self, $search_params)     = @_;
    local $self->{where}        = [];
    local $self->{bind_params}  = [];

    my ($where_token, $bindings);
    my $op = 'AND';
    while (@$search_params) {
        my $curr_search_param = shift @$search_params;
        unless (ref $curr_search_param) {
            # name => 'foo'
            $curr_search_param =~ s/\./@{[OBJECT_DELIMITER]}/g;
            my $value = shift @$search_params;
            ($where_token, $bindings) = $self->_make_where_token($curr_search_param, $value);
        }
        elsif ('ARRAY' eq ref $curr_search_param) {
            # [ name => 'foo', description => 'bar' ]
            ($where_token, $bindings) = $self->_make_where_clause_recursive($curr_search_param);
        }
        elsif ('CODE' eq ref $curr_search_param) {
            # OR(name => 'foo') || AND(name => 'foo')
            my $values;
            ($op, $values) = $curr_search_param->();
            unless ($op =~ GROUP_OP) {
                croak("Grouping operators must be AND or OR, not ($op)");
            }
            ($where_token, $bindings) = $self->_make_where_clause_recursive($values);
        }
        else {
            croak sprintf "I don't know what to do with a %s for (@{$self->{where}})"
                => ref $curr_search_param;
        }
        $self->_save_where_data($op, $where_token, $bindings);
    }
    my $where = "(".join(' ' => @{ $self->{where} }).")";
    return $where, $self->{bind_params};
}

##############################################################################

=head3 _save_where_data

  $self->_save_where_data($op, $where_token, $bindings);

This is a utility method used to cache data accumulated by the
C<_make_where_clause_recursive> method.

=cut

sub _save_where_data {
    my ($self, $op, $where_token, $bindings) = @_;
    if (@{$self->{where}} && $self->{where}[-1] !~ GROUP_OP) {
        push @{$self->{where}} => $op if $op;
    }
    push @{$self->{where}}        => $where_token;
    push @{$self->{bind_params}}  => @$bindings if @$bindings;
    return $self;
}

##############################################################################

=head3 _case_insensitive_types

  my @types = $store->_case_insensitive_types;

Returns a list of the C<Kinetic::Meta> types for which searches are to be
case-insensitive.

=cut

sub _case_insensitive_types {
    my ($self) = @_;
    return qw/string/;
}

##############################################################################

=head3 _make_where_token

  my ($where_token, $value) = $store->_make_where_token($field, $search_param);

This method returns individual tokens that will be assembled to form the final
where clause.  The C<$value> is always an arrayref of the values that will be
bound to the bind parameters in the token.  It takes a $field and its
$search_param.  Due to the nature of the mini search language, the search
parameter may be either a string or a code ref.

Examples of returned tokens:

 'name = ?' and the $value will be an array ref with the single value that
            binds to it

 'description IS NULL' and the value will be an empty array ref.

 'age BETWEEN ? and ?' and the value will be an array ref of two elements.

=cut

sub _make_where_token {
    my ($self, $field, $search_param) = @_;

    my ($negated, $operator, $value) = $self->_expand_search_param($search_param);
    unless (grep $_ eq $field => @{$self->{search_data}{fields}}) {
        # special case for searching on a contained object id ...
        my $id_field = $field . OBJECT_DELIMITER . 'id';
        unless (grep $_ eq $id_field => @{$self->{search_data}{fields}}) {
            croak "Don't know how to search for ($field $negated $operator $value)";
        }
        $field = $id_field;
        $value = 'ARRAY' eq ref $value
            ? [map $self->_get_id_from_object($_) => @$value]
            : $self->_get_id_from_object($value);
    }

    $operator ||=  'ARRAY' eq ref $value ? 'BETWEEN' : 'EQ';
    my $search = Search->new(
        attr     => $field,
        operator => $operator,
        negated  => $negated,
        data     => $value,
    );
    my $search_method = $search->search_method
        or croak "Don't know how to search for ($field $negated $operator $value)";

    return $self->$search_method($search);
}

sub _get_id_from_object {
    my ($self, $object) = @_;
    #unless (blessed ($object) && $object->isa('Kinetic::Meta')) {
    #    croak "Don't know how to search for $object";
    #}
    return $object->{id};
}

sub _is_case_insensitive {
    my ($self, $field) = @_;
    my $orig_field     = $field;
    my $search_class   = $self->{search_class};
    if ($field =~ /@{[OBJECT_DELIMITER]}/) {
        my ($key,$field2) = split /@{[OBJECT_DELIMITER]}/ => $field;
        $search_class = Kinetic::Meta->for_key($key)
          or croak "Cannot determine class for key ($key)";
        $field = $field2;
    }
    if ($search_class && $field ne 'id') {
        my $type = $search_class->attributes($field)->type;
        foreach my $ifield ($self->_case_insensitive_types) {
            if ($type eq $ifield) {
                $field = "LOWER($orig_field)";
                last;
            }
        }
    }
    if ($field =~ /^LOWER/) {
        return ($field, 'LOWER(?)');
    }
    else {
        return ($orig_field, '?');
    }
}

sub _ANY_SEARCH {
    my ($self, $search)        = @_;
    my ($negated, $value)      = ($search->negated, $search->data);
    my ($field, $place_holder) = $self->_is_case_insensitive($search->attr);
    my $place_holders = join ', ' => ($place_holder) x @$value;
    return ("$field $negated IN ($place_holders)", $value);
}

sub _EQ_SEARCH {
    my ($self, $search) = @_;
    my ($negated, $value) = ($search->negated, $search->data);
    my ($field, $place_holder) = $self->_is_case_insensitive($search->attr);
    my $operator = $negated ? '!=' : '=';
    return 
          UNIVERSAL::isa($value, Incomplete) ? ("$field $negated LIKE ?", [$self->date_handler($value)])
        :                                      ("$field $operator $place_holder", [$value]);
}

sub _NULL_SEARCH {
    my ($self, $search)   = @_;
    my ($field, $negated) = ($search->attr, $search->negated);
    return ("$field IS $negated NULL", []);
}

sub _GT_SEARCH {
    my ($self, $search) = @_;
    $search->operator($search->negated ? '<=' : '>');
    $self->_gt_lt_handler($search);
}

sub _GE_SEARCH {
    my ($self, $search) = @_;
    $search->operator($search->negated ? '<' : '>=');
    $self->_gt_lt_handler($search);
}

sub _LE_SEARCH {
    my ($self, $search) = @_;
    $search->operator($search->negated ? '>' : '<=');
    $self->_gt_lt_handler($search);
}

sub _LT_SEARCH {
    my ($self, $search) = @_;
    $search->operator($search->negated ? '>=' : '<');
    $self->_gt_lt_handler($search);
}

sub _gt_lt_handler {
    my ($self, $search) = @_;
    my ($orig_field, $operator, $value) =
        ($search->attr, $search->operator, $search->data);
    my ($field, $place_holder) = $self->_is_case_insensitive($orig_field);
    if (UNIVERSAL::isa($value, Incomplete)) {
        return $self->date_handler($value, $field, $operator);
    }
    else {
        return ("$field $operator $place_holder", [$value]);
    }
}

sub _BETWEEN_SEARCH {
    my ($self, $search) = @_;
    my ($negated, $operator) = ($search->negated, $search->operator);
    my ($field, $place_holder) = $self->_is_case_insensitive($search->attr);
    return ("$field $negated $operator $place_holder AND $place_holder", $search->data)
}

sub _MATCH_SEARCH {
    my ($self, $search) = @_;
    my ($field, $place_holder) = $self->_is_case_insensitive($self->attr);
    my $operator = $search->negated ? '!~*' : '~*';
    return ("$field $operator $place_holder", [$search->data]);
}

sub _LIKE_SEARCH {
    my ($self, $search) = @_;
    my ($negated, $operator) = ($search->negated, $search->operator);
    my ($field, $place_holder) = $self->_is_case_insensitive($search->attr);
    return ("$field $negated $operator $place_holder", [$search->data]);
}

##############################################################################

=head3 _expand_search_param

  my ($op_key, $value) = $store->_expand_search_param($search_param);

When given an search_param, this method returns the op key that will be used to
determine the comparison operator used in a where token.  It also returns the
value(s) that will be used in the bind params.  If there are multiple values,
they will be returned as an arrayref.

The search_param passed to this method may be a code ref.  Attribute code refs
return a string and another search_param.  The new search_param may be the value used
or it may, in turn, be another code ref.  Attribute code refs are never more
than two deep.

=cut

sub _expand_search_param {
    # we assume only two levels of code refs
    my ($self, $search_param) = @_;
    my $negated = '';
    unless ('CODE' eq ref $search_param) {
        return ($negated, '', undef)        unless defined $search_param;
        return ($negated, '', $search_param)   if 'ARRAY' eq ref $search_param;
        return ($negated, 'EQ', $search_param);
    }

    my ($type, $value) = $search_param->();
    unless ('CODE' eq ref $value) {
        if ($type =~ GROUP_OP) {
            # need a better error message XXX ?
            croak "($type) cannot be a value.";
        }
        if ('NOT' eq $type) {
            $negated = 'NOT';
            $type    = '';
        }
        return ($negated, $type, $value);
    }

    $negated = $type;
    ($type, $value) = $value->();
    if ($type =~ GROUP_OP) {
        # need a better error message XXX ?
        croak "($negated $type) has no meaning.";
    }
    if ('CODE' eq ref $value) {
        my ($bad, $new_value) = $value->();
        croak "Search operators can never be more than two deep: ($negated $type $bad $new_value)";
    }
    if ('NOT' eq $type) {
        croak "NOT must always be first when used as a search operator: ($negated $type $value)";
    }
    if ($negated ne 'NOT') {
        croak "Two search operators not allowed unless NOT is the first operator: ($negated $type $value)";
    }
    return ($negated, $type, $value);
}

##############################################################################

=head3 _constraints

 my $constraints = $store->_constraints(\%constraints);

This method takes a hash ref of "order by" and "limit" constraints as described
in L<Kinetic::Store|Kinetic::Store> and return an sql snippet representing
those constraints.

=cut

sub _constraints {
    my ($self, $constraints) = @_;
    my $sql = '';
    foreach my $constraint (keys %$constraints) {
        if ('order_by' eq $constraint) {
            $sql .= $self->_constraint_order_by($constraints); 
        }
        elsif ('limit' eq $constraint) {
            $sql .= $self->_constraint_limit($constraints); 
        }
    }
    return $sql;
}

sub _constraint_order_by {
    my ($self, $constraints) = @_;
    my $sql   = ' ORDER BY ';
    my $value = $constraints->{order_by};
    # XXX Default to ASC?
    my $sort_order = $constraints->{sort_order};
    $value      = [$value]      unless 'ARRAY' eq ref $value;
    $sort_order = [$sort_order] unless 'ARRAY' eq ref $sort_order;
    # normalize . to __
    s/\./@{[OBJECT_DELIMITER]}/g foreach @$value; # one.name -> one__name
    my @sorts;
    # XXX Perl 6 would so rock for this...
    for my $i (0 .. $#$value) {
        my $sort = $value->[$i];
        $sort .= ' ' . uc $sort_order->[$i]->() if defined $sort_order->[$i];
        push @sorts => $sort;
    }
    $sql .= join ', ' => @sorts;
    return $sql;
}

sub _constraint_limit {
    my ($self, $constraints) = @_;
    my $sql = " LIMIT $constraints->{limit}";
    if (exists $constraints->{offset}) {
        $sql .= " OFFSET $constraints->{offset}";
    }
    return $sql;
}

sub _dbh {
    my $self = shift->_from_proto;
    # XXX The save() method sets up a database handle for the duration of its
    # execution, so prefer that database handle. This is because, although
    # connect_cached() will return the same handle, it will reset AutoCommit
    # to 1, thus screwing up the transaction.
    return $self->{dbh} || DBI->connect_cached($self->_connect_args);
    # XXX Switch to this single line if connect_cached() ever stops resetting
    # AutoCommit. See http://www.nntp.perl.org/group/perl.dbi.dev/3892
    # DBI->connect_cached(shift->_connect_args);
}

sub _connect_args {
    require Carp;
    Carp::croak("Kinetic::Store::DB::_connect_args must be overridden in "
                . "a subclass");
}

#DESTROY { shift->_dbh->disconnect }

1;
__END__

##############################################################################

=end private

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
