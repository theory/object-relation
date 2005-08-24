package Kinetic::HOP::Parser;

# $Id: Parser.pm 1364 2005-03-08 03:53:03Z curtis $

=head1 Name

Kinetic::HOP::Parser - Parser (see "Higher Order Perl")

=head1 Synopsis

  use Kinetic::HOP::Parser qw/:all/;
  
  # assemble a bunch of parsers according to a grammar
  
=head1 Description

This package is based on the Parser.pm code from the book "Higher Order Perl",
by Mark Jason Dominus.

This module implements recursive-descent parsers by allowing programmers to
build a bunch of smaller parsers to represent grammar elements and assemble
them into a full parser. Pages 376 to 415 of the first edition of HOP should
be enough to get you up to speed :)

=cut

use strict;
use warnings;

use base 'Exporter';
use Kinetic::HOP::Stream ':all';

our @EXPORT_OK = qw(
  action
  alternate
  concatenate
  debug
  End_of_Input
  error
  list_of
  lookfor
  match
  nothing
  null_list
  operator
  parser
  star
  T
  test
);

our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

sub parser (&);    # Forward declaration - see below

##############################################################################

=head3 nothing

  my ($parsed, $remainder) = nothing($stream);

C<nothing> is a special purpose parser which is used internally.  It always
succeeds and returns I<undef> for C<$parsed> and the C<$remainder> is the
unaltered input C<$stream>.

=cut

sub nothing {
    my $input = shift;
    return ( undef, $input );
}

##############################################################################

=head3 End_of_Input

  if (End_of_Input($stream)) {
    ...
  }

C<End_of_Input> is another special purpose parser which only succeeds if there
is no input left in the stream.  It's generally used in the I<start symbol> of
the grammar.

  # entire_input ::= statements 'End_Of_Input'

  my $entire_input = concatenate(
    $statements,
    \&End_of_Input
  );


=cut

sub End_of_Input {
    my $input = shift;
    defined($input) ? () : ( undef, undef );
}

##############################################################################

=head3 lookfor

  my $parser = lookfor($label, [\&get_value], [$param]); # or
  my $parser = lookfor(\@label_and_optional_values, [\&get_value], [$param]);
  my ($parsed, $remaining_stream) = $parser->($stream);

The following details the arguments to C<lookfor>.

=over 4

=item * C<$label> or C<@label_and_optional_values>

The first argument is either a scalar with the token label or an array
reference. The first element in the array reference should be the token label
and subsequent elements can be anything you need. Usually the second element
is the token value, but if you need more than this, that's OK.

=item * C<\&get_value>

If an optional C<get_value> subroutine is supplied, that C<get_value> will be
applied to the parsed value prior to it being returned. This is useful if
non-standard tokens are being passed in or if we wish to preprocess the
returned values.

=item * C<$param>

If needed, additional arguments besides the current matched token can be
passed to C<&get_value>. Supply them as the third argument (which can be any
data structure you wish, so long as it's a single scalar value).

=back

In practice, the full power of this function is rarely needed and C<match> is
used instead.

=cut

sub lookfor {
    my $wanted = shift;
    my $value  = shift || sub { $_[0][1] };
    my $u      = shift;

    $wanted = [$wanted] unless ref $wanted;
    return parser {
        my $input = shift;
        return unless defined $input;
        my $next = head($input);
        for my $i ( 0 .. $#$wanted ) {
            next unless defined $wanted->[$i];
            local $^W;    # suppress unitialized warnings XXX
            return unless $wanted->[$i] eq $next->[$i];
        }
        my $wanted_value = $value->( $next, $u );
        return ( $wanted_value, tail($input) );
    };
}

##############################################################################

=head3 match

  my $parser = match($label, [$value]);
  my ($parsed, $remainder) = $parser->($stream);

This function takes a label and an optional value and builds a parser which
matches them by dispatching to C<lookfor> with the arguments as an array
reference. See C<lookfor> for more information.

=cut

sub match { @_ = [@_]; goto &lookfor }

##############################################################################

=head3 parser

  my $parser = parser { 'some code' };

Currently, this is merely syntactic sugar that allows us to declare a naked
block as a subroutine (i.e., omit the "sub" keyword).

=cut

sub parser (&) { $_[0] }

##############################################################################

=head3 concatenate

  my $parser = concatenate(@parsers);
  ok ($values, $remainder) = $parser->($stream);

This function takes a list of parsers and returns a new parser. The new parser
succeeds if all parsers passed to C<concatenate> succeed sequentially.

=cut

sub concatenate {
    shift unless ref $_[0];
    my @p = @_;
    return \&nothing if @p == 0;
    return $p[0]     if @p == 1;

    my $parser = parser {
        my $input = shift;
        my $v;
        my @values;
        for (@p) {
            ( $v, $input ) = $_->($input) or return;
            push @values, $v;
        }
        return ( \@values, $input );
    };
}

##############################################################################

=head3 alternate

  my $parser = alternate(@parsers);
  my ($parsed, $remainder) = $parser->stream;

This function behaves like C<concatenate> but matches one of any tokens
(rather than all tokens sequentially).

=cut

sub alternate {
    my @p = @_;
    return parser { return () }
      if @p == 0;
    return $p[0] if @p == 1;
    my $parser = parser {
        my $input = shift;
        my ( $v, $newinput );
        for (@p) {
            if ( ( $v, $newinput ) = $_->($input) ) {
                return ( $v, $newinput );
            }
        }
        return;
    };
}

## Chapter 8 section 3.3

sub list_of {
    my ( $element, $separator ) = @_;
    $separator = lookfor('COMMA') unless defined $separator;

    return concatenate( $element, star( $separator, $element ) );
}

1;

## Chapter 8 section 4

sub T {
    my ( $parser, $transform ) = @_;
    return parser {
        my $input = shift;
        if ( my ( $value, $newinput ) = $parser->($input) ) {
            local $^W;    # using this to suppress 'uninitialized' warnings
            $value = [$value] if 'undef' eq $value;
            $value = $transform->(@$value);
            return ( $value, $newinput );
        }
        else {
            return;
        }
    };
}

##############################################################################

=head3 null_list

  my ($parsed, $remainder) = null_list($stream);

This special purpose parser always succeeds and returns an empty array
reference and the stream.

=cut

sub null_list {
    my $input = shift;
    return ( [], $input );
}

##############################################################################

=head3 star

  my $parser = star($another_parser);
  my ($parsed, $remainder) = $parser->($stream);

This parser always succeeds and matches zero or more instances of
C<$another_parser>.  If it matches zero, it returns the same results as
C<null_list>.  Otherwise, it returns and array ref of the matched values and
the remainder of the stream.

=cut

sub star {
    my $p = shift;
    my $p_star;
    $p_star = alternate(
        T(
            concatenate( $p, parser { $p_star->(@_) } ),
            sub {
                my ( $first, $rest ) = @_;
                [ $first, @$rest ];
            }
        ),
        \&null_list
    );
}

## Chapter 8 section 4.4

sub operator {
    my ( $subpart, @ops ) = @_;
    my (@alternatives);
    for my $operator (@ops) {
        my ( $op, $opfunc ) = @$operator;
        push @alternatives, T(
            concatenate( $op, $subpart ),
            sub {
                my $subpart_value = $_[1];
                sub { $opfunc->( $_[0], $subpart_value ) }
            }
        );
    }
    my $result = T(
        concatenate( $subpart, star( alternate(@alternatives) ) ),
        sub {
            my ( $total, $funcs ) = @_;
            for my $f (@$funcs) {
                $total = $f->($total);
            }
            $total;
        }
    );
}

## Chapter 8 section 4.7.1

our %N;

sub error {
    my ( $checker, $continuation ) = @_;
    my $p;
    $p = parser {
        my $input = shift;

        while ( defined($input) ) {
            if ( my ( undef, $result ) = $checker->($input) ) {
                $input = $result;
                last;
            }
            else {
                drop($input);
            }
        }

        return unless defined $input;

        return $continuation->($input);
    };
    $N{$p} = "errhandler($N{$continuation} -> $N{$checker})";
    return $p;
}

## Chapter 8 section 6

sub action {
    my $action = shift;
    return parser {
        my $input = shift;
        $action->($input);
        return ( undef, $input );
    };
}

sub test {
    my $action = shift;
    return parser {
        my $input  = shift;
        my $result = $action->($input);
        return $result ? ( undef, $input ) : ();
    };
}

sub debug { shift; @_ }    # see Parser::Debug::debug

1;

__END__

=head1 Copyright and License

This software is derived from code in the book "Higher Order Perl" by Mark
Jason Dominus. This software is licensed under the terms outlined in
L<Kinetic::HOP::License|Kinetic::HOP::License>.

