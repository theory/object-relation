package Kinetic::Store::Lexer::Code;

# $Id$

=head1 Name

Kinetic::Store::Lexer::Code - Lexer for Kinetic search code

=head1 Synopsis

  use Kinetic::Store::Lexer::Code qw/code_lexer_stream/;
  my $stream = code_lexer_stream([
    name => NOT LIKE 'foo%',
    OR (age => GE 21)
  ]);

=head1 Description

This package lexes the data structure built by
L<Kinetic::Store::Handle|Kinetic::Store::Handle> search operators and return a token stream
that a Kinetic parser can parse.

See L<Kinetic::Parser::DB|Kinetic::Parser::DB> for an example.

=cut

use strict;
use warnings;

use version;
our $VERSION = version->new('0.0.2');

use overload;
use Kinetic::Store::Handle            qw/AND BETWEEN/;
use Kinetic::Util::Exceptions 'throw_search';
use HOP::Stream               'node';

use Exporter::Tidy            default => ['code_lexer_stream'];

##############################################################################

=head3 code_lexer_stream;

  my $stream = code_lexer_stream(\@search_parameters);

This function, exported on demand, is the only function publicly useful in
this module. It takes search parameters as described in the
L<Kinetic::Store::Handle|Kinetic::Store::Handle> documents and returns a token stream that
Kinetic parsers should be able to turn into an intermediate representation.

=cut

sub code_lexer_stream {;
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
            throw_search [ q{I don't know how to lex a "[_1]"}, $type ];
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

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
