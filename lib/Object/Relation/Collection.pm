package Object::Relation::Collection;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.1.1');

#use Object::Relation::Meta; # Do not load here--causes loading order problems.
use Object::Relation::Exceptions qw(throw_fatal throw_invalid throw_invalid_class);
use aliased 'Object::Relation::Iterator';
use aliased 'Array::AsHash';

use Scalar::Util qw(blessed refaddr);

# to simplify the code, we use -1 instead of undef for "null" indexes
use constant NULL => -1;

sub _key($) {
    my $thing = shift;
    return eval { $thing->uuid } || refaddr $thing || $thing;
}

=head1 Name

Object::Relation::Collection - Object::Relation collection class

=head1 Synopsis

  use Object::Relation::Collection;

  my $coll = Object::Relation::Collection->new(
     {
         iter => $iterator,
         key  => $key        # optional
     }
  );
  while (my $thing = $coll->next) {
      # Do something with $thing.
  }

=head1 Description

This class provides an interface for accessing a collection of Object::Relation
objects. Users generally won't create collection objects directly, but will
get them back from accessor methods for collections of objects related to an
object.

Note that the collection is essentially an ordered set.  Duplicate items are
not allowed and order is important.

Also, a collection can be for objects other than Object::Relation objects, but the
objects must provide a C<uuid> method.

If the key is not supplied, the collection is untyped.  If the key is
supplied, the collection is I<typed>.  All objects in the collection must
either be Object::Relation classes or subclasses for the key C<$key>.  =cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $coll = Object::Relation::Collection->new({
      iter => $iterator,
      key  => $key,    # optional
  });

Constructs and returns a new collection object. Takes a hash reference argument
containing the following parameters:

=over

=item iter

A L<Object::Relation::Iterator|Object::Relation::Iterator> object. Required.

=item key

An optional key identifying a data type to force a typed collection.

=back

B<Throws:>

=over 4

=item Fatal::Invalid

=back

=cut

sub new {
    my ( $class, $arg_for ) = @_;
    $arg_for ||= {};
    my ( $iter, $key ) = @{$arg_for}{qw/iter key/};

    throw_invalid [
        'Argument "[_1]" is not a valid [_2] object',
        $iter || '',
        Iterator
    ] unless eval { $iter->isa(Iterator) };

    my $self = {
        iter        => $iter,
        index       => NULL,
        added_index => NULL,
        array       => AsHash->new,
        got         => NULL,
        key         => $key,
        package     => undef,
    };

    bless $self => $class->_set_package($self);
}

##############################################################################

=head3 empty

  my $collection = Object::Relation::Collection->empty;
  my $collection = Object::Relation::Collection->empty( $key );

Syntactic sugar for creating a new, empty collection. Takes an optional data
type key to force a typed collection.

=cut

sub empty {
    my $class = shift;
    my @key;
    @key = ( key => shift ) if @_;
    return $class->new({ iter => Iterator->new( sub { } ), @key });
}

##############################################################################

=head3 from_list

  my $coll = Object::Relation::Collection->from_list({
      list => \@list,
      key  => $key,    # optional
  });

Constructs a new collection object based on an array reference. If the key is
present, all objects in C<@list> must be objects whose classes correspond to
said key. Duplicate items in the list will be removed.

For convenience, this method may also be called from a collection instance
and, in which case it returns a new collection. The new collection will be of
the same type unless an explicit key is used.

  # will be the same type as $old_coll
  my $coll = $old_coll->from_list({ list => \@list });

  # will ignore the type of $old_coll
  my $coll = $old_coll->from_list({ list => \@list, key => 'customer' });

=cut

sub from_list {
    my ( $proto, $arg_for ) = @_;
    my $class = ref $proto || $proto;
    $arg_for ||= {};
    my ( $list, $key ) = @{$arg_for}{qw/list key/};
    _clear_dupes($list) if @$list;
    my @list = @$list;    # copy the array to avoid changing called array
    my $self = $class->new({
        iter => Iterator->new( sub { shift @list } ),
        (defined $key ? (key => $key) : ()),
    });
    $self->{assigned} = 1;
    return $self;
}

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 next

  while (my $thing = $coll->next) {
      print "It's a thing!\n";
  }

Returns the next item in the collection and sets the collection's current
position to that item. Calling C<next()> multiple times will return each item
in sequence. If you attempt to fetch an item beyond the end of the current
collection size, the collection returns false and the position of the
collection will not be changed. Call C<curr()> to get the value at the current
index position.

=cut

sub next {
    my $self = shift;
    if ( $self->{got} > ( $self->index || 0 ) ) {
        # We've been here before.
        $self->_inc_index;
        return $self->curr;
    }

    my $result = $self->_check( $self->iter->next );
    unless (defined $result) {
        $self->{filled} = 1;
        return;
    }
    $self->{got} = $self->_inc_index;
    $self->_array->push( _key $result, $result );
    return $result;
}

##############################################################################

=head3 package

  my $package = $collection->package;

If the collection is typed (see C<new()>), this method will return the package
that objects in the collection are allowed to be.

=cut

sub package { shift->{package} }

##############################################################################

=head3 curr

  my $current = $coll->curr;

Returns the value at the current position of the collection.

=cut

sub curr {
    my $self = shift;
    return if $self->index == NULL;
    return $self->_check( $self->_array->value_at( $self->index ) );
}

##############################################################################

=head3 current

 my $current = $coll->current;

Alias for C<curr>.

=cut

*current = \&curr;

##############################################################################

=head3 prev

  my $previous = $coll->prev;

Returns the value at the previous position of the collection. Also sets the
current collection value to that position. If we're already at the start of
the collection, this method returns C<undef> and does not change the position.

=cut

sub prev {
    my $self = shift;
    return unless $self->index > 0;
    $self->_dec_index;
    return $self->curr;
}

##############################################################################

=head3 iter

=head3 iterator

  my $iterator = $coll->iter;

This method returns the iterator the collection has.

=cut

sub iter { shift->{iter} }

##############################################################################

=head3 iterator

  my $iterator = $coll->iterator;

Alias for C<iter()>.

=cut

*iterator = \&iter;

##############################################################################

=head3 get

  my $item = $coll->get($index);

Returns the item in the collection slot for the numeric C<$index>. Sets the
current position of the collection to C<$index>. As a side effect, it loads
the collection from the iterator up to C<$index>.

=cut

sub get {
    my ( $self, $index ) = @_;
    $self->_fill_to($index);
    return $self->_check( $self->_array->value_at($index) );
}

##############################################################################

=head3 set

 $coll->set($index, $value);

Sets the value of the collection at C<$index> to C<$value>. As a side effect,
it loads the collection from the iterator up to C<$index>. As a side effect,
C<added()>, C<removed()> will no longer return values, C<is_cleared()> will
return false, and C<is_assigned()> will return true, because it is assumed
that the whole collection has been reordered.

=cut

sub set {
    my ( $self, $index, $value ) = @_;
    $value = $self->_check($value);
    $self->_fill_to($index);
    my $array = $self->_array;
    my $key   = $array->key_at($index);
    $array->insert_after($key, _key $value => $value);
    $array->delete($key);
    delete @{ $self }{ qw(added removed cleared) };
    $self->{assigned} = 1;
    return $self;
}

##############################################################################

=head3 assign

  $coll->assign(@values);

Assigns a list of values to the collection in the order in which they're
passed. All previously-existing values will be discarded and the index will be
reset. As a result, C<added()> and C<removed()> will return now values,
C<is_cleared()> will return false, and the collection will be reset, as it has
been assigned to.

=cut

sub assign {
    my $self = shift;
    delete @{$self}{qw(iter added removed cleared)};
    my %seen;
    my @assigned = do {
        no warnings 'uninitialized';
        map  { $self->_check($_) } grep {  !$seen{_key $_}++; } @_;
    };
    $self->{assigned} = 1;
    $self->{filled} = 0;
    $self->{iter} = Iterator->new(sub { shift @assigned } );
    @{$self}{qw(index got)} = (NULL, NULL);
    $self->{array}->clear;
    return $self;
}

##############################################################################

=head3 is_assigned

  if ($coll->is_assigned) {
      print "Values have been set or assigned\n";
  }

Returns true if values have been set or assigned by one or more calls to
C<set()> or C<assigned()> and no subsequent call to C<clear()>.

=cut

sub is_assigned { shift->{assigned} }

##############################################################################

=head3 add

  $coll->add(@values);

Adds a list of values to the end of the collection. This method does I<not>
load the collection from the iterator. Returns the collection object.

=cut

sub add {
    my $self = shift;
    return $self unless @_;

    # Create the AsHash array of added items.
    my $added = $self->{added} || AsHash->new;
    $self->{added} ||= $added unless $self->{assigned};
    my $removed = $self->{removed} || {};
    my $array = $self->_array;

    # Collect the items to be added.
    my @to_push;
    for my $item (@_) {
        my $key = _key $item;
        next if $added->exists($key) || $array->exists($key);
        push @to_push, $key => $self->_check($item );
        delete $removed->{$key};
    }
    return $self unless @to_push;
    $added->push(@to_push);

    if ( $self->{filled} ) {
        $array->push(@to_push);
    } else {
        # Create a new iterator that returns the added items.
        my $iter = $self->{iter};
        $self->{iter} = Iterator->new(
            sub {
                if (defined( my $val = $iter->next )) {
                    return $val;
                }
                return $added->value_at(++$self->{added_index});
            }
        );
    }
    return $self;

}

##############################################################################

=head3 added

  my @added = $coll->added;
  my $added = $coll->added;

Returns a list or array reference of items that have been added to the
collection by one or more calls to C<add()>. Returns an empty list or C<undef>
if no items have been added or if the collection has been modified by a call
to C<set()> or C<assign()> or C<clear()>.

=cut

sub added {
    my $self = shift;
    my $added = $self->{added} or return;
    return unless $added->acount;
    return wantarray ? $added->values : [ $added->values ];
}

##############################################################################

=head3 remove

  $coll->remove(@values);

Removes a list of values to the end of the collection. This method does I<not>
load the collection from the iterator. Returns the collection object.

=cut

sub remove {
    my $self = shift;
    return $self unless @_;

    # Create the hash of items to be removed.
    my $removed = $self->{removed} || {};
    $self->{removed} ||= $removed unless $self->{assigned};
    my $added = $self->{added};

    # Add the removed items to the hash and remove them from the array.
    my $array = $self->_array;
    for my $item (@_) {
        my $key = _key $item;
        $array->delete($key);
        $added->delete($key) if $added;
        $removed->{$key} = $item;
    }

    # Create a new iterator to filter out the deleted items.
    my $iter = $self->{iter};
    $self->{iter} = Iterator->new(
        sub {
            while (defined( my $val = $iter->next )) {
                return $val unless $removed->{_key $val};
            }
        }
    );

    return $self;
}

##############################################################################

=head3 removed

  my @removed = $coll->removed;
  my $removed = $coll->removed;

Returns a list or array reference of items that have been removed from the
collection by one or more calls to C<remove()>. Returns an empty list or
C<undef> if no items have been removed or if the collection has been modified
by a call to C<set()> or C<assign()> or C<clear()>.

=cut

sub removed {
    my $self = shift;
    my $removed = $self->{removed} or return;
    return unless %{ $removed };
    return wantarray ? values %{ $removed } : [ values %{ $removed } ];
}

##############################################################################

=head3 index

 my $index = $coll->index;

Returns the current numeric value of the index. Returns C<undef> if the
collection is not yet pointing at anything.

=cut

sub index {
    my $self = shift;
    return if $self->{index} == NULL;
    return $self->{index};
}

##############################################################################

=head3 reset

 $coll->reset;

C<reset> resets the collection. The collection will now behave like a new
collection has been created with the same iterator.

=cut

sub reset { @{+shift}{qw(index added_index)} = (NULL, NULL) }

##############################################################################

=head3 size

 my $size = $coll->size;

Returns the number of items in the collection. As a side effect, it loads
the entire collection from the iterator.

=cut

sub size {
    my $self = shift;
    $self->_fill;
    return scalar $self->_array->hcount;
}

##############################################################################

=head3 clear

 $coll->clear;

Empties the collection. All existing values in the collection will be
discarded, C<removed()> and C<added()> will return no values, and
C<assigned()> will return false.

=cut

sub clear {
    my $self = shift;
    $self->{iter}        = Iterator->new(sub {});
    $self->{got}         = NULL;
    $self->{index}       = NULL;
    $self->{added_index} = NULL;
    $self->{cleared}     = 1;
    $self->{array}->clear;
    delete @{ $self }{qw(added removed assigned)};
    return $self;
}

##############################################################################

=head3 is_cleared

  if ($coll->is_cleared) {
      print "The collection has been cleared\n";
  }

Returns true if the collection has been cleared by a call to C<clear()> and
there have been no subsequent calls to C<set()> or C<assigned()>.

=cut

sub is_cleared { shift->{cleared} }

##############################################################################

=head3 peek

 my $item = $coll->peek;

Peek at the next item of the list without advancing the collection.

=cut

sub peek {
    my $self = shift;
    return $self->get( $self->index + 1 );
}

##############################################################################

=head3 all

  my @all = $coll->all;
  my $all = $coll->all;

Returns a list or array reference of all items in the collection. Returns an
array reference in scalar context. The entire collection will be loaded from
the iterator.

=cut

sub all {
    my $self = shift;
    $self->_fill;
    $self->reset;
    my @values = $self->_array->values;
    $self->{got} = $#values;
    return wantarray ? @values : \@values;
}

##############################################################################

=head3 do

  $coll->do( sub { print "$_[0]\n"; return $_[0]; } );
  $coll->do( sub { print "$_\n"; return $_; } );

Pass a code reference to this method to execute it for each item in the
collection. Each item will be set to C<$_> before executing the code
reference, and will also be passed as the sole argument to the code reference.
If C<next()> has been called prior to the call to C<do()>, then only the
remaining items in the iterator will passed to the code reference. Call
C<reset()> first to ensure that all items will be processed. Iteration
terminates when the code reference returns a false value, so be sure to have
it return a true value if you want it to iterate over every item.

=cut

sub do {
    my ( $self, $code ) = @_;
    while ( defined( local $_ = $self->next ) ) {
        return unless $code->($_);
    }
}

##############################################################################

=begin private

=head2 Private Instance Methods

These methods are designed to be used by subclasses.

=head3 _fill

  $coll->_fill;

Fills the collection up with all of the items returned by the iterator object.
Called by C<size()>, and C<all()>. Called implicitly by C<clear()>, which
calls C<all()>.

=cut

sub _fill {
    my $self = shift;
    return if $self->{filled};
    $self->_array->push(
        map { _key $_, $self->_check($_) } $self->iter->all
    );
    $self->{filled} = 1;
}

##############################################################################

=head3 _fill_to

  $coll->_fill_to($index);

Like C<_fill>, but only fills the collection up to the specified index. This
is usefull when you must fill part of the collection but filling all of it
would be expensive. Called by C<get()> and C<set()>.

=cut

sub _fill_to {
    my ( $self, $index ) = @_;
    if ( !$self->{filled} && $index > $self->{got} ) {
        my $array = $self->_array;
        my $iter  = $self->iter;
        while ( $iter->peek && $index > $self->{got} ) {
            $self->{got}++;
            my $next = $iter->next;
            $array->push( _key $next, $self->_check($next) );
        }
        $self->{filled} = 1 unless $iter->current;
    }
    return $self;
}

##############################################################################

=head3 _array

  my $array = $collection->_array;

Returns the C<Array::AsHash> object. For internal use only. If ingested, do
not induce vomiting.

=cut

sub _array { shift->{array} }

##############################################################################

=head3 _inc_index

  $collection->_inc_index;

Increments the collection index by one.

=cut

sub _inc_index { ++shift->{index} }

##############################################################################

=head3 _dec_index

  $collection->_dec_index;

Decrements the collection index by one.

=cut

sub _dec_index { shift->{index}-- }

##############################################################################

=head3 _check

  $value = $collection->_check($value);

Returns the C<$value> unchanged for untyped collections. Otherwise, throws a
C<Object::Relation::Exception::Fatal::Invalid> exception if the C<$value> does not
match the collection type (class or subclass).

=cut

sub _check {
    my ( $self, $value ) = @_;
    return unless defined $value;
    my $package = $self->package or return $value;
    return $value if eval { $value->isa($package) };
    throw_invalid [
        'Value "[_1]" is not a valid [_2] object',
        $value,
        $package
    ];
}

##############################################################################

=head3 _set_package

  my $package = Object::Relation::Collection->_set_package($self_hashref);

If we have a typed collection, this method sets the package and key for the
collection. As an arguments, takes the hashref which will eventually be
blessed into the class. Returns the correct class to bless the hashref into.

=cut

sub _set_package {
    my ( $class, $hashref ) = @_;
    my $key = $hashref->{key};
    if ( __PACKAGE__ ne $class ) {
        my $package = __PACKAGE__;
        ( $key = $class ) =~ s/^$package\:://;
        $key = lc $key;
    }

    return $class unless defined $key;

    # we have a typed collection!
    my $class_object = Object::Relation::Meta->for_key($key) or throw_invalid_class [
        'I could not find the class for key "[_1]"',
        $key
    ];

    $hashref->{package} = $class_object->package;
    $hashref->{key}     = $key;

    $class = __PACKAGE__ . "::\u$key";
    no strict 'refs';
    @{"$class\::ISA"} = __PACKAGE__;

    return $class;
}

##############################################################################

=head3 _clear_dupes

  _clear_dupes(\@list);

Given an array reference, this method will return the array reference with any
duplicate entries removed.

=cut

sub _clear_dupes {
    my $list = shift;

    my %found;
    for my $i (0..$#$list) {
        no warnings 'uninitialized';
        delete $list->[$i] if $found{_key $list->[$i]}++;
    }
    return $list;
}

=end private

=cut

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@obj_relode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
