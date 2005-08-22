package Kinetic::Store::Lexer;

# $Id: Code.pm 1364 2005-03-08 03:53:03Z curtis $

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

=head1 Name

Kinetic::Store::Lexer - Lexer for Kinetic searches

=head1 Synopsis

  use Kinetic::Store::Lexer::Code qw/lexer_stream/;
  my $stream = lexer_stream([ 
    name => NOT LIKE 'foo%',
    OR (age => GE 21)
  ]);

=head1 Description

This package is not intended to be used directly, but is a support package
for custom lexers.  It is based on the Lexer.pm code from the book
"Higher Order Perl", by Mark-Jason Dominus.

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
    records
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
