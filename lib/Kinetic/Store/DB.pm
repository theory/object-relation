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
use version;
our $VERSION = version->new('0.0.1');
use DBI;
use Clone;

use Class::BuildMethods qw(
  _in_transaction
);

use Kinetic::Util::Exceptions qw/
  panic
  throw_attribute
  throw_fatal
  throw_invalid
  throw_invalid_class
  throw_search
  throw_unimplemented
  /;
use Kinetic::Store qw/:sorting/;
use Kinetic::Store::Parser qw/parse/;
use Kinetic::Store::Lexer::Code qw/code_lexer_stream/;
use Kinetic::Store::Lexer::String qw/string_lexer_stream/;
use Kinetic::Util::Constants qw/:data_store/;

use aliased 'Kinetic::Meta' => 'Meta', qw/:with_dbstore_api/;
use aliased 'Kinetic::Util::Iterator';
use aliased 'Kinetic::DateTime::Incomplete';
use aliased 'Kinetic::Store::Search';

my %SEARCH_TYPE_FOR = map { $_ => 1 } qw/CODE STRING XML/;

my @setup_string_methods = qw(
  query
  query_uuids
);
foreach my $method (@setup_string_methods) {
    my $string_method = "s$method";
    no strict 'refs';
    *$string_method = sub {
        my $proto        = shift;
        my $search_class = shift;
        unshift @_, $proto, $search_class, 'STRING';
        goto &$method;
    };
}

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

If a transaction has been started manually with C<begin_work>, this method
does not attempt to start a new transaction.

=cut

sub save {
    my $self = shift->_from_proto;

    if ( $self->_in_transaction ) {

        # someone has started a transaction externally
        eval { $self->_save(@_) };
        throw_fatal [ 'Error saving to data store: [_1]', $@ ] if $@;
    }
    else {
        $self->begin_work;
        eval {
            $self->_save(@_);
            $self->commit;
        };
        if ( my $err = $@ ) {
            $self->rollback;
            throw_fatal [ 'Error saving to data store: [_1]', $@ ] if $@;
        }
    }
    return $self;
}

##############################################################################

=head3 begin_work

  $store->begin_work;

Begins a transaction.  No effect if we're already in a transaction.

=cut

sub begin_work {
    my $self = shift;

    # XXX Cache the database handle only for the duration of a single call to
    # save(). We can change this if DBI is ever changed so that
    # connect_cached() stops resetting AutoCommit.
    return if $self->_in_transaction;
    $self->{dbh} = $self->_dbh;
    $self->{dbh}->begin_work;
    $self->_in_transaction(1);
    return $self;
}

##############################################################################

=head3 commit

  $store->commit;

Commits a transaction.  No effect if we're not in a transaction.

=cut

sub commit {
    my $self = shift;
    return unless $self->_in_transaction;
    $self->_in_transaction(0);
    delete( $self->{dbh} )->commit;
    return $self;
}

##############################################################################

=head3 rollback

  $store->rollback;

Rolls back an uncommitted transaction.  No effect if we're not in a
transaction.

=cut

sub rollback {
    my $self = shift;
    return unless $self->_in_transaction;
    $self->_in_transaction(0);
    delete( $self->{dbh} )->rollback;
    return $self;
}

##############################################################################

=head3 search_class

  my $search_class = $store->search_class;
  $store->search_class($search_class);

This is an accessor method for the Kinetic::Meta::Class object representing
the class being searched in the current search.  This is usually the first
argument to the C<query> method.

Generally, the programmer will know which search class she is working with,
but if not, this method is avaible. Note that it is only available externally
if the programmer first creates an instances of store prior to doing a search.

 my $store = Kinetic::Store->new;
 my $iter  = $store->query($some_class, name => 'foo');
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

  my $object = Store->lookup($class_object, $unique_attr, $value);

Returns a single object whose value matches the specified attribute. This
method will throw an exception if the attribute does not exist or if it is not
unique.

=cut

sub lookup {
    my ( $proto, $search_class, $attr_key, $value ) = @_;
    my $self = $proto->_from_proto;
    unless ( ref $search_class ) {
        $search_class = Kinetic::Meta->for_key($search_class);
    }
    my $attr = $search_class->attributes($attr_key);
    throw_attribute [ 'No such attribute "[_1]" for [_2]', $attr_key,
        $search_class->package ]
      unless $attr;
    throw_attribute [ 'Attribute "[_1]" is not unique', $attr_key ]
      unless $attr->unique;
    $self->_prepare_method($CACHED);
    $self->_should_create_iterator(0);
    local $self->{search_class} = $search_class;
    my $results = $self->_query( $attr_key, $value );

    if ( @$results > 1 ) {
        my $package = $search_class->package;
        panic [
            "PANIC: lookup([_1], [_2], [_3]) returned more than one result.",
            $package, $attr_key, $value ];
    }
    return $results->[0];
}

##############################################################################

=head3 query

  my $iter = $kinetic_object->query(@search_params);

Returns a L<Kinetic::Util::Iterator|Kinetic::Util::Iterator> object containing
all objects that match the search params. See L<Kinetic::Store|Kinetic::Store>
for more information about search params.

=begin comment

See notes for C<_set_search_data> and C<_build_object_from_hashref> for more
information about how this method works internally. For a given search, all
objects and their contained objects are fetched with a single SQL statement.
While this complicates the code, it is far more efficient than issuing
multiple SQL calls to assemble the data.

=end comment

=head3 squery

  my $iter = $kinetic_object->squery(@search_params);

Identical to C<query>, but uses string search syntax.  This method does B<not>
expect the value 'STRING' at the front of a query.

=cut

sub query {
    my ( $proto, $search_class, @search_params ) = @_;
    my $self = $proto->_from_proto;
    $self->_prepare_method($PREPARE);
    $self->_should_create_iterator(1);
    unless ( ref $search_class ) {
        $search_class = Kinetic::Meta->for_key($search_class);
    }
    local $self->{search_class} = $search_class;
    $self->_query(@search_params);
}

##############################################################################

=head3 query_uuids

  my @uuids = Store->query_uuids($search_class, \@attributes, \%constraints);
  my $uuids = Store->query_uuids($search_class, \@attributes, \%constraints);

This method will return a list of uuids matching the listed criteria.  It
takes the same arguments as C<query>.  In list context it returns a list.  In
scalar context it returns an array reference.

=head3 squery_uuids

  my @uuids = Store->squery_uuids($search_class, "@attributes", @constraints);
  my $uuids = Store->squery_uuids($search_class, "@attributes", @constraints);

Identical to C<query_uuids>, but uses string search syntax.

=cut

sub query_uuids {
    my ( $proto, $search_class, @search_params ) = @_;
    unless ( ref $search_class ) {
        $search_class = Kinetic::Meta->for_key($search_class);
    }
    my $self = $proto->_from_proto;
    $self->_set_search_type( \@search_params );
    $self->_prepare_method($PREPARE);
    $self->_should_create_iterator(0);
    local $self->{search_class} = $search_class;
    $self->_set_search_data;
    my ( $sql, $bind_params ) =
      $self->_get_select_sql_and_bind_params( "uuid", \@search_params );
    my $uuids = $self->_dbh->selectcol_arrayref( $sql, undef, @$bind_params );
    return wantarray ? @$uuids : $uuids;
}

##############################################################################

=head3 count

  my $count = Store->count($class_object, @search_params);

This method takes the same arguments as C<query>.  Returns a count of how
many rows a similar C<query> will return.

Any final constraints (such as "LIMIT" or "ORDER BY") will be discarded.

=cut

sub count {
    my ( $proto, $search_class, @search_params ) = @_;
    unless ( ref $search_class ) {
        $search_class = Kinetic::Meta->for_key($search_class);
    }
    pop @search_params if 'HASH' eq ref $search_params[-1];
    my $self = $proto->_from_proto;
    $self->_set_search_type( \@search_params );
    $self->_prepare_method($PREPARE);
    local $self->{search_class} = $search_class;
    $self->_set_search_data;
    my ( $sql, $bind_params ) =
      $self->_get_select_sql_and_bind_params( 'count(*)', \@search_params );
    my ($count) = $self->_dbh->selectrow_array( $sql, undef, @$bind_params );
    return $count;
}

##############################################################################

=begin private

=head2 Private methods

All private methods are considered instance methods.

=head3 _date_handler

  my ($where_token, $bind_params) = $store->_date_handler($date);

This method is used for returning the proper SQL and bind params for handling
incomplete dates.

Ultimately, all it does is dispatch on the operator to the correct date
handing method.

=cut

sub _date_handler {
    my ( $self, $search ) = @_;
    my $operator = $search->operator;
    return '=' =~ $operator ? $self->_eq_date_handler($search)
      : 'BETWEEN' eq $operator ? $self->_between_date_handler($search)
      : 'ANY'     eq $operator ? $self->_any_date_handler($search)
      : $self->_gt_lt_date_handler($search);
}

##############################################################################

=head3 _XXX_date_handler

  my ($where_token, $bind_params) = $self->_XXX_date_handler($search_object);

The date handler methods which the search object dispatches to are data store
dependent.  Thus, the methods in C<Kinetic::Store::DB> throw exceptions when
called to warn the user they must be overridden.

The various date handlers are:

=over 4

=item * C<_eq_date_handler>

This method is called when an exact date match is requested:

 $store->query($class, date => $date);

=item * C<_between_date_handler>

This method is called when a date search between two dates is requested.

 $store->query($class, date => [$date => $date2]);

=item * C<_any_date_handler>

This method is called when the user requests and "ANY" date search.

 $store->query($class, date => ANY(@dates));

=item * C<_gt_lt_date_handler>

This method is called when a user makes a C<GT>, C<LT>, C<GE>, or C<LE> date
search.

 $store->query($class, date => GE $date);

=back

=cut

sub _eq_date_handler {
    throw_unimplemented "This must be overridden in a subclass";
}

sub _gt_lt_date_handler {
    throw_unimplemented "This must be overridden in a subclass";
}

sub _between_date_handler {
    throw_unimplemented "This must be overridden in a subclass";
}

sub _any_date_handler {
    throw_unimplemented "This must be overridden in a subclass";
}

sub _get_select_sql_and_bind_params {
    my ( $self, $columns, $search_request ) = @_;
    my $constraints = pop @$search_request
      if 'HASH' eq ref $search_request->[-1];
    my $view = $self->search_class->key;
    my ( $where_clause, $bind_params ) =
      $self->_make_where_clause($search_request);
    $where_clause = "WHERE $where_clause" if $where_clause;
    my $sql = "SELECT $columns FROM $view $where_clause";
    $sql .= $self->_constraints($constraints) if $constraints;
    return ( $sql, $bind_params );
}

##############################################################################

=head3 _save

  $self->_save($object);

This method is called by C<save> to handle the actual saving of objects.  It
calls itself recursively if it encounters a contained object, thus allowing
for a single save to be called at the top level.

=cut

sub _save {
    my ( $self, $object ) = @_;

    # XXX So this is something we need to get implemented.
    #return $class unless $object->changed;
    $object->_save_prep;
    local $self->{search_class} = $object->my_class;
    local $self->{view}         = $self->{search_class}->key;
    local @{$self}{qw/columns values/};
    $self->_save( $_->get($object) ) for $self->{search_class}->ref_attributes;

    foreach my $attr ( $self->{search_class}->persistent_attributes ) {
        push @{ $self->{columns} } => $attr->_view_column;
        push @{ $self->{values} }  => $attr->raw($object);
    }

    return $object->id
      ? $self->_update($object)
      : $self->_insert($object);
}

##############################################################################

=head3 _query

  my @results = $self->_query(@search_params);

This method is called internally by both C<query> and C<lookup>.  Each method
sets whether or not the search is a CODE or STRING search and sets the search
type property accordingly.  It will I<remove> the search type from the front
of the search params, if it's there.

=cut

sub _query {
    my ( $self, @search_params ) = @_;
    $self->_set_search_type( \@search_params );
    if ( $self->{search_type} eq 'CODE' ) {

        # XXX we're going to temporarily disable full text searches unless it's
        # a code search. We need to figure out the exact semantics of the
        # others
        return $self->_full_text_search(@search_params)
          if 1 == @search_params && !ref $search_params[0];
    }
    $self->_set_search_data;
    my $columns = join ', ' => $self->_search_data_columns;
    my ( $sql, $bind_params ) =
      $self->_get_select_sql_and_bind_params( $columns, \@search_params );
    return $self->_get_sql_results( $sql, $bind_params );
}

##############################################################################

=head3 _set_search_type

  $self->_set_search_type(\@search_params);

This method is called internally by both C<query> C<count> and C<lookup>.  It
determines whether or not the search is a CODE or STRING search and sets the 
search type property accordingly.  It will I<remove> the search type from the
front of the search params, if it's there.

Also, if we have a string search, everything passed I<after> the search is
assumed to be a list of name/value pairs for the constraints.  These are 
also removed from the search params and replaced with a hashref containing
them.  This allows us to do this:

  $store->query($class,
    STRING   => 'name => "foo"',
    order_by => 'name'
  );

  # or
  $store->query($class,
    STRING     => 'name => "foo"',
    order_by   => 'name'
    sort_order => 'DESC',
  );

  # or
  $store->query($class,
    STRING     => 'name => "foo"',
    order_by   => 'name'
    sort_order => 'DESC',
    order_by   => 'age'
    sort_order => 'ASC',
  );

Note that if multiple C<order_by> parameters are present in a string search
and one C<sort_order> parameter is present, the C<sort_order> parameters
merely have to be in the same order as the C<order_by> parameters.  They are
not required to immediately follow them.

  $store->query($class,
    STRING     => 'name => "foo"',
    order_by   => 'name'
    order_by   => 'age'
    sort_order => 'DESC',
    sort_order => 'ASC',
  );

=cut

sub _set_search_type {
    my ( $self, $search_params ) = @_;
    {
        no warnings 'uninitialized';
        $self->{search_type} =
          !@$search_params ? 'CODE'
          : exists $SEARCH_TYPE_FOR{ $search_params->[0] }
          ? shift @$search_params
          : 'CODE';
    }
    if ( 'STRING' eq $self->{search_type} && @$search_params > 1 ) {
        my @constraints = splice @$search_params, 1;
        if ( @constraints % 2 ) {
            throw_search [
                'Odd number of constraints in string search:  "[_1]"',
                join ', ' => @constraints
            ];
        }
        my %constraint_for;
        while ( my ( $constraint, $value ) = splice @constraints, 0, 2 ) {
            $value = ASC  if 'ASC'  eq uc $value;    # convert to search subs
            $value = DESC if 'DESC' eq uc $value;    # convert to search subs

            # only "order_by" and "sort_order" constraints may
            # be multi-valued
            if ( $constraint =~ /^order_by|sort_order$/ ) {
                if ( exists $constraint_for{$constraint} ) {
                    push @{ $constraint_for{$constraint} } => $value;
                }
                else {
                    $constraint_for{$constraint} = [$value];
                }
            }
            else {
                $constraint_for{$constraint} = $value;
            }
        }
        $search_params->[1] = \%constraint_for;
    }
    $self;
}

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

Please note that the C<id> is only used for internal bookkeepping.  The
objects themselves are unaware of their C<id> and this should not be use
externally for any purpose.

=cut

sub _insert {
    my ( $self, $object ) = @_;
    my $columns = join ', ' => @{ $self->{columns} };
    my $placeholders = join ', ' => ( ('?') x @{ $self->{columns} } );
    my $sql = "INSERT INTO $self->{view} ($columns) VALUES ($placeholders)";
    $self->_prepare_method($CACHED);
    $self->_do_sql( $sql, $self->{values} );
    $self->_set_id($object);
    return $self;
}

##############################################################################

=head3 _set_id

  $store->_set_id($object);

This method is used by C<_insert> to set the C<id> of an object.  This is
frequently database specific, so this method may have to be overridden in a
subclass.  See C<_insert> for caveats about object C<id>s.

=cut

sub _set_id {
    my ( $self, $object ) = @_;

    # XXX This won't work for PostgreSQL, so be sure to override it.
    $object->id( $self->_dbh->last_insert_id( undef, undef, undef, undef ) );
    return $self;
}

##############################################################################

=head3 _update

  $store->_update($object);

This should only be called by C<save>.

Creates and executes an C<UPDATE> sql statement for the given object.

=cut

sub _update {
    my ( $self, $object ) = @_;
    my $columns = join ', ' => map { "$_ = ?" } @{ $self->{columns} };
    push @{ $self->{values} } => $object->id;
    my $sql = "UPDATE $self->{view} SET $columns WHERE id = ?";
    $self->_prepare_method($CACHED);
    return $self->_do_sql( $sql, $self->{values} );
}

##############################################################################

=head3 _do_sql

  $store->_do_sql($sql, \@bind_params);

Executes the given sql with the supplied bind params.  Returns the store
object.  Used for sql that is not expected to return data.

=cut

sub _do_sql {
    my ( $self, $sql, $bind_params ) = @_;
    my $dbi_method = $self->_prepare_method;
    my $sth        = $self->_dbh->$dbi_method($sql);

    # The warning has been suppressed due to "use of unitialized value in
    # subroutine entry" warnings from DBD::SQLite.
    no warnings 'uninitialized';
    $sth->execute(@$bind_params);
    return $self;
}

##############################################################################

=head3 _prepare_method

  $store->_prepare_method($prepare_method_name);

This getter/setter tells L<DBI|DBI> which method to use when preparing a
statement.

=cut

sub _prepare_method {
    my $self = shift;
    if (@_) {
        my $method = shift;
        unless ( $PREPARE eq $method || $CACHED eq $method ) {
            throw_invalid [ 'Invalid method "[_1]"', $method ];
        }
        $self->{prepare_method} = $method;
        return $self;
    }
    return $self->{prepare_method};
}

##############################################################################

=head3 _should_create_iterator

  $store->_should_create_iterator(1);
  if ($store->_should_create_iterator) {
    # use prepare_cached
  }

This getter/setter tells C<_get_sql_results> whether or not to use an
iterator.

=cut

sub _should_create_iterator {
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
results of a given C<query>.

=cut

sub _get_sql_results {
    my ( $self, $sql, $bind_params ) = @_;
    my $dbi_method = $self->_prepare_method;
    my $sth        = $self->_dbh->$dbi_method($sql);
    $self->_execute( $sth, $bind_params );

    if ( $self->_should_create_iterator ) {
        my $search_class = $self->{search_class};
        my $iterator     = Iterator->new(
            sub {
                my $result = $self->_fetchrow_hashref($sth) or return;
                local $self->{search_class} = $search_class;
                return $self->_build_object_from_hashref($result);
            }
        );
        return $iterator;
    }
    else {
        my @results;
        while ( my $result = $self->_fetchrow_hashref($sth) ) {
            push @results => $self->_build_object_from_hashref($result);
        }
        return \@results;
    }
}

##############################################################################

=head3 _execute

  $self->_execute($sth, \@bind_params);

This wrapper for C<$sth-E<gt>execute> may be subclassed if preprocessing of
bind params is necessary.

=cut

sub _execute {
    my ( $self, $sth, $bind_params ) = @_;
    $sth->execute(@$bind_params);
}

##############################################################################

=head3 _fetchrow_hashref

  my $hashref = $self->_fetchrow_hashref($sth);

This wrapper for C<$sth-E<gt>_fetchrow_hashref> may be subclassed if
post-processing of resulting data is necessary.

=cut

sub _fetchrow_hashref {
    my ( $self, $sth ) = @_;
    return $sth->fetchrow_hashref;
}

##############################################################################

=head3 _build_object_from_hashref

  my $object = $store->_build_object_from_hashref($hashref);

For a given hashref returned by C<$sth-E<gt>fetchrow_hashref>, this method
will return an object representing that row.  Note that the hashref may
represent multiple objects because an object can contain other objects.
C<_build_object_from_hashref> resolves this by utilizing the metadata
assembled by C<_set_search_data> to match the table columns for each object
and pull them off of the hashref with hash slices.

=cut

sub _build_object_from_hashref {
    my ( $self, $hashref ) = @_;
    my %objects_for;
    my %metadata_for = $self->_search_data_metadata;

    foreach my $package ( $self->_search_data_build_order ) {
        my $columns = $metadata_for{$package}{columns};

        # XXX Is the distinction here due to IDs?
        my @object_columns    = keys %$columns;
        my @object_attributes = @{$columns}{@object_columns};

        # create the object
        my %object;
        @object{@object_attributes} = @{$hashref}{@object_columns};
        $objects_for{$package}      = bless \%object => $package;

        # do we have a contained object?
        if ( defined( my $contains = $metadata_for{$package}{contains} ) ) {
            while ( my ( $key, $contained ) = each %$contains ) {
                delete $objects_for{$package}{$key};
                my $contained_package = $contained->package;
                my $view              = $contained->key;
                $objects_for{$package}{$view} =
                  $objects_for{$contained_package};
            }
        }
    }
    return $objects_for{ $self->search_class->package };
}

##############################################################################

=head3 _set_search_data

 $store->_set_search_data;

This method sets the search data used for the current search. Since this is
expensive, we cache search data for each search class. The search data
consists of the SQL columns that will be used in the search SQL and metadata
that C<_build_object_from_hashref> will use to break the returned SQL data
down into an object and its contained objects.

=cut

# XXX This is the information it'd be great to compile in at build time.
# Maybe a utility object to track all of this data would be useful...

my %SEARCH_DATA_FOR;

sub _set_search_data {
    my ($self) = @_;
    my $package = $self->search_class->package;
    unless ( exists $SEARCH_DATA_FOR{$package} ) {
        my ( @columns, %packages );
        my @classes_to_process = {
            class  => $self->search_class,
            prefix => '',
        };
        my @build_order;
        while (@classes_to_process) {
            foreach my $data ( splice @classes_to_process, 0 ) {
                my $package = $data->{class}->package;
                unshift @build_order => $package;
                foreach my $attr ( $data->{class}->attributes ) {
                    my $column      = $attr->_view_column;
                    my $view_column = "$data->{prefix}$column";

                    $packages{$package}{columns}{$view_column} = $column;
                    if ( my $class = $attr->references ) {
                        push @classes_to_process => {
                            class  => $class,
                            prefix => $class->key . $OBJECT_DELIMITER,
                        };
                        $packages{$package}{contains}{$column} = $class;
                    }
                    else {
                        push @columns => $view_column;
                    }
                }
            }
        }
        $SEARCH_DATA_FOR{$package}{columns}     = \@columns;
        $SEARCH_DATA_FOR{$package}{metadata}    = \%packages;
        $SEARCH_DATA_FOR{$package}{build_order} = \@build_order;
        $SEARCH_DATA_FOR{$package}{lookup}      = {};

        # merely a hashset.  The values are useless
        @{ $SEARCH_DATA_FOR{$package}{lookup} }{@columns} = undef;
    }
    $self->_search_data( $SEARCH_DATA_FOR{$package} );
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

=head3 _search_data_columns

  my @columns = $store->_search_data_columns;

Returns a list of the search data columns.  See C<_set_search_data>.

=cut

sub _search_data_columns { @{ shift->{search_data}{columns} } }

##############################################################################

=head3 _search_data_has_column

  if ($store->_search_data_has_column($column)) {
    ...
  }

This method returns true of false depending upon whether or not the current
search class has a database column matching the column name passed as an
argument.

=cut

sub _search_data_has_column {
    my ( $self, $column ) = @_;
    return exists $self->{search_data}{lookup}{$column};
}

##############################################################################

=head3 _search_data_metadata

  my @metadata = $store->_search_data_metadata;

Returns a list of the search data metadata.  See C<_set_search_data>.

=cut

sub _search_data_metadata { %{ shift->{search_data}{metadata} } }

##############################################################################

=head3 _search_data_build_order

  my @build_order = $store->_search_data_metadata;

Returns a list of the packages in the order they should be built by
C<_build_object_from_hashref>.  See C<_set_search_data>.

=cut

sub _search_data_build_order { @{ shift->{search_data}{build_order} } }

##############################################################################

=head3 _make_where_clause

 my ($where_clause, $bind_params) = $self->_make_where_clause(\@search_params);

This method returns a where clause and an arrayref of any appropriate bind
params for that where clause. Returns an empty string if no where clause can
be generated.

=cut

sub _make_where_clause {
    my ( $self, $search_request ) = @_;
    return ( '', [] ) unless @$search_request && $search_request->[0];

    # unless explicitly set elsewhere, the default search type is CODE
    $self->{search_type} ||= 'CODE';
    my $stream =
      $self->{search_type} eq 'CODE'    # XXX we may need to clean this up later
      ? code_lexer_stream($search_request)
      : string_lexer_stream( $search_request->[0] );
    my $ir = parse( $stream, $self );
    my ( $where_clause, $bind_params ) =
      $self->_convert_ir_to_where_clause($ir);
    $where_clause = "" if '()' eq $where_clause;
    return ( $where_clause, $bind_params );
}

sub _convert_ir_to_where_clause {
    my ( $self, $ir ) = @_;
    my ( @where, @bind );
    while ( my $term = shift @$ir ) {
        unless ( ref $term ) {    # Currently, this means its 'OR'
            pop @where if 'AND' eq $where[-1];
            push @where => $term;
            my ( $token, $bind ) =
              $self->_convert_ir_to_where_clause( shift @$ir );
            push @where => $token;
            push @bind  => @$bind;

            # (LOWER(name) = LOWER(?) OR (LOWER(desc) = LOWER(?) AND this = ?))
        }
        elsif ( Search eq ref $term ) {
            my $search_method = $term->search_method;
            my ( $token, $bind ) = $self->$search_method($term);
            push @where => $token;
            push @bind  => @$bind;
        }
        elsif ('ARRAY' eq ref $term
            && 'AND'  eq $term->[0]
            && Search eq ref $term->[1] )
        {
            shift @$term;
            my ( $token, $bind ) = $self->_convert_ir_to_where_clause($term);
            push @where => $token;
            push @bind  => @$bind;
        }
        else {
            panic
              'Failed to convert IR to where clause.  This should not happen.',;
        }
        unless ( $where[-1] =~ $GROUP_OP ) {
            push @where => 'AND';
        }
    }

    # XXX We should look into what it takes to fix this.  Sometimes we have
    # a group op on the end of the @where array.  We don't want that.
    pop @where
      if defined $where[-1]
      && $where[-1] =~ $GROUP_OP;
    return '(' . join ( ' ' => @where ) . ')', \@bind;
}

##############################################################################

=head3 _is_case_sensitive

  if($store->_is_case_sensitive) {
    ...
  }

Returns a boolean value indicating whether a particular data store data type
is case sensitive.

=cut

my %case_insensitive = map { $_ => 1 } qw/string/;

sub _is_case_sensitive {
    my ( $self, $type ) = @_;
    return exists $case_insensitive{$type};
}

##############################################################################

=head3 _handle_case_sensitivity

  my ($column, $place_holder) = $store->_handle_case_sensitivity($column);

This method takes a column and return the correct column token and bind param
based upon whether or not the column's data type is case-insensitive.

=cut

sub _handle_case_sensitivity {
    my ( $self, $column ) = @_;

    # if 'type eq string' for attr (only relevent for postgres)
    my $orig_column  = $column;
    my $search_class = $self->{search_class};
    if ( $column =~ /$OBJECT_DELIMITER/ ) {
        my ( $key, $column2 ) = split /$OBJECT_DELIMITER/ => $column;
        $search_class = Kinetic::Meta->for_key($key);
        $column       = $column2;
    }
    if ($search_class) {
        $column = "LOWER($orig_column)"
          if $self->_is_case_sensitive(
            $search_class->attributes($column)->type );
    }
    return $column =~ /^LOWER/
      ? ( $column, 'LOWER(?)' )
      : ( $orig_column, '?' );
}

##############################################################################

=head3 _XXX_SEARCH

 my ($where_token, $bind_params) = $store->_XXX_SEARCH($search_object); 

These methods all take a L<Kinetic::Store::Seach|Kinetic::Store::Search>
object as an argument and return a where token and an array ref of bind
params.  There "where token" will be a snippet of an SQL where clause that is
valid SQL, with bind params.

All C<_XXX_SEARCH> methods are generated by 
L<Kinetic::Store::Seach|Kinetic::Store::Search>.

=over 4

=item * _ANY_SEARCH

=item * _EQ_SEARCH

=item * _NULL_SEARCH

=item * _GT_LT_SEARCH

=item * _BETWEEN_SEARCH

=item * _MATCH_SEARCH

=item * _LIKE_SEARCH

=back

=cut

sub _ANY_SEARCH {
    my ( $self,    $search )       = @_;
    my ( $negated, $value )        = ( $search->negated, $search->data );
    my ( $column,  $place_holder ) =
      $self->_handle_case_sensitivity( $search->column );
    my $place_holders = join ', ' => ($place_holder) x @$value;
    return ( "$column $negated IN ($place_holders)", $value );
}

sub _EQ_SEARCH {
    my ( $self,   $search )       = @_;
    my ( $column, $place_holder ) =
      $self->_handle_case_sensitivity( $search->column );
    my $operator = $search->operator;
    return ( "$column $operator $place_holder", [ $search->data ] );
}

sub _NULL_SEARCH {
    my ( $self, $search ) = @_;
    my ( $column, $negated ) = ( $search->column, $search->negated );
    return ( "$column IS $negated NULL", [] );
}

sub _GT_LT_SEARCH {
    my ( $self, $search ) = @_;
    my $value    = $search->data;
    my $operator = $search->operator;
    my ( $column, $place_holder ) =
      $self->_handle_case_sensitivity( $search->column );
    return ( "$column $operator $place_holder", [$value] );
}

sub _BETWEEN_SEARCH {
    my ( $self,    $search )       = @_;
    my ( $negated, $operator )     = ( $search->negated, $search->operator );
    my ( $column,  $place_holder ) =
      $self->_handle_case_sensitivity( $search->column );
    return ( "$column $negated $operator $place_holder AND $place_holder",
        $search->data );
}

sub _MATCH_SEARCH {
    my ( $self,   $search )       = @_;
    my ( $column, $place_holder ) =
      $self->_handle_case_sensitivity( $search->column );
    my $operator = $search->negated ? '!~*' : '~*';
    return ( "$column $operator $place_holder", [ $search->data ] );
}

sub _LIKE_SEARCH {
    my ( $self,    $search )       = @_;
    my ( $negated, $operator )     = ( $search->negated, $search->operator );
    my ( $column,  $place_holder ) =
      $self->_handle_case_sensitivity( $search->column );
    return ( "$column $negated $operator $place_holder", [ $search->data ] );
}

##############################################################################

=head3 _constraints

 my $constraints = $store->_constraints(\%constraints);

This method takes a hash ref of "order by" and "limit" constraints as
described in L<Kinetic::Store|Kinetic::Store> and return an sql snippet
representing those constraints.

=cut

sub _constraints {
    my ( $self, $constraints ) = @_;
    my $sql = '';
    foreach my $constraint ( keys %$constraints ) {
        if ( 'order_by' eq $constraint ) {
            $sql .= $self->_constraint_order_by($constraints);
        }
        elsif ( 'limit' eq $constraint ) {
            $sql .= $self->_constraint_limit($constraints);
        }
    }
    return $sql;
}

##############################################################################

=head3 _constraint_order_by

  my $order_by = $store->_constraint_order_by($constraints);

Given optional constraints passed to a search, this method returns a valid
"order by" constraint.

=cut

sub _constraint_order_by {
    my ( $self, $constraints ) = @_;
    my $sql   = ' ORDER BY ';
    my $value = $constraints->{order_by};

    # XXX Default to ASC?
    my $sort_order = $constraints->{sort_order};
    $value      = [$value]      unless 'ARRAY' eq ref $value;
    $sort_order = [$sort_order] unless 'ARRAY' eq ref $sort_order;

    # normalize . to __
    s/\Q$ATTR_DELIMITER\E/$OBJECT_DELIMITER/eg
      foreach @$value;    # one.name -> one__name
    my @sorts;

    # XXX Perl 6 would so rock for this...
    for my $i ( 0 .. $#$value ) {
        my $sort = $value->[$i];
        $sort .= ' ' . uc $sort_order->[$i]->() if defined $sort_order->[$i];
        push @sorts => $sort;
    }
    $sql .= join ', ' => @sorts;
    return $sql;
}

##############################################################################

=head3 _constraint_limit

  my $limit = $store->_constraint_limit($constraints);

Given optional constraints passed to a search, this method returns a valid
"limit" constraint.

=cut

sub _constraint_limit {
    my ( $self, $constraints ) = @_;
    my $sql = " LIMIT $constraints->{limit}";
    if ( exists $constraints->{offset} ) {
        $sql .= " OFFSET $constraints->{offset}";
    }
    return $sql;
}

##############################################################################

=head3 _dbh

  my $dbh = $store->_dbh;

Returns the current database handle.

=cut

sub _dbh {
    my $self = shift->_from_proto;
    return $self->{dbh} || DBI->connect_cached( $self->_connect_args );

    # XXX Switch to this single line if connect_cached() ever stops resetting
    # AutoCommit. See http://www.nntp.perl.org/group/perl.dbi.dev/3892
    # DBI->connect_cached(shift->_connect_args);
}

##############################################################################

=head3 _connect_args

  my @connect_args = $store->_connect_args;

Abstract method that must be overridden in a subclass.  Returns valid
C<DBI|DBI> connect args for the current store.

=cut

sub _connect_args {
    throw_unimplemented "This must be overridden in a subclass";
}

##############################################################################

=head3 _add_store_meta

  package Kinetic;
  my $km = Kinetic::Meta->new;
  Kinetic::Store->_add_store_meta($km);

This protected method adds an "id" attribute to the Kinetic base class, solely
for use from within database stores. May be overridden in subclasses to add
other metadata.

=cut

sub _add_store_meta {
    my ( $self, $km ) = @_;
    $km->add_attribute(
        name     => 'id',
        label    => 'Database Primary Key',
        type     => 'whole',
        required => 1,
        indexed  => 1,
        unique   => 1,
        once     => 1,
        authz    => Class::Meta::RDWR,
        view     => Class::Meta::TRUSTED,
    );
    return $self;
}

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
