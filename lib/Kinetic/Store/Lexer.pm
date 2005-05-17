package Kinetic::Store::Lexer;

use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw/
    allinput
    blocks
    iterator_to_stream
    make_lexer
    records
    tokens
/;
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use Stream 'node';

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
