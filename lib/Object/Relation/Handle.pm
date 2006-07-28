package Object::Relation::Handle;

# $Id$

use strict;
use aliased 'Object::Relation::Cache';
use Object::Relation::Functions qw(:class);
use Object::Relation::Exceptions qw(
    throw_search
    throw_unimplemented
);

use version;
our $VERSION = version->new('0.1.1');

=head1 Name

Object::Relation::Handle - The Object::Relation data storage class

=head1 Synopsis

  use Object::Relation::Handle;
  use Object::Relation::Biz::Subclass;
  my $iter = Object::Relation::Handle->query('Object::Relation::Biz::SubClass' =>
                                    attr => 'value');

=head1 Description

This class handles all of the work necessary to communicate with back-end
storage systems. Object::Relation::Handle itself is an abstract class; its
subclasses will implement its interface for different storage devices: RDBMSs,
OODBMSs, XML Files, LDAP, or whatever. The canonical storage implementation is
L<Object::Relation::Handle::DB::Pg|Object::Relation::Handle::DB::Pg>, for
PostgreSQL 8.0 or later. Others might include
L<Object::Relation::Handle::DB::SQLite|Object::Relation::Handle::DB::SQLite> for
SQLite, Object::Relation::Handle::DB::mysql for MySQL 5.0 or later, and
Object::Relation::Handle::LDAP.

=cut

# Here are the functions we'll need to export to get the search parameter
# syntax to work.

# These are simple constants we can use for the sort_order parameter. These
# are used for the DBI storage classes only.

my %tokens;

BEGIN {
    $tokens{comparison} = [qw/LIKE GT LT GE LE NE MATCH/];
    $tokens{logical}    = [qw/AND OR/];
    $tokens{sorting}    = [qw/ASC DESC/];

    no strict 'refs';
    foreach my $token ( @{ $tokens{comparison} } ) {
        *$token = sub($) {
            my $value = shift;
            sub {
                shift || (), [ 'COMPARE', $token ], [ 'VALUE', $value ];
            };
        };
    }
    foreach my $token ( @{ $tokens{logical} } ) {
        *$token = sub {
            my @values = @_;
            sub { $token, \@values }
        };
    }
    foreach my $token ( @{ $tokens{sorting} } ) {
        *$token = sub() {
            sub { $token }
          }
    }
    push @{ $tokens{comparison} } => qw/NOT EQ BETWEEN ANY/;
}

use Exporter::Tidy
  comparison => $tokens{comparison},
  logical    => $tokens{logical},
  sorting    => $tokens{sorting};

sub NOT($) {
    my $value = shift;

    #$value    = BETWEEN($value) if 'ARRAY' eq ref $value;
    my $negated = [ 'KEYWORD', 'NOT' ];
    sub {
        return ( 'CODE' eq ref $value )
          ? $value->($negated)
          : ( $negated, _value_token($value) );
    };
}

sub EQ($) {
    my $value = shift;
    sub {
        if ( 'ARRAY' eq ref $value ) {
            return ( shift || (), [ 'KEYWORD', 'BETWEEN' ],
                _value_token($value), );
        }
        else {
            return ( shift || (), [ 'COMPARE', 'EQ' ], _value_token($value) );
        }
      }
}

sub _value_token {
    my $value = shift;
    return !defined $value ? [ 'UNDEF', 'undef' ]
      : 'ARRAY' ne ref $value ? [ 'VALUE', $value ]
      : 2 == @$value ? (
        [ 'OP',    '[' ],
        [ 'VALUE', $value->[0] ],
        [ 'OP',    ',' ],
        [ 'VALUE', $value->[1] ],
        [ 'OP',    ']' ]
      )
      : throw_search [
        'BETWEEN searches may only take two values.  You have [_1]',
        scalar @$value
      ];
}

sub BETWEEN($) {
    my $value = shift;
    sub { shift || (), [ 'KEYWORD', 'BETWEEN' ], _value_token($value) };
}

sub ANY {
    my @args = @_;
    my @values;
    while (@args) {
        my $value = shift @args;
        push @values => [ 'VALUE', $value ];
        push @values => [ 'OP', ',' ] if @args;
    }
    sub {
        shift || (), [ 'KEYWORD', 'ANY' ], [ 'OP', '(' ], @values,
          [ 'OP', ')' ];
    };
}

my @redispatch = qw(
  lookup
  query_uuids
  squery_uuids
  query
  squery
  count
  save
);

foreach my $method (@redispatch) {
    no strict 'refs';
    *$method = sub {
        my $self = shift;
        unless ( ref $self ) {    # they called it as a class method
            $self = $self->new;
        }
        $self->$method(@_);
    };
}


##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

  my $store = Object::Relation::Handle->new(
      class => 'DB::Pg',
      cache => 'Memcached',
      dsn   => 'dbi:Pg:dbname=obj_rel',
      user  => 'obj_rel',
      pass  => 'obj_rel',
  );

Creates and returns a new store object. This is a factory constructor; it will
return an object of the subclass specified by the C<class> parameter. The
default parameters are:

=over

=item class

The subclass of Object::Relation::Handle to use. If the class is under the
Object::Relation::Handle namespace, you can leave out "Object::Relation::Handle". Otherwise, use
the full class name. Defaults to "DB::SQLiite".

=item cache

The subclass of L<Object::Relation::Cache|Object::Relation::Cache> to use for
caching. If the class is under the Object::Relation::Cache namespace, you can
leave out "Object::Relation::Cache". Otherwise, use the full class name. Defaults
to "File".

=back

All other parameters are specific to subclasses of Object::Relation::Handle; see the
revelant subclass for details.

=cut

sub new {
    my ($class, $params) = @_;
    $class = load_class(delete $params->{class}, __PACKAGE__, 'DB::SQLite')
        if $class eq __PACKAGE__;

    return bless {
        cache  => Object::Relation::Cache->new( delete $params->{cache} ),
        config => $params,
    } => $class;
}

##############################################################################
# Class Methods
##############################################################################

=head2 Instance Methods

=head3 lookup

  my $bric_obj = $store->lookup($class, uuid => $uuid);
  $bric_obj = $store->lookup($class, unique_attr => $value);

Method to look up objects in the Object::Relation data store by a unique identifier.
Most often the identifier used will be  globally unique object identifier.
However, for Object::Relation classes that allow unique identifiers other than UUIDs
-- that is, system-wide (rather than globally) unique identifiers -- then an
appropriate key/value pair may be used for the lookup. No SQL wildcards or
regular expressions will be allowed. The lookup value must be a complete
value.

Most often this method will not be used directly, but rather by calling the
C<lookup()> method on Object::Relation classes.

B<Throws:>

=over

=item Exception::DA

=back

=head3 query

  my $iter = $store->query( $class => @search_params );
  $iter = $store->query( $class => @search_params,
                          \%constraints );

Use this method to search the Object::Relation data store for all of the objects of a
particular Object::Relation class that meet a specified set of search parameters. The
C<$class> argument is required, while the search parameters are optional but
highly recommended (otherwise it will "find" I<all> of the objects in the
class). See L<Search Parameters Explained|"SEARCH PARAMETERS EXPLAINED"> for
details on specifying search parameters. Returns a Object::Relation::Collection
object that may be used to fetch each of the objects found by the search. If
no objects are found, C<query> returns an empty iterator. See
L<Object::Relation::Collection|Object::Relation::Collection> for details on its
interface. See the documentation for the C<query> method in a particular class
for a list of object attributes to search by in that class.

An optional hash reference of search modifiers may be passed in as the final
argument to C<query>. The available search modifiers are:

=over 4

=item order_by

  my $iter = $store->query( $class, @search_params,
                             { order_by => $attr } );

The name of an object attribute or an array reference of object attributes to
sort by. All sorting is done in a case-insensitive fashion. The actual sort
order is dependent on the ordering rules of your data store. I<Do not> pass
"uuid" as a sort parameter, as it will always be used for sorting, anyway. If
this modifier isn't passed in, the class will select a default or set of
default attributes to sort by.

=item sort_order

  my $iter = $store->query( $class, @search_params,
                             { order_by   => $attr,
                               sort_order => ASC } );


The direction in which to sort the the C<order_by> attributes. The possible
values are C<ASC> and C<DESC>. If C<order_by> is a single attribute, then
C<sort_order> should be a single value, or will default to C<ASC>. If
C<order_by> is an array of attributes, then C<sort_order> may also be an array
of directions; any directions missing for a corresponding C<order_by>
attribute will default to C<ASC>. By default, all searches will be C<ASC>.

Passing C<sort_order> without a corresponding C<order_by> constraint will have
no effect.

=item limit

  my $iter = $store->query( $class, @search_params,
                             { limit => 50 } );

Limits the number of objects returned to a given number. This is useful for
search interfaces that need to paginate search results without loading
thousands or even millions of objects just to load 50 of them. Best used in
combination with C<offset>.

=item offset

  my $iter = $store->query( $class, @search_params,
                             { limit  => 50 } );
                               offset => 200 );

Returns an iterator of Object::Relation objects starting with the number C<offset> in
the search results. In the above example, the call to C<query> would return
only 50 objects, starting with the 200th object found in the search. This is
implemented in such a way that the data store does all the work and returns
only the results desired. It is therefore a very efficient way to fetch results
for pagination.

Passing C<offset> without a corresponding C<limit> constraint will have no
effect.

=back

B<Throws:>

=over

=item Exception::DA

=back

=head3 query_uuids

  my @uuids = $store->query_uuids( $class => @search_params );
  my $uuids_aref = $store->query_uuids( $class => @search_params );

Returns a list or array reference of UUIDs for the the class C<$class> based
on the search parameters. See L<Search Parameters Explained|"SEARCH PARAMETERS
EXPLAINED"> for details on specifying search parameters. Returns an empty list
in an array context and an empty array reference in a scalar context when no
results are found.

B<Throws:>

=over 4

=item Exception::DA

=back

=head3 squery_uuids

  my @uuids = $store->squery_uuids( $class => "@search_params" );
  my $uuids_aref = $store->squery_uuids( $class => "@search_params" );

Same as C<query_uuids> but uses a string search.

=head3 count

  my $count = $store->count( $class => @search_params );

Returns a count of the number of objects that would be found by C<query>
(or the number of UUIDs that would be returned by C<query_uuids()>) for the
class C<$class> based on the search parameters. See L<Search Parameters
Explained|"SEARCH PARAMETERS EXPLAINED"> for details on specifying search
parameters. Returns "0" when no results would be found in the search.

The C<count()> method will most often be called to determine how many pages to
provide links for when paginating search results in the UI. Therefore, for
purposes of efficiency, the result of a call to C<count()> will be cached, so
that subsequent calls to C<count()> with the same parameters will not incur
the database overhead.

B<Throws:>

=over 4

=item Exception::DA

=back

=head3 save

  $bric_obj = $store->save($bric_obj);

Saves any changes to the Object::Relation object to the data store. Returns the
Object::Relation object on success and throws an exception on failure. No part of the
Object::Relation object or its parts will ever be saved unless and until the
C<save()> method is called. The only exception is when the Object::Relation object is
contained in another object (such as via a has-a relationship), when that
other will be saved, as well. That is to say, C<save()> saves the Object::Relation
object and each of its contained objects.

The C<save()> method will also delete an object from the data store if its
C<state> is set to C<PURGE>. This feature should be used with care, however,
since in an RDBMS, at least, C<DELETE>s will likely cascade.

For storage back-ends that support transactions, all transaction handling will
be managed by C<save()>. When called, C<save()> will start a transaction. At
the end of the method, it will either commit the transaction or rollback the
transaction, depending on whether an error was thrown. If the transaction is
rolled back, the exception will be propagated to the caller. Any contained
objects that have their C<save()> methods called from within the context of
the call to the containing object's C<save()> method will be a part of the
same transaction. This approach keeps transactions neatly encapsulated in a
single call to C<save()>, mirroring the encapsulation of Object::Relation objects.

B<Throws:>

=over 4

=item Error::Undef

=item Error::Invalid

=item Exception::DA

=back

=begin private

=head1 Private Methods

=head2 Private Class Methods

=head3 _add_store_meta

  package Object::Relation::Base;
  my $km = Object::Relation::Meta->new;
  Object::Relation::Handle->_add_store_meta($km);

This protected method is the interface that allows store subclasses to add
data-store dependendent attributes to the Object::Relation base class via the
Object::Relation::Meta object used to construct the Object::Relation base class. It will
B<only> be called once, during compilation, by Object::Relation::Base, to add
any necessary attributes or other metadata objects to ease the implemtation of
the data store.

The default implementation of this method is a no-op. See
L<Object::Relation::Handle::DB> for an example implemntation.

=cut

sub _add_store_meta {
    my $self = shift;
    $self = $self->new unless ref $self;
    $self->_add_store_meta(@_);
}

##############################################################################

=head3 _cache

  my $cache = $store->_cache;

Read-only method which returns the cache object.

See L<Object::Relation::Cache|Object::Relation::Cache>.

=cut

sub _cache {
    return shift->{cache};
}

##############################################################################

=head3 _prep_search_token

  my $search = $store->prep_search_token($search);

Examines a L<Object::Relation::Search|Object::Relation::Search> object created
by L<Object::Relation::Parser|Object::Relation::Parser> to ensure that it has
valid search data.

=cut

sub _prep_search_token {
    throw_unimplemented [
        '"[_1]" must be overridden in a subclass',
        '_prep_search_token',
    ];
}

##############################################################################

=head1 Search Parameters Explained

The specification for search parameters to be passed to the C<query>,
C<query_uuids()>, and C<count()> methods has been designed to maximize
flexibility and ease of use by making it as Perlish as possible. This means
that you can search on multiple object attributes of different types,
attributes on contained or related objects, and values that are equivalent to
or similar to a search string or matching a regular expression. You can search
for values between two values, and for values that are C<NULL> (or undefined).

This section details the search parameters semantics in detail.

=head2 Example Classes

Since there is potentially a lot to specifying search parameters depending on
the complexity of the search you want to do, we'll include a lot of examples
here. The examples will make use of a couple of phony Object::Relation
classes. Object::Relation::Phony::Person has the following attributes:

=over 4

=item uuid

=item last_name

=item first_name

=item birthday

=item fav_number

=item bio

=back

It also may be associated with zero or more phony Object::Relation::Phony::Contact
objects, which have the following attributes:

=over 4

=item uuid

=item type

=item label

=item contact

=back

=head2 Search Basics

=head3 Full Text Search

At its simplest, a search  can be a simple keyword search:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'Perl inventor');

Passing a single string as the search parameter triggers a full text search of
all the objects of the class and returns all of the active objects that match
the search. The full text substring search works because an XML representation
of each Object::Relation business object is always kept in the data store. The
semantics of the search results will, however, be dependent on the full text
indexing of the data store in question. See the relevant Object::Relation::Handle
subclasses for details on their full text search implementations.

Note that if you need to search for objects with inactive or deleted states,
you'll need to do an attribute search, instead.

=head3 Attribute Search

The most common use of the search interface is to specify certain object
attributes to search against.

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name  => 'Wall',
                            first_name => 'larry');

In this example, we're searching for all the phony person objects with the
last name 'Wall' and the first name 'larry'. Note that even though the case is
different in the two arguments, both will return the same results. This is
because searches against strings are always case-insensitive in
Object::Relation.

With attribute searches, all the attributes searched against are C<AND>ed
together -- that is, the objects returned must match I<all> of the search
parameters (But see L<Compound Searches|"Compound Searches"> for an
alternative approach).

By default, searches will never return Object::Relation objects with their state
attribute set to DELETE. If you wish to search for deleted objects, explicitly
specify the C<state> attribute in your search parameters.

=head3 Contained Object Searching

Searches can also be made for objects based on contained or related objects,
or based on the attributes of contained or related objects by using a simple
dot notation. All Object::Relation classes have a unique key returned by their
C<my_key()> methods. This unique key can be used to identify which types of
contained or related objects to search against by specifying search parameters
using this key.

In our example classes, phony person objects can contain any number of phony
contact objects. If the value returned by
C<< Object::Relation::Phony::Contact->my_key >> is "contact", then this search:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                             contact => $contact);

Would return the phony person object or objects with which the contact was
associated. This approach will work whether zero, one, or many objects are
associated with or contained in a person object.

In addition, searches can be made based on the I<attributes> of contained or
related objects by specifying the contained class key name plus the attribute
of that class to search, separated by a dot. For example, this search:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'contact.type' => 'email');

Will return all phony person objects containing a contact with its type
attribute set to 'email'. This approach can be used for any combination of
attributes on the object or contained objects. For example, this search:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'last_name'     => 'Wall',
                            'contact.type'  => 'email',
                            'contact.value' => 'larry@wall.org');

Returns all phony person objects with the last name attribute 'Wall', and a
contact with the type 'email' and the value 'larry@wall.org'. Note that even
though there are multiple contact attributes specified to search, the search
attributes for contact are truly C<AND>ed, meaning that no objects will be
returned with one contact with the type 'email' and another contact with the
value 'larry@wall.org'. The two attributes must be a part of the same contact
object (But see L<Compound Searches|"Compound Searches"> for a a method to get
the other behavior).

Attentive readers will realize that the first example, wherein we passed in a
<$contact> object as the search criterion, is actually a shortcut for using
its C<uuid> attribute. The equivalent would be:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'contact.uuid' => $contact->get_uuid);

=cut

##############################################################################

=head3 squery

  my $iter = $store->squery('Object::Relation::Phony::Person' => <<'END_QUERY');
      last_name     => 'Wall',
      contact.type  => 'email',
      contact.value => 'larry@wall.org'
  END_QUERY

This method is the same as C<query>, but uses a string search instead of a
code search.  Note that a string search is identical to a code search but the
code is wrapped in quotes (thus being a string).

=head3 Attribute Types

Object::Relation supports three basic types of attributes: strings (such as the
C<last_name> and C<bio> attributes of Object::Relation::Phony::Person), numbers,
(such as the C<fav_number> attribute of Object::Relation::Phony::Person). and dates
and times (such as the C<birthday> attribute of Object::Relation::Phony::Person).
Each type of attribute requires that the appropriate type of data be passed as
the search value. Thus, string attributes require string search values,
numeric attributes require numeric values, and date and times require
DateTime objects to be passed as their values.

=over 4

=item Strings

We've already had a quick look at searching on strings, but let's do it
again, just for fun:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name => 'Conway',
                            fist_name => 'Damian');

This search will return an iterator of all phony person objects with the
first name attribute 'Damian' and the last name attribute 'Conway'. String
searches are always case-insensitive, so searches will also succeed with the
last names "conway", "CONWAY", and "cOnWAy".

=item Numbers

So let's look at numbers:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            fav_number  => 42);

This search returns all phony person objects with the C<fav_number> attribute
set to the number 42. Pretty simple, eh? You can of course also combine
numeric attribute search parameters with other types of search parameters:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name   => 'Adams',
                            fav_number  => 42);

This search will return all phony person objects with the last name 'Adams'
(or 'adams' or 'ADAMS' or 'aDaMs' -- you get the idea) and the favorite number
42.

=item Dates

Date and time attributes are searched a little differently, with DateTime
objects:

  my $date = DateTime->new( year  => 1968,
                            month => 12,
                            day   => 19 );

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            birthday => $date);

This search will return all phony person objects with a birth date of December
19, 1968. Note that even if C<birthday> is technically a datetime field rather
than simple a date field, it will return all persons with a their C<birthday>
attributes set to sometime on that date, regardless of the time.

The reason DateTime objects are required rather than date strings is that all
times are stored in the data store in UTC. By specifying a DateTime object,
Object::Relation can convert from whatever time zone is specified in the DateTime
object to UTC before performing the query.

For datetime fields, you can of course specify more exact times:

  my $date = DateTime->new( year   => 1968,
                            month  => 12,
                            day    => 19,
                            hour   => 19,
                            minute => 42,
                            second => 18 );

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                                      birthday => $date);

This search of course returns all the phony person objects with a birth date
and time of 19 December 1968, at 19:42:18. Any other phony person objects with
their C<birthday> attribute set to any other time on the same date will of
course be excluded from the search results.

Queries on partial dates can be carried out using DateTime::Incomplete. For
example, if you wanted to search for all persons with a date of 19 December
without regard to year, you can do it like this:

  my $date = DateTime::Incomplete->new( month => 12,
                                        day   => 19 );

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            birthday => $date);

=back

=head2 Search Parameters Values

The ability to search for exact values is all well and good, but leaves
much to be desired in terms of flexibility. What if you want to find all
objects with a null attribute? Or with an attribute between two values?
Or with any attribute but a specific one? It is to solve these problems
that we proudly present details on specifying more sophisticated search
parameters values.

=head3 C<undef>

First and foremost is the need to find objects with a null attribute. From the
Perl point of view, C<undef> is roughly equivalent to null (and after all,
what works for DBI will surely work for us, eh?), so just use undef to
search for null attributes:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            birthday => undef);

This search will return all phony person objects for which the C<birthday>
attribute has no value -- that is, it is "undefined" or "null". And of course,
this value can be used in combination with other search parameters:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'last_name'     => 'wall',
                            'contact.value' => undef);

This search returns all phony person objects with the C<last_name> attribute
set to 'wall' and at least one contact object with an undefined value.

=head3 Overloaded Object Values

Any Object::Relation objects overloaded to output a value in a double-quoted string
context will automatically have their strings used for the value if you pass
in the overloaded object as the search parameter value. For example:

  my $string_obj = Object::Relation::Biz::Value::String->new("Salzenberg");
  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name => $string_obj);

This search will find all of the phony person objects with their C<last_name>
attributes set to "Salzenberg". The same deal works for numbers, too:

  my $numb_obj = Object::Relation::Biz::Value::Number->new(42);
  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            fav_number => $numb_obj);

It's effectively the same for dates, as well, only a DateTime-inherited object
I<must> be the argument for a date search parameter, as already discussed.

Note that the only situation where a stringifiable object will not be
stringified are searches against contained or related objects. For example,
even if our phony contact objects stringify to their value attributes, an
argument to a C<contact> search parameter will always search by the contact
object ID:

  # XXX the docs say "ID", but this says UUID.  Which is it?
  # right now I'll assume ID as its easier.  However, is this
  # distinction necessary?  Is it OK to just search by "person
  # has this object" and complete hide from the developer the
  # fact that it's joining on anything?

  # Search by contact object UUID.
  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'contact' => $contact);

To search against the value, you would need to specify the C<value> search
parameter explicitly:

  # Search by contact object value.
  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'contact.value' => $contact);

But then, in case such as this, it may be best to just to be explicit:

  # Search by contact object value.
  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'contact.value' => $contact->get_value);

=head3 Value Ranges

To search for objects with an attribute that falls within a range of values,
simply pass an array reference of the two values to search between, and the
objects returned will have the attribute in question set to a value between
those two values, inclusive. For example, to find all of the phony person
objects with favorite numbers between 1 and 100, do this:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'fav_number' => [1 => 100]);

Yes, that's it. Any values in the array beyond the second will be ignored.
It works on dates and strings, too:

  my $date1 = DateTime->now;
  my $date2 = $date1->clone->subtract( years => 1 );
  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'birthday' => [$date2 => $date1]);

This search returns all phony person objects with their C<birthday> attributes
set for sometime in the last year.

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'last_name' => ['l' => 'm']);

And this search returns all phony person objects with their C<last_name>
attributes set between 'l' and 'm' -- which essentially works out to any last
names starting with the letter 'l'. The comparisons are of course made
case-insensitively, so "Lawrence" would be included as well as "l'Oriale".

=head3 Value Operators

Well that was easy, wasn't it? But wait, there's more! But you knew that from
having read the questions at the beginning of this section, didn't you? Well,
here are the details. Object::Relation provides a number of unary operators to affect
how search parameters values are treated. These are designed to give you
greater flexibility in building your search parameters to get the objects you
need. Most have the same names as standard Perl operators, the only difference
being an initial uppercase letter. This design, we hope, makes the Object::Relation
search value operators both familiar and easy to remember.

Please note that value operators can never be more than two deep.

And so, without further ado, here they are:

=over

=item NOT

The C<NOT> operator indicates a search for objects where an attribute does
I<not> have a value matching our parameters. If used, the C<NOT> operator must
always be the first operator.  For example, say you want to find all the phony
person objects whose last name is I<not> "Wall". Here's how you do it:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'last_name' => NOT 'wall');

Simple, eh? It can be used with value ranges, as well. To find all of the
persons whose birthday did I<not> occur in the last year, try this:

  my $date1 = DateTime->now;
  my $date2 = $date1->clone->subtract( years => 1 );
  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'birthday' => NOT [$date2 => $date1]);

And naturally it works with numbers, too:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'fav_number' => NOT 42); # Sillies.

=item LIKE

The C<LIKE> operator is used to do a simple pattern match against a value.  Please
consult your actual data store's documentation for exact implementation.

In the case of a RDBMs data store, this translates directly to an SQL C<LIKE>
operator.

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'first_name' => LIKE '_arry'); # Barry, Harry, or Larry

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'first_name' => LIKE '%ry'); # also matches Gary and Terry

=item MATCH

B<Note:>  Not all data stores will support the MATCH operator.  For those that
do, please read the documentation for that data store to understand how it is
to be used.

The C<MATCH> operator indicates that the search value is a regular expression.
That's right, as long as the type of attribute you're searching is a string
data type (or your data store can use regular expressions on numeric and date
data), you can specify a regular expression to match against it (provided, of
course, that the data store supports regular expressions at all). All regular
expression matching is implicitly case-insensitive. Otherwise, consult the
documentation for your data storage engine for its supported regular expression
syntax.

Here are a couple of simple examples to get you started.

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'last_name' => MATCH '^wa');

This search returns all phony person objects with their C<last_name> attribute
matching the regular expression C</^wa/>, that is, that start with the string
"wa".

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'contact.type'  => MATCH 'email',
                            'contact.value' => MATCH '@wall\.org$');

This search returns all person objects with a contact type matching C</email/>
and a contact value matching C</@wall\.org$/>, that is, everyone with an email
address in the "wall.org" domain.

Note that the same caveat as that for SQL C<MATCH> patterns applies here, too:
if your data store is an RDBMS, some databases don't have full-text indexes on
their columns. So even if there is an index on the "value" column of the
contact table in the database (not a sure thing by any stretch of the
imagination), it may not be used if your regular expression does not start
searching from the beginning of the value. So a regular expression such as
C</@wall\.org$/> may trigger a full table scan, which, if you have tens of
thousands of records or more, could be a very inefficient way to search,
indeed.

The C<MATCH> operator can also be used in combination with the C<NOT> operator,
so that you can search for objects with attributes that I<fail> to match a
regular expression. For example, we slightly change the last example to find
all persons with email addresses outside of the "wall.org" domain like this:

  my $iter = $store->query(
     'Object::Relation::Phony::Person' =>
     'contact.type'  => MATCH 'email',
     'contact.value' => NOT MATCH '@wall\.org$'
  );

=item GT

The C<GT> operator can be used to find objects with an attribute set to a
value greater than the specified value. For example, to find all phony person
objects with a favorite number greater than 42, use this syntax:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'fav_number' => GT 42);

The C<GT> operator also operates on date and string data. To find all phony
person objects with birthdays since exactly a year ago, try this approach:

  my $date = DateTime->now->subtract( years => 1 );
  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'birthday' => GT $date);

And to find all phony person objects with a last name greater than "za" (for
however your data store interprets that expression), this should do the trick:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'last_name' => GT 'za');

You could also use C<GT> in combination with C<NOT>, but why, when you can
use...

=item LT

This operator specifies a search for a value less than the value specified in
the search parameters. So to find all phony person objects with a favorite
number less than 42, do this:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'fav_number' => LT 42);

Like C<GT>, C<LT> works on dates and strings, too. To find all the phony
person objects with birthdays preceding a year ago, try this:

  my $date = DateTime->now->subtract( years => 1 );
  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'birthday' => LT $date);

And to find all phony person objects with a last name less than "bz" (for
however your data store interprets that expression), this should do the trick:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'last_name' => LT 'bz');

=item GE

The C<GE> operator is the inclusive form of C<GT>. That means that it returns
the objects for which the attribute value searched is greater than or equal to
the search criterion value. You probably get the idea now, but let's show off
the fact that we can combine different types of operators in a single search:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'fav_number'    => GE 42,
                            'contact.type'  => LIKE 'email',
                            'contact.value' => LIKE '@wall\.org$');

Look familiar? Now we're searching for all phony person objects with an email
type contact with a value matching the regular expression C</@wall\.org$/> and
whose favorite number is greater than or equal to 42. Fun, huh?

=item LE

The C<LE> operator is the inclusive form of C<LT>. That means that it returns
the objects for which the attribute value searched is less than or equal to the
search criterion value. Enough examples for now, eh?

=back

As you can see, there's a lot of expressive value in combining operators and
various attributes and contained object attributes. But sometimes they're not
enough. What if you want to C<OR> search parameters together? Or combine some
C<AND>ed parameters with C<OR>ed parameters? The next topic will help you there.

=head2 Compound Searches

Sometimes you need to do more complex searches. For example, you might want to
find all the persons with the last name of "Wall" or the last name of
"Conway". But because search parameters are always explicitly C<AND>ed together,
you'd have to do something like this:

  my $walls = $store->query('Object::Relation::Phony::Person' =>
                             'last_name' => 'Wall');

  my $conways = $store->query('Object::Relation::Phony::Person' =>
                               'last_name' => 'Conway');

But two searches will nearly always be less efficient than one. So to address
this conundrum, we introduce three new functions, C<AND>, C<OR>, and C<ANY> --
so named to be syntactically familiar to Perl users.

=head3 AND

As we've mentioned, search parameters are implicitly C<AND>ed when you perform
a search. It is possible to also explicitly C<AND> them together using the
C<AND> function. For example, this familiar search:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name  => 'Conway',
                            first_name => 'Damian');

Could also be written like so:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name       => 'Conway',
                            AND ( first_name => 'Damian' ));

This makes it explicit that we're search for phony person objects with the
C<last_name> attribute set to "Conway" and the C<first_name> attribute set to
"Damian".

But since the implicit C<AND>ing is so convenient, you might at first wonder
why we include an C<AND> function at all. Indeed, the implicit C<AND>ing is
easier to use (and arguably more legible). In general, we wouldn't expect
C<AND> to be used at all. But the real reason for the C<AND> function -- and
the secret to its power -- is for use in combination with the C<OR> function.

=head3 OR

The C<OR> function is for use in C<OR>ing together search parameters for more
flexible and efficient searches. To take our earlier example, if you wanted to
find all phony person objects with the C<last_name> attribute set to "Wall" or
to "Conway", you can use the C<OR> function to do so in a single search:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name      => 'Wall',
                            OR ( last_name => 'Conway' ));

Of course you can use more than one C<OR>, too. Say that you needed to find
all phony person objects with the last name of "Wall" or the last name of
"Conway" or the first name of "Bartholomew". Just add another C<OR>:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name       => 'Wall',
                            OR ( last_name  => 'Conway' ),
                            OR ( first_name => 'Bartholomew' ));

Multiple search parameters in a single call to C<OR> will of course be
C<AND>ed together, just like any other list of search parameters. For example,
to find all of the phony person objects with their C<last_name> attribute set
to "Wall", I<or> their C<last_name> attributes set to "Conway" and their
C<first_name> attributes set to "Damian", initiate the search like so:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name       => 'Wall',
                            OR ( last_name  => 'Conway',
                                 first_name => 'Damian' ));

This is convenient, but the real power of compound searches comes into play
when C<OR> is used in combination with C<AND>. Say you need to find all of
the phony user objects with the last name "Wall" and either an email address
in the "wall.org" domain, or an email address in the "cpan.org" domain. By
combining C<OR> with C<AND> it's a piece of cake:

  my $iter = $store->query(
    'Object::Relation::Phony::Person' =>
    last_name                  => 'Wall',
    AND ( 'contact.value'      => LIKE '@wall\.org$',
          OR ( 'contact.value' => LIKE '@cpan\.org$' )
        )
  );

And of course, these compound searches can be as arbitrarily complex as
necessary to get you what you need. Just know that the more contained or
related objects you search against (those with the dot notation for the search
parameter) will add complexity to the search and slow it down. But sometimes
that's just what you need.

  my $iter = $store->query(
    'Object::Relation::Phony::Person' =>
    last_name                  => 'Wall',
    first_name                 => 'Larry',
    OR ( bio                   => LIKE ' perl ' ),
    OR ( 'contact.type'        => LIKE 'email',
         AND ( 'contact.value' => LIKE '@cpan\.org$' ),
         AND ( 'fav_number     => GE 42 )
       )
  );

Let's read this search out. We want to find all of the phony person objects
with the last name "Wall" and the first name "Larry", I<or> with a mention of
the word "perl" in the bio, I<or> with an email contact type with a value
ending in "cpan.org" and a favorite number greater than or equal to 42. Whew!

As you can see, you can use any combination of parameters and value operators
that make sense for your particular search. There's a lot of power in that,
so be careful with the power tools!

=head3 ANY

Now you may have noticed some redundancy in some of the above examples. For
example, the first example for the C<OR> operator was:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name      => 'Wall',
                            OR ( last_name => 'Conway' ));

But this can get redundant really fast. What if you have a list of 5 last
names that you need to match against, any one of which is a legitimate search
result?

  my $iter = $store->query(
      'Object::Relation::Phony::Person' =>
      last_name      => 'Wall',
      OR ( last_name => 'Conway' )
      OR ( last_name => 'Randall' )
      OR ( last_name => 'Cawley' )
      OR ( last_name => 'Sugalski' )
  );

The syntax can get old really fast. There are two solutions to this problem:
The best is to use the dot notation to relate to another object or set of
objects and force the storage back end to do the hard work of sorting out
what's what (in other words, get an RDBMS back-end to do a join). But that's
not always feasible. Sometimes you just have a simple list of values to search
for, and that's all there is to it. For those circumstances, we offer the
C<ANY> operator:

  my $iter = $store->query(
    'Object::Relation::Phony::Person' =>
    last_name => ANY(qw(Wall Conway Randall Cawley Sugalski))
  );

Now isn't that a lot more elegant? Now you can search for any number of
values, an one of which may be correct. In general, the actual search will be
carried out exactly the same as if you'd use multiple C<OR> operators. And the
great thing about it is that, like the C<AND> and C<OR> operators, you can use
C<ANY> with any of the comparison operators. C<LIKE> can be especially useful:

  my $iter = $store->query(
    'Object::Relation::Phony::Person' =>
    last_name => LIKE ANY(qw(wall.* con[wv]ay rand(all|one) cawle[yi]
                          sugalsk[yi]))
  );

Now what could be more flexible than that?

=head3 BETWEEN

The C<BETWEEN> function is a range search.  Generally, this keyword is optional.
Any place where a range search between two values can be used, the C<BETWEEN>
keyword may be used to make the search more explicit.

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'birthday' => [$date2 => $date1]);

  # same as

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            'birthday' => BETWEEN [$date2 => $date1]);

=head3 Compound Function Greediness

You'll notice that each of the above examples using a compound function framed
its arguments in parentheses. This was mainly for the sake of clarity, but,
with a caveat, it's not entirely necessary. Provided you want all of the
arguments to the end of the search parameter to be included in a search, the
parentheses can be left out. For example, this search is identical to the very
first C<OR> example:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name      => 'Wall',
                            OR last_name => 'Conway');

Because we want all of the parameters that follow the C<OR> to be included in
the C<OR> function call, we can leave the parentheses out. However, we
recommend that in all but the simplest queries, you use the parentheses
anyway, if only to prevent unexpected problems. For example, this search may
not do what you at first expect:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name       => 'Wall',
                            OR  last_name   => 'Conway',
                            AND first_name  => 'Larry');

Did you mean to search for all instances with either last name "Wall" or the
last name "Conway", but always with the first name "Larry"? Or does it search
for all instances with the last name "Wall", I<or> the last name "Conway" and
the first name "Larry"? The second interpretation is the correct one, because
the C<OR> will suck up all of the arguments all the way to the end of the
search parameters, included the C<AND>ed parameters. So unless you meant:

  my $iter = $store->query(
      'Object::Relation::Phony::Person' =>
      last_name            => 'Wall',
      OR (
          last_name       => 'Conway',
          AND first_name  => 'Larry'
      )
  );

You're better off using explicit parentheses:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name         => 'Wall',
                            OR  ( last_name   => 'Conway' ),
                            AND ( first_name  => 'Larry'  );

Note that this caveat especially applies to the C<query> method (as opposed to
the C<query_uuids()> and C<count()> methods) when used with its optional
final hash reference argument. This search, for example, will likely trigger
an exception:

  my $iter = $store->query('Object::Relation::Phony::Person' =>
                            last_name       => 'Wall',
                            OR  last_name   => 'Conway',
                            { order_by      => 'first_name' });

Because the hash reference cannot be part of an C<OR> search expression.

=head1 How to Implement Store Subclasses

Say you were creating a subclass of Object::Relation::Handle for a new storage back-end.
If it were to be called, for example, "Oracle," and it was a database
back-end, here's what you'd need to do:

=over

=item * Create subclass of Object::Relation::Schema::DB

The job of this class is to create the code to generate the data store
infrastructure on the data store server. For a database, this generally means
generating a DDL (SQL, stored procedures, functions, and the like). See
L<Object::Relation::Schema::DB::Pg|Object::Relation::Schema::DB::Pg> and
L<Object::Relation::Schema::DB::SQLite|Object::Relation::Schema::DB::SQLite>
for examples.

=item * Test it in test script

See F<t/sqlite/schema.t> and F</pg/schema.t> for examples.

=item * Create a subclass of Object::Relation::Setup::Store::DB

The job of this class is to determine, at installation time, the necessary
information to build the back end, for example the server name, password,
database name, etc. It then takes this information and actually I<builds> the
data store. It also builds a test data store (the build system will ask the
Object::Relation::Setup::Store subclass to do this, if necessary). See
L<Object::Relation::Setup::Store::DB::Pg|Object::Relation::Setup::Store::DB::Pg>
and
L<Object::Relation::Setup::Store::DB::SQLite|Object::Relation::Setup::Store::DB::SQLite>
for examples. Note that this class should use FSA::Rules to gather
information, and respect the C<--accept_defaults> and C<--quiet> C<./Build>
options.

=item * Add the Object::Relation::Setup::Store subclass to the C<%STORES> hash in Object::Relation.

This is so that the build system knows that your new store back-end exists and
may need to be built. The key in this hash is used to identify the data store
via the C<--store> C<./Build> option.

=item * Test it in a build test class

See F<t/build/TEST/Object/Relation/Build/Store/Handle/DB/SQLite.pm> and
F<t/build/TEST/Object/Relation/Build/Store/Handle/DB/Pg.pm> for examples.

=item * Create scripts to setup and teardown a test data store.

The scripts should live in F<t/store> and be named with the key used in the
C<%STORES> hash in Object::Relation and should build a data store with the
test classes defined in F<t/sample/lib>. There can be two scripts, one to
setup the data store, and one to tear it down. For our Oracle example, the
scripts would be named F<t/store/oracle_setup.pl> and
F<t/store/oracle_teardown.pl>. These are different than the behavior of the
test database created for testing Object::Relation applications. It is designed
specifically to fully test the complete store API, as the sample classes
exhibit every relationship and data type.

=item * Create a subclass of Object::Relation::Handle::DB.

It should be named Object::Relation::Handle::DB::Oracle. See
L<Object::Relation::Handle::DB::Pg|Object::Relation::Handle::DB::Pg> and
L<Object::Relation::Handle::DB::SQLite|Object::Relation::Handle::DB::SQLite> for examples. Be sure
to override the C<_add_store_meta()> method if you need to add data-store
specific trusted attributes to Object::Relation base class. For example,
Object::Relation::Handle::DB uses this method to add a trusted C<id> attribute that can
only be accessed by the store classes, but allows them to treat database IDs
just like any other attribute.

=item * Add Any needed code to Object::Relation::Meta

Some data stores need to add extra code to Object::Relation::Meta classes in order to
keep their code clean and well-factored. For example, the database stores have
a special Object::Relation::Meta label, ":with_dbstore_api". So when you load
Object::Relation::Meta like this:

  use Object::Relation::Meta ':with_dbstore_api';

the import methods of the various Object::Relation::Meta classes (Attribute, Class,
Type) add Object::Relation::Meta methods specific to database stores.

Now, an Oracle data store probably wouldn't need to add any metadata methods
not already added by the Object::Relation::Handle::DB class, but if it did, you could
modify the import() methods of these classes to add the necessary methods. For
example, say you needed to add a foo() method to Object::Relation::Meta::Attribute just
for use with Oracle, you could add something like this to the import() method
of Object::Relation::Meta::Attribute:

    if ($api_label eq ':with_oracle_api') {
        return if defined(&foo);
        no strict 'refs';
        *{__PACKAGE__ . '::foo'} = sub { ... };
    }

See the existing code in the import() methods of
L<Object::Relation::Meta::Attribute|Object::Relation::Meta::Attribute> and
L<Object::Relation::Meta::Type|Object::Relation::Meta::Type> for examples. Be sure to write
tests for any methods you add! See F<t/dbmeta.t> for an example.

=item * Create the test classes for the data store.

These should live in the F<t/store> directory, and be subclasses of
TEST::Object::Relation::Handle::DB. See
F<t/store/TEST/Object/Relation/Store/Handle/DB/SQLite.pm> and
F<t/store/TEST/Object/Relation/Store/Handle/DB/Pg.pm> for examples.

=back

=cut

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@obj_relode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
