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

use Kinetic::Util::Exceptions qw(throw_invalid);
use aliased 'Kinetic::Util::Iterator';
use aliased 'Array::AsHash';

# to simplify the code, we use -1 instead of undef for "null" indexes
use Readonly;
Readonly our $NULL => -1;

=head1 Name

Kinetic::Util::Collection - Kinetic collection class

=head1 Synopsis

  use Kinetic::Util::Collection;

  my $coll = Kinetic::Util::Collection->new($iterator);
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

=cut

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
    my ( $class, $iter ) = @_;
    {
        $iter ||= '';
        throw_invalid [
            'Argument "[_1]" is not a valid [_2] object',
            $iter,
            Iterator
          ]
          unless eval { $iter->isa( Iterator ) };
    }
    bless {
        iter  => $iter,
        index => $NULL,
        array => AsHash->new( { strict => 1 } ),
        got   => $NULL,
    }, $class;
}

##############################################################################

=head3 from_list

  my $coll = Kinetic::Util::Collection->from_list(@list);

When passed a list, returns a collection object for said list.

=cut

sub from_list {
    my ( $class, @list ) = @_;
    return $class->new( Iterator->new( sub { shift @list } ) );
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

# I am forced to conclude that iterators are not permitted to return an undef
# value.  This is annoying.

sub next {
    my $self = shift;
    if ( defined $self->{got} && $self->{got} > $self->{index} ) {

        # we've been here before
        $self->{index}++;
        return $self->_array->value_at( $self->index );
    }
    my $result = $self->iter->next;
    return unless defined $result;
    $self->{got} = ++$self->{index};
    $self->_array->push( $result->uuid, $result )
      ;    # XXX sanity check for duplicates!
    return $result;
}

##############################################################################

=head3 curr

  my $current = $coll->curr;

Returns the value at the current position of the collection.

=cut

sub curr {
    my $self = shift;
    return if $self->index == $NULL;
    return $self->_array->value_at( $self->index );
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
    return $self->_array->value_at( --$self->{index} );

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
    return $self->_array->value_at($index);
}

##############################################################################

=head3 set

 $coll->set($index, $value);

Sets the value of the collection at C<$index> to C<$value>.

=cut

# Should we allow optional typing?

sub set {
    my ( $self, $index, $value ) = @_;
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

=head3 splice

 my @list = $coll->splice(@splice_args);

Operates just like C<splice>.

=cut

sub splice {
    my $self = shift;
    return unless @_;
    $self->_fill;
    my $array  = $self->_array;
    my $index  = shift;
    my $last   = @_ ? shift: $array->hcount - 1;
    my @keys   = $array->key_at( $index .. $last );
    my @values = $array->value_at( $index .. $last );
    $array->delete(@keys);

    if (@_) {
        my @list = map { $_->uuid => $_ } @_;
        if ($index) {
            my $key = $array->key_at( $index - 1 );
            $array->insert_after( $key, @list );
        }
        else {
            $array->push(@list);
        }
    }
    return @values;
}

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
    $self->_array->push( map { $_->uuid, $_ } $self->iter->all );
}

##############################################################################

=head3 _fill_to

  $coll->_fill_to($index);t

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
            $array->push( $next->uuid, $next );
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
