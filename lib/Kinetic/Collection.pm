package Kinetic::Collection;

# $Id$

use strict;
use Kinetic::Exceptions qw(throw_invalid);

=head1 Name

Kinetic::Collection - Kinetic collection class

=head1 Synopsis

  use Kinetic::Collection;

  my $coll = Kinetic::Collection->new($iterator);
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

  my $coll = Kinetic::Collection->new($iterator);

Constructs and returns a new collection object. The only argument is a
Kinetic::Iterator object, which will provide the list of items in the
collection.

B<Throws:>

=over 4

=item Fatal::Invalid

=back

=cut

sub new {
    my ($class, $iter) = @_;
    throw_invalid ['Argument "[_1]" is not a [_2] object', $iter,
                   'Kinetic::Iterator']
      unless UNIVERSAL::isa($iter, 'Kinetic::Iterator');
    bless { iter => $code, index => -1, array => [], got => -1 }, $class;
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

Returns the next item in the collection. Calling C<next()> multiple times will
return each item in sequence. Once all of the items have been returned via
C<next()>, the index will be reset and the next call to C<next()> will start
over again at the begining of the collection. In general, this is not a
problem, because the last value returned by the iterator will be an
C<undef>. However, if you've resized or spliced the collection so that there
are C<undef> values in the collection, then C<next()> may return C<undef>
before reaching the end of the collection. The best rule of thumb is to use
C<next()> only if you're not resizing or splicing the collection.

=cut

sub next {
    my $self = shift;
    my $ret = $self->get(++$self->{index});
    $self->reset if $self->{index} >= $#{$self->{array}}
      and not defined $self->{got};
    return $ret;
}

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
    return if $self->{index} = -1;
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

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item L<Kinetic::Iterator|Kinetic::Iterator>

A Kinetic iterator object provides the initial list of items in a
collection.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This Library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
