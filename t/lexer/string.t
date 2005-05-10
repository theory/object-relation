#!/usr/bin/perl
use warnings;
use strict;

use Test::More 'no_plan';

use lib 'lib/', '../lib/';
use Kinetic::Util::Stream 'drop';
BEGIN {
    use_ok 'Kinetic::Store::Lexer::String', qw/:all/ or die;
}

ok my $tokens = lex("name => 'foo'"),
    '... and we should be able to lex a basic string';

my $expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and it should return the correct tokens';

my $stream = lex_iterator("name => 'foo'");
my @tokens;
while (my $node = drop($stream)) {
    push @tokens => $node;
}
is_deeply \@tokens, $expected, 'Streams should also return the correct tokens';

is_deeply lex("3"), [['VALUE', 3]],
    'And we should be able to parse positive integers';

is_deeply lex("3.2"), [['VALUE', 3.2]],
    '... and numbers on either side of the decimal point';

is_deeply lex(".3"), [['VALUE', ".3"]],
    '... or after the decimal point';

is_deeply lex("3E5"), [['VALUE', "3E5"]],
    '... or scientific notation';

is_deeply lex("-3"), [['VALUE', -3]],
    'And we should be able to parse negative integers';

is_deeply lex("-3.2"), [['VALUE', -3.2]],
    '... and numbers on either side of the decimal point';

is_deeply lex("-.3"), [['VALUE', "-.3"]],
    '... or after the decimal point';

is_deeply lex("-3E5"), [['VALUE', "-3E5"]],
    '... or scientific notation';

is_deeply lex("."), ["."],
    '... but a standalone period should fail to lex';

is_deeply lex("object.name"), [['IDENTIFIER', 'object.name']],
    '... and should not be pulled out of an identifier';

ok $tokens = lex("name => undef"),
    'We should be able to lex an undef value';

$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'UNDEF',     'undef' ],
];

is_deeply $tokens, $expected,
    '... and it should return the correct tokens';

$tokens = lex("name => 'undef'");

$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'VALUE',     'undef' ],
];

is_deeply $tokens, $expected,
    '... but it should indentify "undef" as a value if it is quoted';

ok $tokens = lex("object.name => 'foo'"),
    'We should be able to lex identifiers with dots in the name';

$expected = [
  [ 'IDENTIFIER', 'object.name' ],
  [ 'COMMA',               '=>' ],
  [ 'VALUE',              'foo' ],
];
is_deeply $tokens, $expected,
    '... and get the correct results';

ok $tokens = lex("name => EQ 'foo'"),
    'We should be able to handle search keywords';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'KEYWORD',      'EQ' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and it should handle keywords correctly';

ok $tokens = lex("name => LIKE 'foo'"),
    '... and it should succeed if the string can be lexed';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'KEYWORD',    'LIKE' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and LIKE keywords and normal commas should be properly lexed';

ok $tokens = lex("name => LIKE 'foo', age => GT 3"),
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

ok $tokens = lex('name => NOT "foo"'), 'NOT should parse correctly';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'COMMA',        '=>' ],
  [ 'NEGATED',     'NOT' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and produce the correct tokens';

ok $tokens = lex("name => NOT ['foo', 'bar']"), 
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

ok $tokens = lex("name => NOT BETWEEN ['foo', 'bar']"), 
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

ok $tokens = lex(<<'END_SEARCH'), 'AND and parens should also parse';
    AND(
        desc => 'bar',
        this => NOT LIKE 'that',
    )
END_SEARCH
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
  [ 'SEPARATOR',     ',' ],
  [ 'RPAREN',        ')' ],
];
is_deeply $tokens, $expected, '... and we should allow trailing commas';

ok $tokens = lex(<<'END_SEARCH'), 'Stress testing the lexer should succeed';
    AND(
        last_name  => 'Wall',
        first_name => 'Larry',
    ),
    OR( bio => LIKE '%perl%'),
    OR(
      'one.type'  => LIKE 'email',
      'one.value' => LIKE '@cpan\.org$',
      'fav_number'    => GE 42
    )
END_SEARCH

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
  [ 'SEPARATOR',           ',' ],
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
  [ 'VALUE',        'one.type' ],
  [ 'COMMA',              '=>' ],
  [ 'KEYWORD',          'LIKE' ],
  [ 'VALUE',           'email' ],
  [ 'SEPARATOR',           ',' ],
  [ 'VALUE',       'one.value' ],
  [ 'COMMA',              '=>' ],
  [ 'KEYWORD',          'LIKE' ],
  [ 'VALUE',      '@cpan.org$' ],
  [ 'SEPARATOR',           ',' ],
  [ 'VALUE',      'fav_number' ],
  [ 'COMMA',              '=>' ],
  [ 'KEYWORD',            'GE' ],
  [ 'VALUE',              '42' ],
  [ 'RPAREN',              ')' ]
];
is_deeply $tokens, $expected, '... and still produce a valid list of tokens';
