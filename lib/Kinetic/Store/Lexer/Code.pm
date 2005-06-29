package Kinetic::Store::Lexer::Code;

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

Kinetic::Store::Lexer::Code - Lexer for Kinetic search code

=head1 Synopsis

  use Kinetic::Store::Lexer::Code qw/lexer_stream/;
  my $stream = lexer_stream([ 
    name => NOT LIKE 'foo%',
    OR (age => GE 21)
  ]);

=head1 Description

This package will lex the data structure built by
L<Kinetic::Store|Kinetic::Store> search operators and return a token stream
that a Kinetic parser can parse.

See L<Kinetic::Parser::DB|Kinetic::Parser::DB> for an example.

=cut

use strict;
use warnings;
use overload;
use Kinetic::Store qw/:all/;
use Kinetic::Util::Exceptions 'throw_search';
use Kinetic::Util::Stream 'node';

use Exporter::Tidy default => ['lexer_stream'];

##############################################################################

=head3 lexer_stream;

  my $stream = lexer_stream(\@search_parameters);

This function, exported on demand, is the only function publicly useful in this
module.  It takes search parameters as described in the
L<Kinetic::Store|Kinetic::Store> documents and returns a token stream that
Kinetic parsers should be able to turn into an intermediate representation.

=cut

sub lexer_stream {;
    my $tokens = _lex(shift);
    return _iterator_to_stream(sub { shift @$tokens });
}

sub _iterator_to_stream {
    my $it = shift;
    my $v  = $it->();
    return unless defined $v;
    node($v, sub { _iterator_to_stream($it) } );
}

my %term_types = (
    standard => sub {
        # name => 'foo'
        my ($column, $code) = @_;
        my $value = shift @$code;
        my @tokens = (['IDENTIFIER', $column], ['OP', '=>']);
        unless (ref $value) {
            push @tokens => defined $value
                ? ['VALUE',  $value] 
                : ['UNDEF', 'undef']; 
        }
        else {
            my $ref = ref $value;
            push @tokens =>
                  'CODE'  eq $ref ? $value->()
                : 'ARRAY' eq $ref ? BETWEEN($value)->()
                :                   [ 'VALUE', $value ];
        }
        return @tokens;
    },
    CODE => sub {
        my ($term) = @_;
        my ($op, $code) = $term->();
        my $op_token = [ KEYWORD => $op ];
        my $lparen   = [ 'OP',     '('  ];
        my $rparen   = [ 'OP',     ')'  ];
        return ($op_token, $lparen, @{_lex($code)}, $rparen);  # AND 
    },
);

sub _lex {
    my ($code) = @_;
    my @tokens;
    while (my $term = _normalize_key(shift @$code)) {
        my $type = ref $term || 'standard';
        if (my $make_token = $term_types{$type}) {
            push @tokens => $make_token->($term, $code);
        }
        else {
            throw_search [ 'I don\'t know how to lex a "[_1]"', $type ];
        }
        push @tokens => ['OP', ','] if @$code;
    }
    return \@tokens;
}

sub _normalize_key {
    my $term = shift;
    if ('ARRAY' eq ref $term) {
        my @body = @$term;
        $term = AND(@body);
    }
    return $term;
}

sub _normalize_value {
    my $term = shift;
    if ('ARRAY' eq ref $term) {
        my @body = @$term;
        $term = BETWEEN(\@body);
    }
    unless ('CODE' eq ref $term) {
        # we have to test if it's a CODE ref because they might 
        # have a stringified object here.
        $term = EQ $term;
    }
    return $term;
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
