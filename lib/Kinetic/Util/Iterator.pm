package Kinetic::Util::Iterator;

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
use Scalar::Util qw/blessed/;

=head1 Name

Kinetic::Util::Iterator - Kinetic iterator class

=head1 Synopsis

  use Kinetic::Util::Iterator;

  my $iter = Kinetic::Util::Iterator->new(\&closure);
  while (my $thing = $iter->next) {
      # Do something with $thing.
  }

=head1 Description

This class provides an iterator interface for accessing a list of items,
generally Kinetic objects. Users generally won't create iterator objects
directly, but will get them back from calls to the C<search()> method of
Kinetic::Store.

The basic interface for iterator objects is the C<next()> instance
method. This method will return each item in turn, and will return C<undef>
when there are no more items. Therefore, no item can actually be C<undef>.

=cut

##############################################################################

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $iter = Kinetic::Util::Iterator->new(\&closure);

Constructs and returns a new iterator object. The closure passed in must
return the next item to iterate over each time it is called, and C<undef> when
there are no more items. C<undef> cannot itself be an item.

B<Throws:>

=over 4

=item Fatal::Invalid

=back

=cut

sub new {
    my ( $class, $code ) = @_;
    throw_invalid [ 'Argument "[_1]" is not a code reference', $code ]
      unless ref $code eq 'CODE';
    bless { code => $code }, $class;
}

##############################################################################

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 next

  while (my $thing = $iter->next) {
      # Do something with $thing.
  }

Returns the next item in the iterator. Returns C<undef> when there are no more
items to iterate.

=cut

sub next {
    my $self = shift;
    $self->{curr} =
      exists $self->{peek}
      ? delete $self->{peek}
      : $self->{code}->();
    return $self->{curr};
}

##############################################################################

=head3 current

  my $current = $iter->current;

Returns the current item in the iterator--that is, the same item returned by
the last call to C<next()>.

=cut

sub current { shift->{curr} }

##############################################################################

=head3 peek

  while ($iter->peek == 1) {
      $iter->next;
  }

Returns the next item to be returned by C<next()> without actually removing it
from the list of items to be returned. The item returned by C<peek()> will be
returned by the next call to C<next()>. After that, it will not be available
from C<peek()> but the next item will be.

=cut

sub peek {
    my $self = shift;
    return $self->{peek} ||= $self->{code}->();
}

##############################################################################

=head3 all

  for my $item ($iter->all) {
      print "Item: $item\n";
  }

Returns a list or array reference of all of the items to be returned by the
iterator. If C<next()> has been called prior to the call to C<all()>, then
only the remaining items in the iterator will be returned. Use this method
with caution, as it could cause a large number of Kinetic objects to be
loaded into memory at once.

=cut

sub all {
    my $self = shift;
    my @items;
    push @items, $self->next while $self->peek;
    return wantarray ? @items : \@items;
}

##############################################################################

=head3 do

  $iter->do( sub { print "$_[0]\n"; return $_[0]; } );
  $iter->do( sub { print "$_\n"; return $_; } );

Pass a code reference to this method to execute it for each item in the
iterator. Each item will be set to C<$_> before executing the code reference,
and will also be passed as the sole argument to the code reference. If
C<next()> has been called prior to the call to C<do()>, then only the
remaining items in the iterator will passed to the code reference. Iteration
terminates when the code reference returns false, so be sure to have it return
a true value if you want it to iterate over every item.

=cut

sub do {
    my ( $self, $code ) = @_;
    while ( local $_ = $self->next ) {
        return unless $code->($_);
    }
}

##############################################################################

=head3 request

  my $request = $iter->request;
  $iter->request($intermediate_representation);

In the event that the iterator was created by a C<Kinetic::search> request,
this method will return the intermediate representation (IR) generated by the
C<Kinetic::Store::Parser>. This IR is an array reference of
C<Kinetic::Store::Search> objects. This is useful if you have an iterator but
need to know how the results were generated.

The returned request will be a hash reference with the keys being the query
parameter keys and the values being the search object which corresponds to the
given column.

Due to the extremely complicated nature of some searches, this request at the
present time only stores I<simple> searches. Simple searches are those which
implicitly C<AND> their search terms via the comma operator.

 name => 'foo', age => GE 21

Searches with C<AND> or C<OR> compounds are considered complex searches and
are not stored completely:

 name => 'foo', OR(age => GE 21)

=cut

sub request {
    my $self = shift;
    if (@_) {
        my $ir = shift;
        $self->{request} = {
            map {
                blessed $_ && $_->can('param')
                    ? ( $_->param => $_ )
                    : ()
            } @$ir
        };
        return $self;
    }
    return $self->{request};
}

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
