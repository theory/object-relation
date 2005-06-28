package Kinetic::Store::Lexer::String;

# $Id: String.pm 1364 2005-03-08 03:53:03Z curtis $

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

Kinetic::Store::Lexer::String - Lexer for Kinetic search strings

=head1 Synopsis

  use Kinetic::Store::Lexer::String qw/lexer_stream/;
  my $stream = lexer_stream(<<'END_QUERY'); 
    name => NOT LIKE 'foo%',
    OR (age => GE 21)
  END_QUERY

=head1 Description

This package will lex the data structure built by
L<Kinetic::Store|Kinetic::Store> search operators and return a data structure
that a Kinetic parser can parse.

See L<Kinetic::Parser::DB|Kinetic::Parser::DB> for an example.

=cut
use strict;
use warnings;
use Kinetic::Util::Exceptions qw/throw_search/;
use Kinetic::Util::Stream 'node';
use Kinetic::Store::Lexer ':all';
use Carp qw/croak/;

use Exporter::Tidy default => [qw/lexer_stream/];
use Regexp::Common;
use Text::ParseWords;

my $QUOTED = $RE{quoted};
my $NUM = $RE{num}{real};
my $VALUE  = qr/(?!\.(?!\d))(?:$QUOTED|$NUM)/;

my @TOKENS = (
    [ 
        'VALUE',                                   # value before keyword
        $VALUE, 
        sub {[$_[1], _strip_quotes($_[0])]} 
    ],
    [   'UNDEF',    'undef'                     ],
    [ 
        'KEYWORD',                                 # keyword before identifier
        qr/(?:LIKE|GT|LT|GE|LE|NE|MATCH|EQ)/ 
    ],
    [ 'BETWEEN',    'BETWEEN'                   ],
    [ 'AND',        'AND'                       ],
    [ 'OR',         'OR'                        ],
    [ 'ANY',        'ANY'                       ],
    [ 'NEGATED',    'NOT'                       ], # negated before identifier
    [ 'COMMA',      '=>'                        ],
    [ 'IDENTIFIER', qr/[[:alpha:]][.[:word:]]*/  ],
    [ 'WHITESPACE', qr/\s*/, sub {()}           ],
    [ 'SEPARATOR',  ','                         ],
    [ 'RBRACKET',   '\\]'                       ],
    [ 'LBRACKET',   '\\['                       ],
    [ 'RPAREN',     '\\)'                       ],
    [ 'LPAREN',     '\\('                       ],
);

sub _search_tokens { @TOKENS };

sub _lex {
    my @search = @_;
    my $lexer = make_lexer( sub { shift @search }, @TOKENS);
    my @tokens;
    while (my $token = $lexer->()) {
        push @tokens => $token;
    }
    return \@tokens;
}

sub _strip_quotes { # naive
    my $string = shift;
    $string =~ s/^(['"`])(.*)\1$/$2/;
    $string =~ s/\\\\/\\/g;
    $string =~ s/\\([^\/])/$1/g;
    return $string;
}

=head3 lexer_stream;

  my $stream = lexer_stream(\@search_parameters);

This function, exported on demand, is the only function publicly useful in this
module.  It takes search parameters as described in the
L<Kinetic::Store|Kinetic::Store> documents and returns a token stream that
Kinetic parsers should be able to turn into an intermediate representation.

=cut

sub lexer_stream {
    my @input = @_;
    my $input = sub { shift @input };
    return iterator_to_stream(make_lexer($input, _search_tokens()));
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
