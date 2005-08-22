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

This package is not intended to be used directly, but is a support package
for custom lexers.  It is based on the Lexer.pm code from the book
"Higher Order Perl", by Mark Jason Dominus.

See L<Kinetic::Store::Lexer::String|Kinetic::Store::Lexer::String> for an
example.

All Kinetic lexers, regardless of what they are lexing, should produce output
compatible with this lexer.  This allows the Kinetic parsers to produce an
intermediate representation that is suitable for any data store regardless of
the source of the search request (XML, AJAX, code, etc.).

=cut

use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw/
    allinput
    blocks
    iterator_to_stream
    make_lexer
    tokens
/;
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use Kinetic::HOP::Stream 'node';

sub allinput {
    my $fh = shift;
    my @data = do { local $/; <$fh> };
    sub { return shift @data };
}

sub blocks {
    my $fh = shift;
    my $blocksize = shift || 8192;
    sub {
        return unless read $fh, my ($block), $blocksize;
        return $block;
    }
}

sub make_lexer {
    my $lexer = shift;
    while (@_) {
        my $args = shift;
        $lexer = tokens($lexer, @$args);
    }
    $lexer;
}

sub tokens {
    my ($input, $label, $pattern, $maketoken) = @_;
    $maketoken  ||= sub { [$_[1] => $_[0]] };
    my @tokens;
    my $buf = ""; # set to undef when input is exhausted
    my $split     = sub { split /($pattern)/ => $_[0] };

    return sub {
        while (0 == @tokens && defined $buf) {
            my $i = $input->();
            if (ref $i) { # input is a token
                my ($sep, $tok) = $split->($buf);
                $tok = $maketoken->($tok, $label) if defined $tok;
                push @tokens => grep defined && $_ ne "" => $sep, $tok, $i;
                $buf = "";
                last;
            }
            $buf .= $i if defined $i; # append new input to buffer
            my @newtoks = $split->($buf);
            while (@newtoks > 2 || @newtoks && ! defined $i) {
                # buffer contains complete separator plus combined token
                # OR we've reached the end of input
                push @tokens => shift @newtoks;
                push @tokens => $maketoken->(shift @newtoks, $label)
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

sub iterator_to_stream {
    my $it = shift;
    my $v  = $it->();
    return unless defined $v;
    node($v, sub { iterator_to_stream($it) } );
}

1;

__END__

=head1 Copyright and License

This software is derived from code in the book "Higher Order Perl" by Mark
Jason Dominus.  This software is licensed under the terms outlined in
L<Kinetic::HOP::License|Kinetic::HOP::License>.

=cut
