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
use Kinetic::HOP::Stream qw/drop tail head/;

our %N;

our @EXPORT_OK = qw(
  absorb
  action
  alternate
  concatenate
  debug
  fetch_error
  End_of_Input
  error
  list_of
  list_values_of
  lookfor
  match
  nothing
  null_list
  operator
  optional
  parser
  rlist_of
  rlist_values_of
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
    return ( undef, undef ) unless defined($input);
    die [ "End of input", $input ];
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
    my $param  = shift;

    $wanted = [$wanted] unless ref $wanted;
    my $parser = parser {
        my $input = shift;
        unless ( defined $input ) {
            die [ 'TOKEN', $input, $wanted ];
        }

        my $next = head($input);
        for my $i ( 0 .. $#$wanted ) {
            next unless defined $wanted->[$i];
            no warnings 'uninitialized';
            unless ($wanted->[$i] eq $next->[$i]) {
                die [ 'TOKEN', $input, $wanted ];
            }
        }
        my $wanted_value = $value->( $next, $param );

        # the following is unlikely to affect a stream with a promise
        # for a tail as the promise tends to Do The Right Thing.
        #
        # Otherwise, the AoA stream might just return an aref for
        # the tail instead of an AoA.  This breaks things
        my $tail = tail($input);
        if ( 'ARRAY' eq ref $tail && 'ARRAY' ne ref $tail->[0] ) {
            $tail = [$tail];
        }
        return ( $wanted_value, $tail );
    };
    $N{$parser} = "[@$wanted]";
    return $parser;
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

C<concatenate> will discard undefined values.  This allows us to do this and
only return the desired value(s):

  concatenate(absorb($lparen), $value, absorb($rparen))

=cut

sub concatenate {
    shift unless ref $_[0];
    my @parsers = @_;
    return \&nothing   if @parsers == 0;
    return $parsers[0] if @parsers == 1;

    my $parser = parser {
        my $input = shift;
        my ( $v, @values );
        for (@parsers) {
            ( $v, $input ) = $_->($input);
            push @values, $v if defined $v;   # assumes we wish to discard undef
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
    my @parsers = @_;
    return parser { return () }
      if @parsers == 0;
    return $parsers[0] if @parsers == 1;

    my $parser = parser {
        my $input = shift;
        my @failures;

        for (@parsers) {
            my ( $v, $newinput ) = eval { $_->($input) };
            if ($@) {
                die unless ref $@; # not a parser failure
                push @failures, $@;
            }
            else {
                return ( $v, $newinput );
            }
        }
        die [ 'ALT', $input, \@failures ];
    };
    {
        no warnings 'uninitialized';
        $N{$parser} = "(" . join ( " | ", map $N{$_}, @parsers ) . ")";
    }
    return $parser;
}

##############################################################################

=head3 list_of

  my $parser = list_of( $element, $separator );
  my ($parsed, $remainder) = $parser->($stream);

This function takes two parsers and returns a new parser which matches a
C<$separator> delimited list of C<$element> items.

=cut

sub list_of {
    my ( $element, $separator ) = @_;
    $separator = lookfor('COMMA') unless defined $separator;

    return T(
        concatenate( $element, star( concatenate( $separator, $element ) ) ),
        sub {
            my @matches = shift;
            if ( my $tail = shift ) {
                foreach my $match (@$tail) {
                    push @matches, @$match;
                }
            }
            return \@matches;
        }
    );
}

##############################################################################

=head3 rlist_of

  my $parser = list_of( $element, $separator );
  my ($parsed, $remainder) = $parser->($stream);

This function takes two parsers and returns a new parser which matches a
C<$separator> delimited list of C<$element> items.  Unlike C<list_of>, this
parser expects a leading C<$separator> in what it matches.

=cut

sub rlist_of {
    my ( $element, $separator ) = @_;
    $separator = lookfor('COMMA') unless defined $separator;

    return T( concatenate( $separator, list_of( $element, $separator ) ),
        sub { [ $_[0], @{ $_[1] } ] } );
}

##############################################################################

=head3 list_values_of

  my $parser = list_of( $element, $separator );
  my ($parsed, $remainder) = $parser->($stream);

This parser generator is the same as C<&list_of>, but it only returns the
elements, not the separators.

=cut

sub list_values_of {
    my ( $element, $separator ) = @_;
    $separator = lookfor('COMMA') unless defined $separator;

    return T(
        concatenate(
            $element, star( concatenate( absorb($separator), $element ) )
        ),
        sub {
            my @matches = shift;
            if ( my $tail = shift ) {
                foreach my $match (@$tail) {
                    push @matches, grep defined $_, @$match;
                }
            }
            return \@matches;
        }
    );
}

##############################################################################

=head3 rlist_values_of

  my $parser = list_of( $element, $separator );
  my ($parsed, $remainder) = $parser->($stream);

This parser generator is the same as C<&list_values_of>, but it only returns
the elements, not the separators.

List C<rlist_of>, it expects a separator at the beginning of the list.

=cut

sub rlist_values_of {
    my ( $element, $separator ) = @_;
    $separator = lookfor('COMMA') unless defined $separator;

    return T( concatenate( $separator, list_values_of( $element, $separator ) ),
        sub { $_[1] } );
}

##############################################################################

=head3 absorb

  my $parser = absorb( $parser );
  my ($parsed, $remainder) = $parser->($stream);

This special-purpose parser will allow you to match a given item but not
actually return anything.  This is very useful when matching commas in lists,
statement separators, etc.

=cut

sub absorb {
    my $parser = shift;
    return T( $parser, sub { () } );
}

##############################################################################

=head3 T

  my @result = T( $parser, \&transform );

Given a parser and a transformation sub, this function will apply the
tranformation to the values returned by the parser, if any.

=cut

sub T {
    my ( $parser, $transform ) = @_;
    return parser {
        my $input = shift;
        if ( my ( $value, $newinput ) = $parser->($input) ) {
            local $^W;    # using this to suppress 'uninitialized' warnings
            $value = [$value] if !ref $value;
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

##############################################################################

=head3 optional

 my $parser = optional($another_parser);
 my ($parser, $remainder) = $parser->(stream); 

This parser matches 0 or 1 of the given parser item.

=cut

sub optional {
    my $parser = shift;
    return alternate (
        T($parser, sub { [ shift ] }),
        \&null_list,
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

sub error {
    my ($try) = @_;
    return parser {
        my $input = shift;
        my @result = eval { $try->($input) };
        if ($@) {
            die ref $@ ? $@ : "Internal error ($@)";
        }
        return @result;
    };
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

my $error;

sub fetch_error {
    my ( $fail, $depth ) = @_;

    # clear the error unless it's a recursive call
    $error = '' if __PACKAGE__ ne caller;
    $depth ||= 0;
    my $I = "  " x $depth;
    return unless 'ARRAY' eq ref $fail; # XXX ?
    my ( $type, $position, $data ) = @$fail;
    my $pos_desc = "";

    while ( length($pos_desc) < 40 ) {
        if ($position) {
            my $h = head($position);
            $pos_desc .= "[@$h] ";
        }
        else {
            $pos_desc .= "End of input ";
            last;
        }
        $position = tail($position);
    }
    chop $pos_desc;
    $pos_desc .= "..." if defined $position;

    if ( $type eq 'TOKEN' ) {
        $error .= "${I}Wanted [@$data] instead of '$pos_desc'\n";
    }
    elsif ( $type eq 'End of input' ) {
        $error .= "${I}Wanted EOI instead of '$pos_desc'\n";
    }
    elsif ( $type eq 'ALT' ) {
        my $any = $depth ? "Or any" : "Any";
        $error .= "${I}$any of the following:\n";
        for (@$data) {
            fetch_error( $_, $depth + 1 );
        }
    }
    return $error;
}

1;

__END__

=head1 Copyright and License

This software is derived from code in the book "Higher Order Perl" by Mark
Jason Dominus. This software is licensed under the terms outlined in
L<Kinetic::HOP::License|Kinetic::HOP::License>.

