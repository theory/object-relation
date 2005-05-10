#!/usr/bin/perl
use warnings;
use strict;

#use Test::More tests => 77;
use Test::More 'no_plan';
use Data::Dumper;

use lib 'lib';
use Kinetic::Util::Stream 'drop';
BEGIN {
    use_ok 'Kinetic::Store', qw/:all/             or die;
    use_ok 'Kinetic::Store::Lexer::Code', qw/lex lex_iterator/ or die;
}


ok my $tokens = lex([name => 'foo']),
    '... and we should be able to lex a basic string';

my $expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and it should return the correct tokens';

my $stream = lex_iterator([name => 'foo']);
my @tokens;
while (my $node = drop($stream)) {
    push @tokens => $node;
}
is_deeply \@tokens, $expected, 'Streams should also return the correct tokens';
ok $tokens = lex([name => undef]),
    'We should be able to lex an undef value';

$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'UNDEF',     'undef' ],
];

is_deeply $tokens, $expected,
    '... and it should return the correct tokens';

$tokens = lex([name => 'undef']);

$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'VALUE',     'undef' ],
];

is_deeply $tokens, $expected,
    '... but it should indentify "undef" as a value if it is quoted';

ok $tokens = lex(['object.name' => 'foo']),
    'We should be able to lex identifiers with dots in the name';

$expected = [
  [ 'IDENTIFIER', 'object.name' ],
  [ 'COMMA',               '=>' ],
  [ 'VALUE',              'foo' ],
];
is_deeply $tokens, $expected,
    '... and get the correct results';

ok $tokens = lex([name => EQ 'foo']),
    'We should be able to handle search keywords';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'KEYWORD',      'EQ' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and it should handle keywords correctly';

ok $tokens = lex([name => LIKE 'foo']),
    '... and it should succeed if the string can be lexed';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'KEYWORD',    'LIKE' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and LIKE keywords and normal commas should be properly lexed';

ok $tokens = lex([name => LIKE 'foo', age => GT 3]),
    '... and it should succeed if the string can be lexed';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'KEYWORD',    'LIKE' ],
  [ 'VALUE',       'foo' ],
  [ 'SEPARATOR',     ',' ],
  [ 'IDENTIFIER',  'age' ],
  [ 'COMMA',        '=>' ],
  [ 'KEYWORD',      'GT' ],
  [ 'VALUE',           3 ],
];
is_deeply $tokens, $expected,
    'Compound searches should parse correctly';

ok $tokens = lex([name => NOT "foo"]), 'NOT should parse correctly';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'NEGATED',     'NOT' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and produce the correct tokens';

ok $tokens = lex([name => NOT ['foo', 'bar']]), 
    'We should be able to parse bracketed lists';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'NEGATED',     'NOT' ],
  [ 'LBRACKET',    '['   ],
  [ 'VALUE',       'foo' ],
  [ 'SEPARATOR',   ','   ],
  [ 'VALUE',       'bar' ],
  [ 'RBRACKET',    ']'   ],
];
is_deeply $tokens, $expected, '... and get the correct tokens';

ok $tokens = lex([name => NOT BETWEEN ['foo', 'bar']]), 
    'We should be able to parse bracketed lists';
$expected = [
  [ 'IDENTIFIER', 'name'     ],
  [ 'COMMA',        '=>'     ],
  [ 'NEGATED',     'NOT'     ],
  [ 'BETWEEN',     'BETWEEN' ],
  [ 'LBRACKET',    '['       ],
  [ 'VALUE',       'foo'     ],
  [ 'SEPARATOR',   ','       ],
  [ 'VALUE',       'bar'     ],
  [ 'RBRACKET',    ']'       ],
];
is_deeply $tokens, $expected, '... and get the correct tokens';

ok $tokens = lex([
    AND(
        desc => 'bar',
        this => NOT LIKE 'that',
    )
]), 'AND and parens should also parse';
$expected = [
  [ 'AND',         'AND' ],
  [ 'LPAREN',        '(' ],
  [ 'IDENTIFIER', 'desc' ],
  [ 'COMMA',        '=>' ],
  [ 'VALUE',       'bar' ],
  [ 'SEPARATOR',     ',' ],
  [ 'IDENTIFIER', 'this' ],
  [ 'COMMA',        '=>' ],
  [ 'NEGATED',     'NOT' ],
  [ 'KEYWORD',    'LIKE' ],
  [ 'VALUE',      'that' ],
#  [ 'SEPARATOR',     ',' ], it's not relevant to the parser, but the
#                            code lexer doesn't know that the comma is there
  [ 'RPAREN',        ')' ],
];
is_deeply $tokens, $expected, '... and we should allow trailing commas';

ok $tokens = lex([
    AND(
        last_name  => 'Wall',
        first_name => 'Larry',
    ),
    OR( bio => LIKE '%perl%'),
    OR(
      'one.type'   => LIKE 'email',
      'one.value'  => LIKE '@cpan.org$',
      'fav_number' => GE 42
    )
]), 'Stress testing the lexer should succeed';

$expected = [
  [ 'AND',               'AND' ],
  [ 'LPAREN',              '(' ],
  [ 'IDENTIFIER',  'last_name' ],
  [ 'COMMA',              '=>' ],
  [ 'VALUE',            'Wall' ],
  [ 'SEPARATOR',           ',' ],
  [ 'IDENTIFIER', 'first_name' ],
  [ 'COMMA',              '=>' ],
  [ 'VALUE',           'Larry' ],
  [ 'RPAREN',              ')' ],
  [ 'SEPARATOR',           ',' ],
  [ 'OR',                 'OR' ],
  [ 'LPAREN',              '(' ],
  [ 'IDENTIFIER',        'bio' ],
  [ 'COMMA',              '=>' ],
  [ 'KEYWORD',          'LIKE' ],
  [ 'VALUE',          '%perl%' ],
  [ 'RPAREN',              ')' ],
  [ 'SEPARATOR',           ',' ],
  [ 'OR',                 'OR' ],
  [ 'LPAREN',              '(' ],
  [ 'IDENTIFIER',   'one.type' ],
  [ 'COMMA',              '=>' ],
  [ 'KEYWORD',          'LIKE' ],
  [ 'VALUE',           'email' ],
  [ 'SEPARATOR',           ',' ],
  [ 'IDENTIFIER',  'one.value' ],
  [ 'COMMA',              '=>' ],
  [ 'KEYWORD',          'LIKE' ],
  [ 'VALUE',      '@cpan.org$' ],
  [ 'SEPARATOR',           ',' ],
  [ 'IDENTIFIER', 'fav_number' ],
  [ 'COMMA',              '=>' ],
  [ 'KEYWORD',            'GE' ],
  [ 'VALUE',              '42' ],
  [ 'RPAREN',              ')' ]
];
is_deeply $tokens, $expected, '... and still produce a valid list of tokens';
