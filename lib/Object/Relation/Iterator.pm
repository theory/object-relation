package Object::Relation::Iterator;

# $Id$

use strict;

our $VERSION = '0.11';

use Object::Relation::Exceptions qw(throw_invalid);
use Scalar::Util qw/blessed/;

=head1 Name

Object::Relation::Iterator - Object::Relation iterator class

=head1 Synopsis

  use Object::Relation::Iterator;

  my $iter = Object::Relation::Iterator->new(\&closure);
  while (my $thing = $iter->next) {
      # Do something with $thing.
  }

=head1 Description

This class provides an iterator interface for accessing a list of items,
generally Object::Relation objects. Users generally won't create iterator objects
directly, but will get them back from calls to the C<search()> method of
Object::Relation::Store.

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

  my $iter = Object::Relation::Iterator->new(\&code_ref);
  my $iter = Object::Relation::Iterator->new(\&code_ref, \&destroy_code_ref);

Constructs and returns a new iterator object. The code reference passed as the
first argument is required and must return the next item to iterate over each
time it is called, and C<undef> when there are no more items. C<undef> cannot
itself be an item. The optional second argument must also be a code reference,
and will only be executed when the iterator object is destroyed (that is, it
will be called in the C<DESTROY()> method).

B<Throws:>

=over 4

=item Fatal::Invalid

=back

=cut

sub new {
    my ( $class, $code, $destroy ) = @_;
    throw_invalid [ 'Argument "[_1]" is not a code reference', $code ]
      if ref $code ne 'CODE';
    throw_invalid [ 'Argument "[_1]" is not a code reference', $destroy ]
      if $destroy && ref $destroy ne 'CODE';
    bless { code => $code, destroy => $destroy }, $class;
}

DESTROY {
    my $dest = shift->{destroy} or return;
    $dest->();
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
the most recent call to C<next()>.

=cut

sub current { shift->{curr} }

##############################################################################

=head3 peek

  while ($iter->peek) {
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
with caution, as it could cause a large number of Object::Relation objects to be
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

In the event that the iterator was created by a C<Object::Relation::search> request,
this method will return the intermediate representation (IR) generated by the
C<Object::Relation::Parser>. This IR is an array reference of
C<Object::Relation::Search> objects. This is useful if you have an iterator but
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

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
