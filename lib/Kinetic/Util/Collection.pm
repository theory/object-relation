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
use Kinetic::Util::Exceptions qw(throw_invalid);

=head1 Name

Kinetic::Util::Collection - Kinetic collection class

=head1 Synopsis

  use Kinetic::Util::Collection;

  my $coll = Kinetic::Util::Collection->new($iterator);
  while (my $thing = $coll->next) {
      # Do something with $thing.
  }

=head1 Description

This class provides an interface for accessing a collection of items,
generally Kinetic objects. Users generally won't create collection objects
directly, but will get them back from accessor methods for collections of
objects related to an object.

=cut

##############################################################################

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
    my ($class, $iter) = @_;
    $iter ||= '';
    throw_invalid ['Argument "[_1]" is not a valid [_2] object', $iter,
                   'Kinetic::Util::Iterator']
      unless UNIVERSAL::isa($iter, 'Kinetic::Util::Iterator');
    bless { 
        iter  => $iter, 
        index => -1,
        array => [], 
        got   => -1,
    }, $class;
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
    if ($self->{got} > $self->{index}) {
        # we've been here before
        $self->{index}++;
        return $self->{array}[$self->{index}];
    }
    my $result = $self->iter->next;
    return unless defined $result;
    $self->{index}++;
    $self->{got} = $self->{index};
    push @{$self->{array}} => $result;
    return $result;
}


##############################################################################

=head3 curr

  my $current = $coll->curr; 

Returns the value at the current position of the collection.

=cut

sub curr { 
    my $self = shift;
    my $index = $self->{index};
    return $self->{array}[$index];
}

##############################################################################

=head3 prev

  my $previous = $coll->prev;

Returns the value at the previous position of the collection.  Also sets the
current collection value to that position.  If we're already at the start of
the collection, this method returns undef and does not change the position.

=cut

sub prev {
    my $self = shift;
    return unless $self->{index} > 0;
    $self->{index}--;
    return $self->{array}[$self->{index}];
} 

##############################################################################

=head3 iter

  my $iterator = $coll->iter;

This method returns the iterator the collection has.

=cut

sub iter { $_[0]->{iter} }

##############################################################################

=head3 get

=cut

sub get {
    my ($self, $index) = @_;
    if (defined $self->{got} && $index > $self->{got}) {
        push @{$self->{array}}, $self->{iter}->next
          while $self->{iter}->peek && $index > $self->{got}++;
        $self->{got} = undef unless defined $self->{iter}->current;
    }
    return $self->{array}[$index];
}

##############################################################################

=head3 set

=cut

sub set {
    my ($self, $index, $value) = @_;
    $self->_fill if defined $self->{got};
    $self->{array}[$index] = $value;
}

##############################################################################

=head3 index

=cut

sub index { shift->{index} }

##############################################################################

=head3 reset

=cut

sub reset { shift->{index} = -1 }

##############################################################################

=head3 size

=cut

sub size {
    my $self = shift;
    $self->_fill if defined $self->{got};
    return $#{$self->{array}} + 1;
}

##############################################################################

=head3 clear

=cut

sub clear {
    my $self = shift;
    $self->{iter}->all if defined $self->{got};
    $self->{got} = undef;
    @{$self->{array}} = ();
}

##############################################################################

=head3 splice

=cut

sub splice {
    my $self = shift;
    return unless @_;
    $self->_fill if defined $self->{got};
    CORE::splice @{$self->{array}}, @_;
}

##############################################################################

=head3 extend

=cut

sub extend {
    my ($self, $index) = @_;
    $#{$self->{array}} = $index unless $#{$self->{array}} >= $index;
}

##############################################################################

=head3 current

=cut

sub current {
    my $self = shift;
    return if $self->{index} == -1;
    return $self->get($self->{index});
}

##############################################################################

=head3 peek

=cut

sub peek {
    my $self = shift;
    return $self->get($self->{index} + 1);
}

##############################################################################

=head3 all

=cut

sub all {
    my $self = shift;
    $self->_fill if defined $self->{got};
    $self->reset;
    return wantarray ? @{$self->{array}} : $self->{array};
}

##############################################################################

=head3 do

=cut

sub do {
    my ($self, $code) = @_;
    $self->reset;
    while (my $item = $self->next) {
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
    push @{$self->{array}}, $self->{iter}->all;
    $self->{got} = undef;
}

=end private

=cut

1;
__END__

##############################################################################

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
