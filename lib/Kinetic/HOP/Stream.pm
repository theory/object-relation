package Kinetic::HOP::Stream;

# $Id: Code.pm 1364 2005-03-08 03:53:03Z curtis $

=head1 Name

Kinetic::HOP::Stream - Streams (see "Higher Order Perl")

=head1 Synopsis

  use Kinetic::Store::Lexer::Code qw/code_lexer_stream/;
  my $stream = code_lexer_stream([ 
    name => NOT LIKE 'foo%',
    OR (age => GE 21)
  ]);

=head1 Description

This package is based on the Stream.pm code from the book "Higher Order Perl",
by Mark Jason Dominus.

A stream is conceptually similar to a linked list. However, we may have an
infinite stream. As infinite amounts of data are frequently taxing to the
memory of most systems, the tail of the list may be a I<promise>. A promise,
in this context, is merely a promise that the code will compute the rest of
the list if necessary. Thus, the rest of the list does not exist until
actually needed.

=cut

use warnings;
use strict;

use base 'Exporter';
our @EXPORT_OK = qw(
  drop
  filter
  head
  iterator_to_stream
  list_to_stream
  merge
  node
  promise
  show
  tail
  transform
);

our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

=head1 FUNCTIONS

All functions in this package may be exported on demand. Nothing is exported
by default.

 use Kinetic::HOP::Stream ':all';
 use Kinetic::HOP::Stream qw/node drop/;

=head2 Exportable functions

The following functions are exported on demand.

=cut

##############################################################################

=head3 node

 my $node = node( $head, $tail );

Returns a node for a stream. A node is merely a two-element array reference:

 [ $head, $tail ]

The tail of the node may be a I<promise> to compute the actual tail when
needed. Thus, we want to use the proper C<head> and C<tail> functions to
manipulate the stream rather than reaching directly into the array references.

=cut

sub node {
    my ( $h, $t ) = @_;
    [ $h, $t ];
}

##############################################################################

=head3 head

  my $head = head( $node );

Returns the head of a node.

=cut

sub head {
    my ($s) = @_;
    $s->[0];
}

##############################################################################

=head3 is_promise

  if ( is_promise($tail) ) {
     ...
  }

Returns true if the tail of a node is a promise. Generally this function is
used internally.

=cut

sub is_promise {
    UNIVERSAL::isa( $_[0], 'CODE' );
}

##############################################################################

=head3 promise

  my $promise = promise { ... };

A utility function with a code prototype (C<< sub promise(&); >>) allowing one
to specify a coderef with curly braces and omit the C<sub> keyword.

=cut

sub promise (&) { $_[0] }

##############################################################################

=head3 show

 show( $stream, [ $number_of_nodes ] ); 

This is a debugging function that will print C<$number_of_nodes> of the stream
C<$stream>.

Omitting the second argument will print all elements of the stream. This is
not recommended for infinite streams (duh).

=cut

sub show {
    my ( $s, $n ) = @_;
    while ( $s && ( !defined $n || $n-- > 0 ) ) {
        _print( head($s), $" );
        $s = tail($s);
    }
    _print($/);
}

##############################################################################

=head3 drop

  my $head = drop( $stream );

This is the C<shift> function for streams. It returns the head of the stream
and and modifies the stream in-place to be the tail of the stream.

=cut

sub drop {
    my $h = head( $_[0] );
    $_[0] = tail( $_[0] );
    return $h;
}

##############################################################################

=head3 transform

  my $new_stream = transform { $_[0] * 2 } $old_stream;

This is the C<map> function for streams. It returns a new stream, but is not
recommended for infinite streams.

=cut

sub transform (&$) {
    my $f = shift;
    my $s = shift;
    return unless $s;
    node( $f->( head($s) ), promise { transform ( $f, tail($s) ) } );
}

##############################################################################

=head3 filter

  my $new_stream = filter { $_[0] % 2 } $old_stream;

This is the C<grep> function for streams. It returns a new stream, but is not
recommended for infinite streams.

=cut

sub filter (&$) {
    my $f = shift;
    my $s = shift;
    until ( !$s || $f->( head($s) ) ) {
        drop($s);
    }
    return if !$s;
    node( head($s), promise { filter ( $f, tail($s) ) } );
}

##############################################################################

=head3 tail

 my $tail = tail( $stream ); 

Returns the I<tail> of a stream.

=cut

sub tail {
    my ($s) = @_;
    if ( is_promise( $s->[1] ) ) {
        $s->[1] = $s->[1]->();
    }
    $s->[1];
}

##############################################################################

=head3 merge

  my $merged_stream = merge( $stream1, $stream2 );

This function takes two streams assumed to be in sorted order and merges them
into a new stream, also in sorted order. Tails of the streams are promises, so
infinite streams are fine.

=cut

sub merge {
    my ( $S, $T ) = @_;
    return $T unless $S;
    return $S unless $T;
    my ( $s, $t ) = ( head($S), head($T) );
    if ( $s > $t ) {
        node( $t, promise { merge( $S, tail($T) ) } );
    }
    elsif ( $s < $t ) {
        node( $s, promise { merge( tail($S), $T ) } );
    }
    else {
        node( $s, promise { merge( tail($S), tail($T) ) } );
    }
}

##############################################################################

=head3 list_to_stream

  my $stream = list_to_stream(@list);

Converts a list into a stream.

=cut

sub list_to_stream {
    my $node = pop;
    while (@_) {
        $node = node( pop, $node );
    }
    $node;
}

##############################################################################

=head3 iterator_to_stream

  my $stream = iterator_to_stream($iterator);

Converts an iterator into a stream.

=cut

sub iterator_to_stream {
    my $it = shift;
    my $v  = $it->();
    return unless defined $v;
    node( $v, sub { iterator_to_stream($it) } );
}

sub _print { print @_ }

1;

__END__

=head1 Copyright and License

This software is derived from code in the book "Higher Order Perl" by Mark
Jason Dominus. This software is licensed under the terms outlined in
L<Kinetic::HOP::License|Kinetic::HOP::License>.

=cut
