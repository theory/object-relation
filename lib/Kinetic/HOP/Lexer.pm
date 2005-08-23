package Kinetic::HOP::Lexer;

# $Id: Code.pm 1364 2005-03-08 03:53:03Z curtis $

=head1 Name

Kinetic::HOP::Lexer - Lexer for Kinetic searches

=head1 Synopsis

  use Kinetic::Store::Lexer::Code qw/code_lexer_stream/;
  my $stream = code_lexer_stream([ 
    name => NOT LIKE 'foo%',
    OR (age => GE 21)
  ]);

=head1 Description

This package is not intended to be used directly, but is a support package for
custom lexers. It is based on the Lexer.pm code from the book "Higher Order
Perl", by Mark Jason Dominus.

See L<Kinetic::Store::Lexer::String|Kinetic::Store::Lexer::String> for an
example.

All Kinetic lexers, regardless of what they are lexing, should produce output
compatible with this lexer. This allows the Kinetic parsers to produce an
intermediate representation that is suitable for any data store regardless of
the source of the search request (XML, AJAX, code, etc.).

=cut

use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK   = qw/ make_lexer /;
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use Kinetic::HOP::Stream 'node';

##############################################################################

=head3 make_lexer

 my $lexer = make_lexer( $input_iterator, @tokens );  

The C<make_lexer> function expects an input data iterator as the first
argument and a series of tokens as subsequent arguments. It returns a stream
of lexed tokens. The output tokens are two element arrays:

 [ $label, $matched_text ]


The iterator should be a subroutine reference that returns the next value
merely by calling the subroutine with no arguments.

The input C<@tokens> array passed into C<make_lexer> is expected to be a list
of array references with two mandatory items and one optional one:

 [ $label, qr/$match/, &transform ]

=over 4

=item * C<$label>

The C<$label> is the name used for the first item in an output token.

=item * C<$match>

The C<$match> is either an exact string or regular expression which matches
the text the label is to identify.

=item * C<&transform>

The C<&transform> subroutine reference is optional. If supplied, this will
take the matched text and should return a token matching an output token or
an empty list if the token is to be discarded. For example, to discard
whitespace (the label is actually irrelevant, but it helps to document the
code):

 [ 'WHITESPACE', /\s+/, sub {()} ]

The two arguments supplied to the transformation subroutine are the label and
value. Thus, if we wish to force all non-negative integers to have a unary
plus, we might do something like this:

 [ 
   'REVERSED INT',  # the label
   /[+-]?\d+/,      # integers with an optional unary plus or minus
   sub { 
     my ($label, $value) = @_;
     $value = "+$value" unless $value =~ /^[-+]/;
     [ $label, $value ]
   } 
 ]

=back

For example, let's say we want to convert the string "x = 3 + 4" to the
following tokens:

  [ 'VAR', 'x' ]
  [ 'OP',  '=' ]
  [ 'NUM', 3   ]
  [ 'OP',  '+' ]
  [ 'NUM', 4   ]

One way to do this would be with the following code:

  my $text = 'x = 3 + 4';
  my @text = ($text);
  my $iter = sub { shift @text };
  
  my @input_tokens = (
      [ 'VAR',   qr/[[:alpha:]]+/    ],
      [ 'NUM',   qr/\d+/             ],
      [ 'OP',    qr/[+=]/            ],
      [ 'SPACE', qr/\s*/, sub { () } ],
  );
  
  my $lexer = make_lexer( $iter, @input_tokens );
  
  my @tokens;
  while ( my $token = $lexer->() ) {
      push @tokens, $token;
  }

C<@tokens> would contain the desired tokens.

Note that the order in which the input tokens are passed in might cause input
to be lexed in different ways, thus the order is significant (C</\w+/> might
slurp up numbers before C</\b\d+\b/> can read them).

=cut

sub make_lexer {
    my $lexer = shift;
    while (@_) {
        my $args = shift;
        $lexer = _tokens( $lexer, @$args );
    }
    return $lexer;
}

sub _tokens {
    my ( $input, $label, $pattern, $maketoken ) = @_;
    $maketoken ||= sub { [ $_[0] => $_[1] ] };
    my @tokens;
    my $buf = "";    # set to undef when input is exhausted
    my $split = sub { split /($pattern)/ => $_[0] };

    return sub {
        while ( 0 == @tokens && defined $buf ) {
            my $i = $input->();
            if ( ref $i ) {    # input is a token
                my ( $sep, $tok ) = $split->($buf);
                $tok = $maketoken->( $label, $tok ) if defined $tok;
                push @tokens => grep defined && $_ ne "" => $sep, $tok, $i;
                $buf = "";
                last;
            }
            $buf .= $i if defined $i;    # append new input to buffer
            my @newtoks = $split->($buf);
            while ( @newtoks > 2 || @newtoks && !defined $i ) {

                # buffer contains complete separator plus combined token
                # OR we've reached the end of input
                push @tokens => shift @newtoks;
                push @tokens => $maketoken->( $label, shift @newtoks )
                  if @newtoks;
            }

            # reassemble remaining contents of buffer
            $buf = join "" => @newtoks;
            undef $buf unless defined $i;
            @tokens = grep $_ ne "" => @tokens;
        }
        $_[0] = '' unless defined $_[0];
        return 'peek' eq $_[0] ? $tokens[0] : shift @tokens;
    };
}

1;

__END__

=head1 Copyright and License

This software is derived from code in the book "Higher Order Perl" by Mark
Jason Dominus. This software is licensed under the terms outlined in
L<Kinetic::HOP::License|Kinetic::HOP::License>.

=cut
