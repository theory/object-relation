package Kinetic::Util::Collection;

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

use version;
our $VERSION = version->new('0.0.1');

use Kinetic::Meta;
use Kinetic::Util::Exceptions qw(throw_invalid throw_invalid_class);
use aliased 'Kinetic::Util::Iterator';
use aliased 'Array::AsHash';

use Scalar::Util qw(blessed refaddr);

# to simplify the code, we use -1 instead of undef for "null" indexes
use Readonly;
Readonly our $NULL => -1;

sub _key($) {
    my $thing = shift;
    return defined $thing->uuid ? $thing->uuid : refaddr $thing;
}

=head1 Name

Kinetic::Util::Collection - Kinetic collection class

=head1 Synopsis

  use Kinetic::Util::Collection;

  my $coll = Kinetic::Util::Collection->new(
     {
         iter => $iterator,
         key  => $key        # optional
     }
  );
  while (my $thing = $coll->next) {
      # Do something with $thing.
  }

=head1 Description

This class provides an interface for accessing a collection of Kinetic
objects. Users generally won't create collection objects directly, but will
get them back from accessor methods for collections of objects related to an
object.

Note that the collection is essentially an ordered set.  Duplicate items are
not allowed and order is important.

Also, a collection can be for objects other than Kinetic objects, but the
objects must provide a C<uuid> method.

If the key is not supplied, the collection is untyped.  If the key is
supplied, the collection is I<typed>.  All objects in the collection must
either be Kinetic classes or subclasses for the key C<$key>.  =cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $coll = Kinetic::Util::Collection->new($iterator);

Constructs and returns a new collection object. The only argument is a
Kinetic::Util::Iterator object, which will provide the list of items in the
collection.

B<Throws:>

=over 4

=item Fatal::Invalid

=back

=cut

sub new {
    my ( $class, $arg_for ) = @_;
    $arg_for ||= {};
    my ( $iter, $key ) = @{$arg_for}{qw/iter key/};
    {
        $iter ||= '';
        throw_invalid [
            'Argument "[_1]" is not a valid [_2] object',
            $iter,
            Iterator
          ]
          unless eval { $iter->isa(Iterator) };
    }

    my $self = {
        iter    => $iter,
        index   => $NULL,
        array   => AsHash->new( { strict => 1 } ),
        got     => $NULL,
        key     => $key,
        package => undef,
    };
    $class = $class->_set_package($self);
    bless $self, $class;
}

##############################################################################

=head3 empty

  my $collection = Kinetic::Util::Collection->empty;
  my $collection = Kinetic::Util::Collection->empty( $key );

Syntactic sugar for creating a new, empty collection.  Takes an optional key
to force a typed collection.

=cut

sub empty {
    my $class = shift;
    my @key;
    @key = ( key => shift ) if @_;
    return $class->new( { iter => Iterator->new( sub { } ), @key } );
}

##############################################################################

=head3 from_list

  my $coll = Kinetic::Util::Collection->from_list(
     {
         list => \@list,
         key  => $key,    # optional
     }
 );

When passed a list, returns a collection object for said list.  If the key is
present, all objects in C<@list> must be objects whose classes correspond to
said key.

For convenience, this method may also be called from a collection instance and
it returns a new collection.  Uses the collection type, if any, from the
invoking instance, unless an explicit key is used.

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
    my @key;
    push @key => ( key => $key ) if defined $key;
    my @list = @$list;    # copy the array to avoid changing called array
    return $class->new(
        { iter => Iterator->new( sub { shift @list } ), @key } );
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
in sequence.  If you attempt to fetch an item beyond the end of the current
collection size, the collection returns false and the position of the
collection will not be changed.  Call C<curr()> to get the value at the current
position of the index.

=cut

sub next {
    my $self = shift;
    if ( defined $self->{got} && $self->{got} > ( $self->index || 0 ) ) {

        # we've been here before
        $self->_inc_index;
        return $self->curr;
    }
    my $result = $self->_check( $self->iter->next );
    return unless defined $result;
    $self->_inc_index;
    $self->{got} = $self->index;
    $self->_array->push( _key $result, $result );
    return $result;
}

##############################################################################

=head3 package

  my $package = $collection->package;

If the collection is typed (see C<new>), this method will return the type of
objects allowed in the collection.

=cut

sub package { shift->{package} }

##############################################################################

=head3 curr

  my $current = $coll->curr;

Returns the value at the current position of the collection.

=cut

sub curr {
    my $self = shift;
    return if $self->index == $NULL;
    return $self->_check( $self->_array->value_at( $self->index ) );
}

##############################################################################

=head3 current

 my $current = $coll->current;

A convenient alias for C<curr>.

=cut

*current = \&curr;

##############################################################################

=head3 prev

  my $previous = $coll->prev;

Returns the value at the previous position of the collection.  Also sets the
current collection value to that position.  If we're already at the start of
the collection, this method returns undef and does not change the position.

=cut

sub prev {
    my $self = shift;
    return unless $self->index > 0;
    $self->_dec_index;
    return $self->curr;
}

##############################################################################

=head3 iter

  my $iterator = $coll->iter;

This method returns the iterator the collection has.

=cut

sub iter { shift->{iter} }

##############################################################################

=head3 get

 my $item = $coll->get($index);

Returns the item in the collection slot for the numeric C<$index>.  Sets the
current position of the collection to C<$index>.

=cut

sub get {
    my ( $self, $index ) = @_;
    $self->_fill_to($index);
    return $self->_check( $self->_array->value_at($index) );
}

##############################################################################

=head3 set

 $coll->set($index, $value);

Sets the value of the collection at C<$index> to C<$value>.

=cut

sub set {
    my ( $self, $index, $value ) = @_;
    $value = $self->_check($value);
    $self->_fill_to($index);
    my $array = $self->_array;
    my $key   = $array->key_at($index);
    $array->put( $key, $value );
}

##############################################################################

=head3 index

 my $index = $coll->index;

Returns the current numeric value of the index.  Returns undef if the collection
is not yet pointing at anything.

=cut

sub index {
    my $self = shift;
    return if $self->{index} == $NULL;
    return $self->{index};
}

##############################################################################

=head3 reset

 $coll->reset;

C<reset> resets the collection.  The collection will now behave like a new
collection has been created with the same iterator.

=cut

sub reset { shift->{index} = $NULL }

##############################################################################

=head3 size

 my $size = $coll->size;

Returns the number of items in the collection.

=cut

sub size {
    my $self = shift;
    $self->_fill;
    return scalar $self->_array->hcount;
}

##############################################################################

=head3 clear

 $coll->clear;

Empties the collection.

=cut

sub clear {
    my $self = shift;
    $self->iter->all if defined $self->{got};
    $self->{got}   = undef;
    $self->{index} = $NULL;
    $self->{array} = AsHash->new( { strict => 1 } );
}

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

Return a list of all items in the collection.  Returns an array reference in
scalar context.

=cut

sub all {
    my $self = shift;
    $self->_fill;
    $self->reset;
    return $self->_array->values;
}

##############################################################################

=head3 do

 $code->do($anon_sub);

Call a function with each element of the list until the function returns
false. This method always resets the collection, first, so the code reference
is applied from the beginning of the collection.

=cut

sub do {
    my ( $self, $code ) = @_;
    $self->reset;
    while ( defined( my $item = $self->next ) ) {
        return unless $code->($item);
    }
}

##############################################################################

=begin private

=head2 Private Instance Methods

These methods are designed to be used by subclasses.

=head3 _fill

  $coll->_fill;

Fills the collection up with all of the items returned by the iterator
object. Called by C<set()>, C<size()>, C<splice()>, and C<all()>. Called
implicitly by C<clear()>, which calls C<all()>.

=cut

sub _fill {
    my $self = shift;
    return unless defined $self->{got};
    $self->_array->push( map { _key $_, $self->_check($_) }
          $self->iter->all );
}

##############################################################################

=head3 _fill_to

  $coll->_fill_to($index);

Like C<_fill>, but only fills the collection up to the specified index.  This
is usefull when you must fill part of the collection but filling all of it
would be expensive.

=cut

sub _fill_to {
    my ( $self, $index ) = @_;
    if ( defined $self->{got} && $index > $self->{got} ) {
        my $array = $self->_array;
        my $iter  = $self->iter;
        while ( $iter->peek && $index > $self->{got}++ ) {
            my $next = $iter->next;
            $array->push( _key $next, $self->_check($next) );
        }
        $self->{got} = undef unless defined $iter->current;
    }
    return $self;
}

##############################################################################

=head3 _array

  my $array = $collection->_array;

Returns the C<Array::AsHash> object.  For internal use only.  If ingested, do
not induce vomiting.

=cut

sub _array { shift->{array} }

##############################################################################

=head3 _inc_index

  $collection->_inc_index;

Increments the collection index by one.

=cut

sub _inc_index { shift->{index}++ }

##############################################################################

=head3 _dec_index

  $collection->_dec_index;

Decrements the collection index by one.

=cut

sub _dec_index { shift->{index}-- }

##############################################################################

=head3 _check

  $value = $collection->_check($value);

Returns the C<$value> unchanged for untyped collections.  Otherwise, throws a
C<Kinetic::Exception::Fatal::Invalid> exception if the C<$value> does not
match the collection type (class or subclass).

=cut

sub _check {
    my ( $self, $value ) = @_;
    return unless defined $value;
    my $package = $self->package or return $value;
    return $value if $value->isa($package);
    throw_invalid [
        'Value "[_1]" is not a valid [_2] object',
        $value,
        $package
    ];
}

##############################################################################

=head3 _set_package 

  my $package = Kinetic::Util::Collection->_set_package($self_hashref);

If we have a typed collection, this method sets the package and key for the
collection.  As an arguments, takes the hashref which will eventually be
blessed into the class.  Returns the correct class to bless the hashref into.

=cut

sub _set_package {
    my ( $class, $hashref ) = @_;
    my $key = $hashref->{key};
    if ( __PACKAGE__ ne $class ) {
        my $package = __PACKAGE__;
        ( $key = $class ) =~ s/^$package\:://;
        $key = lc $key;
    }
    my $package;
    if ( defined $key ) {

        # we have a typed collection!
        my $class_object = Kinetic::Meta->for_key($key)
          or throw_invalid_class [
            'I could not find the class for key "[_1]"',
            $key
          ];
        $hashref->{package} = $class_object->package;
        $hashref->{key}     = $key;

        $class = __PACKAGE__ . "::\u$key";
        no strict 'refs';
        @{"$class\::ISA"} = __PACKAGE__;
    }
    return $class;
}

=end private

=cut

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

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
