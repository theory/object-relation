package Kinetic::Store;

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
use base qw(Kinetic);
use Scalar::Util qw(blessed);

=head1 Name

Kinetic::Store - The Kinetic data storage class

=head1 Synopsis

  use Kinetic::Store;
  use Kinetic::Biz::Subclass;
  my $coll = Kinetic::Store->search('Kinetic::Biz::SubClass' =>
                                      attr => 'value');

=head1 Description

This class handles all of the work necessary to communicate with back-end
storage systems. Kinetic::Store itself is an abstract class; its subclasses
will implement its interface for different storage devices: RDBMSs, OODBMSs,
XML Files, LDAP, or whatever. The canonical storage implementation is
L<Kinetic::Store::DB::Pg|Kinetic::Store::DB::Pg>, for PostgreSQL 7.4 or
later. Others might include
L<Kinetic::Store::DB::SQLite|Kinetic::Store::DB::SQLite> for SQLite,
L<Kinetic::Store::DB::mysql|Kinetic::Store::DB::mysql> for MySQL 4.1 or
later, and L<Kinetic::Store::LDAP|Kinetic::Store::LDAP>.

=cut

# Here are the functions we'll need to export to get the search parameter
# syntax to work.

BEGIN {
    foreach my $sub (qw(AND OR ANY)) {
        no strict 'refs';
        *{$sub} = sub { bless [$sub, \@_] => 'Kinetic::Store::Search' };
    }

    foreach my $sub (qw(NOT LIKE GT LT GE LE)) {
        no strict 'refs';
        *{$sub} = sub ($) { bless [$sub, \@_] => 'Kinetic::Store::Search' };
    }
}

# These are simple constants we can use for the sort_order parameter. These
# are used for the DBI storage classes only.
use constant ASC  => 'ASC';
use constant DESC => 'DESC';

##############################################################################
# Class Methods
##############################################################################

=head2 Class Methods

=head3 lookup

  my $bric_obj = Kinetic::Store->lookup($class, guid => $guid);
  $bric_obj = Kinetic::Store->lookup($class, unique_attr => $value);

Method to look up objects in the Kinetic data store by a unique identifier.
Most often the identifier used will be  globally unique object identifier.
However, for Kinetic classes that allow unique identifiers other than GUIDs
-- that is, system-wide (rather than globally) unique identifiers -- then an
appropriate key/value pair may be used for the lookup. No SQL wildcards or
regular expressions will be allowed. The lookup value must be a complete
value.

Most often this method will not be used directly, but rather by calling the
C<lookup()> method on Kinetic classes.

B<Throws:>

=over

=item Exception::DA

=back

=cut

##############################################################################

=head3 search

  my $coll = Kinetic::Store->search( $class => @search_params );
  $coll = Kinetic::Store->search( $class => @search_params,
                                    \%constraints );

Use this method to search the Kinetic data store for all of the objects of a
particular Kinetic class that meet a specified set of search parameters. The
C<$class> argument is required, while the search parameters are optional but
highly recommended (otherwise it will "find" I<all> of the objects in the
class). See L<Search Parameters Explained|"SEARCH PARAMETERS EXPLAINED"> for
details on specifying search parameters. Returns a Kinetic::Util::Collection
object that may be used to fetch each of the objects found by the search. If
no objects are found, C<search()> returns an empty collection. See
L<Kinetic::Util::Collection|Kinetic::Util::Collection> for details on its
interface. See the documentation for the C<search()> method in a particular
class for a list of object attributes to search by in that class.

An optional hash reference of search modifiers may be passed in as the final
argument to C<search()>. The available search modifiers are:

=over 4

=item order_by

  my $coll = Kinetic::Store->search( $class, @search_params,
                                       { order_by => $attr } );

The name of an object attribute or an array reference of object attributes to
sort by. All sorting is done in a case-insensitive fashion. The actual sort
order is dependent on the ordering rules of your data store. I<Do not> pass
"guid" as a sort parameter, as it will always be used for sorting, anyway. If
this modifier isn't passed in, the class will select a default or set of
default attributes to sort by.

=item sort_order


  my $coll = Kinetic::Store->search( $class, @search_params,
                                       { order_by   => $attr,
                                         sort_order => ASC } );


The direction in which to sort the the C<order_by>> attributes. The possible
values are C<ASC> and C<DESC>. If C<order_by> is a single attribute, then
C<sort_order> should be a single value, or will default to C<ASC>. If
C<order_by> is an array of attributes, then C<sort_order> may also be an array
of directions; any directions missing for a corresponding C<order_by>
attribute will default to C<ASC>. By default, all searches will be C<ASC>.

=item limit

  my $coll = Kinetic::Store->search( $class, @search_params,
                                       { limit => 50 } );

Limits the number of objects returned to a given number. This is useful for
search interfaces that need to paginate search results without loading
thousands or even millions of objects just to load 50 of them. Best used in
combination with C<offset>.

=item offset

  my $coll = Kinetic::Store->search( $class, @search_params,
                                       { limit  => 50 } );
                                         offset => 200 );

Returns a collection of Kinetic objects starting with the number C<offset>
in the search results. In the above example, the call to C<search()> would
return only 50 objects, starting with the 200th object found in the
search. This is implemented in such a way that the data store does all the
work and returns only the results desired. It is therefore a very efficient
way to fetch results for pagination.

=back

B<Throws:>

=over

=item Exception::DA

=back

=cut

##############################################################################

=head3 search_guids

  my @guids = Kinetic::Store->search_guids( $class => @search_params );
  my $guids_aref = Kinetic::Store->search_guids( $class => @search_params );

Returns a list or array reference of GUIDs for the the class C<$class> based
on the search parameters. See L<Search Parameters Explained|"SEARCH PARAMETERS
EXPLAINED"> for details on specifying search parameters. Returns an empty list
in an array context and an empty array reference in a scalar context when no
results are found.

B<Throws:>

=over 4

=item Exception::DA

=back

=cut

##############################################################################

=head3 count

  my $count = Kinetic::Store->count( $class => @search_params );

Returns a count of the number of objects that would be found by C<search()>
(or the number of GUIDs that would be returned by C<search_guids()>) for the
class C<$class> based on the search parameters. See L<Search Parameters
Explained|"SEARCH PARAMETERS EXPLAINED"> for details on specifying search
parameters. Returns "0" when no results would be found in the search.

The C<count()> method will most often be called to determine how many pages to
provide links for when paginating search results in the UI. Therefore, for
purposes of efficiency, the result of a call to C<count()> will be cached, so
that subsequent calls to C<count()> with the same parameters will not incur
the database overhead. The timeout for the C<count()> cache will be setable
via a Kinetic::Util::Config setting.

B<Throws:>

=over 4

=item Exception::DA

=back

=cut

##############################################################################

=head3 save

  $bric_obj = Kinetic::Store->save($bric_obj);

Saves any changes to the Kinetic object to the data store. Returns the
Kinetic object on success and throws an exception on failure. No part of the
Kinetic object or its parts will ever be saved unless and until the
C<save()> method is called. The only exception is when the Kinetic object is
contained in another object (such as via a has-a relationship), when that
other will be saved, as well. That is to say, C<save()> saves the Kinetic
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
single call to C<save()>, mirroring the encapsulation of Kinetic objects.

B<Throws:>

=over 4

=item Error::Undef

=item Error::Invalid

=item Exception::DA

=back

=cut

sub save {
    my ($class, $object) = @_;
    return $class unless $object->changed;
    return defined $object->guid
        ? $class->_update($object)
        : $class->_insert($object);
}

sub _insert {
    my ($class, $object) = @_;
    my $my_class     = $object->my_class;
    my $table        = $my_class->table;
    my @attributes   = $my_class->attributes;
    my $attributes   = join ', ' => map { $_->column } @attributes;
    my $placeholders = join ', ' => (('?') x @attributes);
    my @values       = map { my $attr = $_->name; $object->$attr } @attributes;
    my $sql = "INSERT INTO $table ($attributes) VALUES ($placeholders)";
    $class->_do_sql($sql, \@values);
    $object->{_id}   = $class->_dbh->last_insert_id;
    return $class;
}

sub _update {
    my ($class, $object) = @_;
    my $my_class      = $object->my_class;
    my $table         = $my_class->table;
    my @attributes    = $my_class->attributes;
    my $column_values =
        join ', ' =>
        map { $_->column .' = ?' }
            @attributes;;
    my @values = map { my $attr = $_->name; $object->$attr } @attributes;
    push @values => $object->guid;
    my $sql = "UPDATE $table SET $column_values WHERE guid = ?";
    $class->_do_sql($sql, \@values);
    return $class;
}

sub _do_sql {
    my ($class, $sql, $bind_params) = @_;
    $class->_dbh->do($sql, undef, @$bind_params); 
    return $class;
}

##############################################################################

=head1 Search Parameters Explained

The specification for search parameters to be passed to the C<search()>,
C<search_guids()>, and C<count()> methods has been designed to maximize
flexibility and ease of use by making it as Perlish as possible. This means
that you can search on multiple object attributes of different types,
attributes on contained or related objects, and values that are equivalent to
or similar to a search string or matching a regular expression. You can search
for values between two values, and for values that are C<NULL> (or undefined).

This section details the search parameters semantics in detail.

=head2 Example Classes

Since there is potentially a lot to specifying search parameters depending on
the complexity of the search you want to do, we'll include a lot of examples
here. The examples will make use of a couple of phony Kinetic
classes. Kinetic::Phony::Person has the following attributes:

=over 4

=item guid

=item last_name

=item first_name

=item birthday

=item fav_number

=item bio

=back

It also may be associated with zero or more phony Kinetic::Phony::Contact
objects, which have the following attributes:

=over 4

=item guid

=item type

=item label

=item contact

=back

=head2 Search Basics

=head3 Full Text Search

At its simplest, a search  can be a simple keyword search:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'Perl inventor');

Pasing a single string as the search parameter triggers a full text search of
all the objects of the class and returns all of the active objects that match
the search. The full text substring search works because an XML representation
of each Kinetic biziness objects is always kept in the data store. The
semantics of the search results will, however, be dependent on the full text
indexing of the data store in question. See the relevant Kinetic::Store
subclasses for details on their full text search implementations.

Note that if you need to search for objects with inactive or deleted states,
you'll need to do an attribute search, instead.

=head3 Attribute Search

The most common use of the search interface is to specify certain object
attributes to search against.

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name  => 'Wall',
                                      first_name => 'larry');

In this example, we're searching for all the phony person objects with the
last name 'Wall' and the first name 'larry'. Note that even though the case is
different in the two arguments, both will return the same results. This is
because searches against strings are always case-insensitive in
Kinetic.

With attribute searches, all the attributes searched against are C<AND>ed
together -- that is, the objects returned must match I<all> of the search
parameters (But see L<Compound Searches|"Compound Searches"> for an
alternative approach).

By default, searches will never return Kinetic objects with their state
attribute set to DELETE. If you wish to search for deleted objects, explicitly
specify the C<state> attribute in your search parameters.

=head3 Contained Object Searching

Searches can also be made for objects based on contained or related objects,
or based on the attributes of contained or related objects by using a simple
dot notation. All Kinetic classes have a unique key returned by their
C<my_key()> methods. This unique key can be used to identify which types of
contained or related objects to search against by specifying search parameters
using this key.

In our example classes, phony person objects can contain any number of phony
contact objects. If the value returned by
C<< Kinetic::Phony::Contact->my_key >> is "contact", then this search:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      contact => $contact);

Would return the phony person object or objects with which the contact was
associated. This approach will work whether zero, one, or many objects are
associated with or contained in a person object.

In addition, searches can be made based on the I<attributes> of contained or
related objects by specifying the contained class key name plus the attribute
of that class to search, separated by a dot. For example, this search:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'contact.type' => 'email');

Will return all phony person objects containing a contact with its type
attribute set to 'email'. This approach can be used for any combination of
attributes on the object or contained objects. For example, this search:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
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
its C<guid> attribute. The equivalent would be:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'contact.guid' => $contact->get_guid);

=head3 Attribute Types

Kinetic supports three basic types of attributes: strings (such as the
C<last_name> and C<bio> attributes of Kinetic::Phony::Person), numbers,
(such as the C<fav_number> attribute of Kinetic::Phony::Person). and dates
and times (such as the C<birthday> attribute of Kinetic::Phony::Person).
Each type of attribute requires that the appropriate type of data be passed as
the search value. Thus, string attributes require string search values,
numeric attributes require numeric values, and date and times require
DateTime objects to be passed as their values.

=over 4

=item Strings

We've already had a quick look at searching on strings, but let's do it
again, just for fun:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name => 'Conway',
                                      fist_name => 'Damian');

This search will return a collection of all phony person objects with the
first name attribute 'Damian' and the last name attribute 'Conway'. String
searches are always case-insensitive, so searches will also succeed with the
last names "conway", "CONWAY", and "cOnWAy".

But wait, there's more. If you're data store is an ANSI-92 compliant RDBMS, all
string searches will be carried out using the SQL C<LIKE> operator. This means
that you can use C<LIKE> patterns. Consult your RDBMS' documentation for
details on its supported C<LIKE> pattern syntax. Here's a typical example:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name => 'c%');

This search returns all of the phony person objects with their C<last_name>
attributes starting with the letter "c". This search, on the other hand:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      bio => '%photographer%');

Will find all of the phony person objects with the string "photographer"
anywhere in their C<bio> attributes. Be careful of expressions such as this,
though; some databases don't have full-text indexes on their columns, so even
if there is an index on the "bio" column in the database, it may not be used
if your search does not start searching from the beginning of the value. So a
C<LIKE> pattern such as '%photographer%' may trigger a full table scan, which,
if you have tens of thousands of records or more, could be a very inefficient
way to search, indeed. Search patterns that explicitly start at the beginning
of the value, such as 'c%', will use an available index.

=item Numbers

So let's look at numbers:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      fav_number  => 42);

This search returns all phony person objects with the C<fav_number> attribute
set to the number 42. Pretty simple, eh? You can of course also combine
numeric attribute search parameters with other types of search parameters:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
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

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      birthday => $date);

This search will return all phony person objects with a birth date of December
19, 1968. Note that even if C<birthday> is technically a datetime field rather
than simple a date field, it will return all persons with a their C<birthday>
attributes set to sometime on that date, regardless of the time.

The reason DateTime objects are required rather than date strings is that all
times are stored in the data store in UTC. By specifying a DateTime object,
Kinetic can convert from whatever time zone is specified in the DateTime
object to UTC before performing the query.

For datetime fields, you can of course specify more exact times:

  my $date = DateTime->new( year   => 1968,
                            month  => 12,
                            day    => 19,
                            hour   => 19,
                            minute => 42,
                            second => 18 );

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      birthday => $date);

This search of course returns all the phony person objects with a birth date
and time of 19 December 1968, at 19:42:18. Any other phony person objects with
their C<birthday> attribute set to any other time on the same date will of
course be excluded from the search results.

Queries on partial dates can be carried ouit using DateTime::Incomplete. For
example, if you wanted to search for all persons with a date of 19 December
without regard to year, you can do it like this:

  my $date = DateTime::Incomplete->new( month => 12,
                                        day   => 19 );

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
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

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      birthday => undef);

This search will return all phony person objects for which the C<birthday>
attribute has no value -- that is, it is "undefined" or "null". And of course,
this value can be used in combination with other search parameters:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'last_name'     => 'wall',
                                      'contact.value' => undef);

This search returns all phony person objects with the C<last_name> attribute
set to 'wall' and at least one contact object with an undefined value.

=head3 Overloaded Object Values

Any Kinetic objects overloaded to output a value in a double-quoted string
context will automatically have their strings used for the value if you pass
in the overloaded object as the search parameter value. For example:

  my $string_obj = Kinetic::Biz::Value::String->new("Salzenberg");
  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name => $string_obj);

This search will find all of the phony person objects with their C<last_name>
attributes set to "Salzenberg". The same deal works for numbers, too:

  my $numb_obj = Kinetic::Biz::Value::Number->new(42);
  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      fav_number => $numb_obj);

It's effectively the same for dates, as well, only a DateTime-inherited object
I<must> be the argument for a date search parameter, as already discussed.

Note that the only situation where a stringifiable object will not be
stringified are searches against contained or related objects. For example,
even if our phony contact objects stringify to their value attributes, an
argument to a C<contact> search parameter will always search by the contact
object ID:

  # Search by contact object GUID.
  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'contact' => $contact);

To search against the value, you would need to specify the C<value> search
parameter explicitly:

  # Search by contact object value.
  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'contact.value' => $contact);

But then, in case such as this, it may be best to just to be explicit:

  # Search by contact object value.
  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'contact.value' => $contact->get_value);

=head3 Value Ranges

To search for objects with an attribute that falls within a range of values,
simply pass an array reference of the two values to search between, and the
objects returned will have the attribute in question set to a value between
those two values, inclusive. For example, to find all of the phony person
objects with favorite numbers between 1 and 100, do this:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'fav_number' => [1 => 100]);

Yes, that's it. Any values in the array beyond the second will be ignored.
It works on dates and strings, too:

  my $date1 = DateTime->now;
  my $date2 = $date1->clone->subtract( years => 1 );
  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'birthday' => [$date2 => $date1]);

This search returns all phony person objects with their C<birthday> attributes
set for sometime in the last year.

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'last_name' => ['l' => 'm']);

And this search returns all phony person objects with their C<last_name>
attributes set between 'l' and 'm' -- which essentially works out to any last
names starting with the letter 'l'. The comparisons are of course made
case-insensitively, so "Lawrence" would be included as well as "l'Oriale".

=head3 Value Operators

Well that was easy, wasn't it? But wait, there's more! But you knew that from
having read the questions at the beginning of this section, didn't you? Well,
here are the details. Kinetic provides a number of unary operators to affect
how search parameters values are treated. These are designed to give you
greater flexibility in building your search parameters to get the objects you
need. Most have the same names as standard Perl operators, the only difference
beeing an initial uppercase letter. This design, we hope, makes the Kinetic
search value operators both familiar and easy to remember.

And so, without further ado, here they are:

=over

=item NOT

The C<NOT> operator indicates a search for objects where an attribute does
I<not> have a value matching our parameters. For example, say you want to find
all the phony person objects whose last name is I<not> "Wall". Here's how you
do it:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'last_name' => NOT 'wall');

Simple, eh? It can be used with value ranges, as well. To find all of the
persons whose birthday did I<not> occur in the last year, try this:

  my $date1 = DateTime->now;
  my $date2 = $date1->clone->subtract( years => 1 );
  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'birthday' => NOT [$date2 => $date1]);

And naturally it works with numbers, too:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'fav_number' => NOT 42); # Sillies.

=item LIKE

The C<LIKE> operator (not to be confused with SQL C<LIKE> patterns) will be
familiar to anyone who has used the famous Test::More module. It indicates
that the search value is a regular expression. That's right, as long as the
type of attribute you're searching is a string data type (or your data store
can use regular expressions on numeric and date data), you can specify a
regular expression to match against it (provided, of course, that the data
store supports regular expressions at all). All regular expression matching is
implicitly case-insensitive. Otherwise, consult the documentation for your
data storage engine for its supported regular expression syntax.

Here are a couple of simple examples to get you started.

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'last_name' => LIKE '^wa');

This search returns all phony person objects with their C<last_name> attribute
matching the regular expression C</^wa/>, that is, that start with the string
"wa".

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'contact.type'  => LIKE 'email',
                                      'contact.value' => LIKE '@wall\.org$');

This search returns all person objects with a contact type matching C</email/>
and a contact value matching C</@wall\.org$/>, that is, everyone with an email
address in the "wall.org" domain.

Note that the same caveat as that for SQL C<LIKE> patterns applies here, too:
if your data store is an RDBMS, some databases don't have full-text indexes on
their columns. So even if there is an index on the "value" column of the
contact table in the database (not a sure thing by any stretch of the
imagination), it may not be used if your regular expression does not start
searching from the beginning of the value. So a regular expression such as
C</@wall\.org$/> may trigger a full table scan, which, if you have tens of
thousands of records or more, could be a very inefficient way to search,
indeed.

The C<LIKE> operator can also be used in combination with the C<NOT> operator,
so that you can search for objects with attributes that I<fail> to match a
regular expression. For example, we slightly change the last example to find
all persons with email addresses outside of the "wall.org" domain like this:

  my $coll = Kinetic::Store->search
    ('Kinetic::Phony::Person' =>
     'contact.type'  => LIKE 'email',
     'contact.value' => NOT LIKE '@wall\.org$');

=item GT

The C<GT> operator can be used to find objects with an attribute set to a
value greater than the specified value. For example, to find all phony person
objects with a favorite number greater than 42, use this syntax:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'fav_number' => GT 42);

The C<GT> operator also operates on date and string data. To find all phony
person objects with birthdays since exactly a year ago, try this approach:

  my $date = DateTime->now->subtract( years => 1 );
  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'birthday' => GT $date);

And to find all phony person objects with a last name greater than "za" (for
however your data store interprets that expression), this should do the trick:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'last_name' => GT 'za');

You could also use C<GT> in combination with C<NOT>, but why, when you can
use...

=item LT

This operator specifies a search for a value less than the value specified in
the search parameters. So to find all pyony person objects with a favorite
number less than 42, do this:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'fav_number' => LT 42);

Like C<GT>, C<LT> works on dates and strings, too. To find all the phony
person objects with birthdays preceding a year ago, try this:

  my $date = DateTime->now->subtract( years => 1 );
  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'birthday' => LT $date);

And to find all phony person objects with a last name less than "bz" (for
however your data store interprets that expression), this should do the trick:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      'last_name' => LT 'bz');

=item GE

The C<GE> operator is the inclusive form of C<GT>. That means that it returns
the objects for which the attribute value searched is greater than or equal to
the search criterion value. You probably get the idea now, but let's show off
the fact that we can combine different types of operators in a single search:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
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

  my $walls = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                       'last_name' => 'Wall');

  my $conways = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                         'last_name' => 'Conway');

But two searches will nearly always be less efficient than one. So to address
this conundrum, we introduce three new functions, C<AND>, C<OR>, and C<ANY> --
so named to be syntactically familiar to Perl users.

=head3 AND

As we've mentioned, serach parameters are implicitly C<AND>ed when you perform
a search. It is possible to also explicitly C<AND> them together using the
C<AND> function. For example, this familiar search:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name  => 'Conway',
                                      first_name => 'Damian');

Could also be written like so:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
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

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name      => 'Wall',
                                      OR ( last_name => 'Conway' ));

Of course you can use more than one C<OR>, too. Say that you needed to find
all phony person objects with the last name of "Wall" or the last name of
"Conway" or the first name of "Bartholomew". Just add another C<OR>:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name       => 'Wall',
                                      OR ( last_name  => 'Conway' ),
                                      OR ( first_name => 'Bartholomew' ));

Multiple search parameters in a single call to C<OR> will of course be
C<AND>ed together, just like any other list of search parameters. For example,
to find all of the phony person objects with their C<last_name> attribute set
to "Wall", I<or> their C<last_name> attributes set to "Conway" and their
C<first_name> attributes set to "Damian", initiate the search like so:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name       => 'Wall',
                                      OR ( last_name  => 'Conway',
                                           first_name => 'Damian' ));

This is convenient, but the real power of compound searches comes into play
when C<OR> is used in combination with C<AND>. Say you need to find all of
the phony user objects with the last name "Wall" and either an email address
in the "wall.org" domain, or an email address in the "cpan.org" domain. By
combining C<OR> with C<AND> it's a piece of cake:

  my $coll = Kinetic::Store->search(
    'Kinetic::Phony::Person' =>
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

  my $coll = Kinetic::Store->search(
    'Kinetic::Phony::Person' =>
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

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name      => 'Wall',
                                      OR ( last_name => 'Conway' ));

But this can get redundant really fast. What if you have a list of 5 last
names that you need to match against, any one of which is a legitimate search
result?

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
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

  my $coll = Kinetic::Store->search(
    'Kinetic::Phony::Person' =>
    last_name => ANY(qw(Wall Conway Randall Cawley Sugalski))
  );

Now isn't that a lot more elegant? Now you can search for any numer of values,
an one of which may be correct. In general, the actual search will be carried
out exactly the same as if you'd use multiple C<OR> operators. And the great
thing about it is that, like the C<AND> and C<OR> operators, you can use
C<ANY> with any of the comparison operators. C<LIKE> can be especially useful:

  my $coll = Kinetic::Store->search(
    'Kinetic::Phony::Person' =>
    last_name => LIKE ANY(qw(wall.* con[wv]ay rand(all|one) cawle[yi]
                          sugalsk[yi]))
  );

Now what could be more flexible than that?

=cut

=head3 Compound Function Greediness

You'll notice that each of the above examples using a compound function framed
its arguments in parentheses. This was mainly for the sake of clarity, but,
with a caveat, it's not entirely necessary. Provided you want all of the
arguments to the end of the search parameter to be included in a search, the
parentheses can be left out. For example, this search is identical to the very
first C<OR> example:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name      => 'Wall',
                                      OR last_name => 'Conway');

Because we want all of the parameters that follow the C<OR> to be included in
the C<OR> function call, we can leave the parentheses out. However, we
recommend that in all but the simplest queries, you use the parentheses
anyway, if only to prevent unexpected problems. For example, this search may
not do what you at first expect:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name       => 'Wall',
                                      OR  last_name   => 'Conway',
                                      AND first_name  => 'Larry');

Did you mean to search for all instances with either last name "Wall" or the
last name "Conway", but always with the first name "Larry"? Or does it search
for all instances with the last name "Wall", I<or> the last name "Conway" and
the first name "Larry"? The second interpretation is the correct one, because
the C<OR> will suck up all of the arguments all the way to the end of the
search parameters, included the C<AND>ed parameters. So unless you meant:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name            => 'Wall',
                                      OR ( last_name       => 'Conway',
                                           AND first_name  => 'Larry'
                                         )
                                     );

You're better off using explicit parentheses:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name         => 'Wall',
                                      OR  ( last_name   => 'Conway' ),
                                      AND ( first_name  => 'Larry'  );

Note that this caveat especially applies to the C<search()> method (as opposed
to the C<search_guids()> and C<count()> methods) when used with its optional
final hash reference argument. This search, for example, will likely trigger an
exception:

  my $coll = Kinetic::Store->search('Kinetic::Phony::Person' =>
                                      last_name       => 'Wall',
                                      OR  last_name   => 'Conway',
                                      { order_by      => 'first_name' });

Because the hash reference cannot be part of an C<OR> search expression.

=cut


=begin private

=head2 Private Instance Methods

These methods are designed to be used by subclasses.

##############################################################################

=head3 _dbh

  my $dbh = Kinetic::Store->_dbh;
  Kinetic::Store->_dbh($some_dbh);;

This is merely a hack to get this going until the exact implementation is
nailed down.  As all database interaction should be encapsulated by this
class, no one should ever need to call this method (yeah, right).

=cut

my $DBH;
sub _dbh {
    my $proto = shift;
    return $DBH if $DBH;
    $DBH = shift if @_;
    return $proto;
}

##############################################################################

=head3 _search_params

  my ($target, $search, $options) = Kinetic::Store->_search_params(@_);

Given a set of arguments to the C<search()> or C<search_guids()>
methods, this method returns the target class to be searched, the
search parameters as a hash reference, and the options (like limit,
sort order, etc.) as a hash reference.

=cut

sub _search_params {
    my $self = shift;

    my $target = shift;
    my $options = pop @_ if ref $_[-1] && ! blessed $_[-1];

    my @search;
    while (@_) {
        my $param = shift @_;

        # We need to recursively examine the return value from
        # expanding a modifier like AND, because its expansion may
        # contain more modifiers.
        if (UNIVERSAL::isa('Kinetic::Store::Search', $_)) {
            my $name = shift;

            unshift @_, $self->$name($_);
        } else {
            push @search, $param;
        }
    }

    return ($target, \@search, $options);
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
