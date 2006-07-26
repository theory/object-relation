#!/usr/bin/perl
use warnings;
use strict;

use Test::More tests => 45;
#use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.
use Test::Exception;

use lib 'lib/', '../lib/';
use HOP::Stream 'drop';

BEGIN {
    use_ok 'Object::Relation::Lexer::String', qw/string_lexer_stream/ or die;
}

*lex = \&Object::Relation::Lexer::String::_lex;

throws_ok { lex("name ~~ 'foo'") }
  'Object::Relation::Exception::Fatal::Search',
  'A malformed search request should throw an exception';

ok my $tokens = lex("name => 'foo'"),
    '... and we should be able to lex a basic string';

my $expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and it should return the correct tokens';

my $stream = string_lexer_stream("name => 'foo'");
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

throws_ok { lex(".") }
  'Object::Relation::Exception::Fatal::Search',
  '... but a standalone period should fail to lex';

is_deeply lex("object.name"), [['IDENTIFIER', 'object.name']],
    '... and should not be pulled out of an identifier';

ok $tokens = lex("name => undef"),
    'We should be able to lex an undef value';

$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'UNDEF',     'undef' ],
];

is_deeply $tokens, $expected,
    '... and it should return the correct tokens';

$tokens = lex("name => 'undef'");

$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'VALUE',     'undef' ],
];

is_deeply $tokens, $expected,
    '... but it should indentify "undef" as a value if it is quoted';

ok $tokens = lex("object.name => 'foo'"),
    'We should be able to lex identifiers with dots in the name';

$expected = [
  [ 'IDENTIFIER', 'object.name' ],
  [ 'OP',                  '=>' ],
  [ 'VALUE',              'foo' ],
];
is_deeply $tokens, $expected,
    '... and get the correct results';

ok $tokens = lex("name => EQ 'foo'"),
    'We should be able to handle search keywords';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'COMPARE',      'EQ' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and it should handle keywords correctly';

ok $tokens = lex("name => LIKE 'foo'"),
    '... and it should succeed if the string can be lexed';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'COMPARE',    'LIKE' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and LIKE keywords and normal commas should be properly lexed';

ok $tokens = lex("name => LIKE 'foo', age => GT 3"),
    '... and it should succeed if the string can be lexed';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'COMPARE',    'LIKE' ],
  [ 'VALUE',       'foo' ],
  [ 'OP',            ',' ],
  [ 'IDENTIFIER',  'age' ],
  [ 'OP',           '=>' ],
  [ 'COMPARE',      'GT' ],
  [ 'VALUE',           3 ],
];
is_deeply $tokens, $expected,
    'Compound searches should parse correctly';

ok $tokens = lex('name => NOT "foo"'), 'NOT should parse correctly';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'KEYWORD',     'NOT' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and produce the correct tokens';

ok $tokens = lex("name => NOT ['foo', 'bar']"), 
    'We should be able to parse bracketed lists';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'KEYWORD',     'NOT' ],
  [ 'OP',          '['   ],
  [ 'VALUE',       'foo' ],
  [ 'OP',          ','   ],
  [ 'VALUE',       'bar' ],
  [ 'OP',          ']'   ],
];
is_deeply $tokens, $expected, '... and get the correct tokens';

ok $tokens = lex("name => NOT BETWEEN ['foo', 'bar']"), 
    'We should be able to parse bracketed lists';
$expected = [
  [ 'IDENTIFIER', 'name'     ],
  [ 'OP',           '=>'     ],
  [ 'KEYWORD',     'NOT'     ],
  [ 'KEYWORD',     'BETWEEN' ],
  [ 'OP',          '['       ],
  [ 'VALUE',       'foo'     ],
  [ 'OP',          ','       ],
  [ 'VALUE',       'bar'     ],
  [ 'OP',          ']'       ],
];
is_deeply $tokens, $expected, '... and get the correct tokens';

ok $tokens = lex(<<'END_SEARCH'), 'AND and parens should also parse';
    AND(
        desc => 'bar',
        this => NOT LIKE 'that',
    )
END_SEARCH
$expected = [
  [ 'KEYWORD',     'AND' ],
  [ 'OP',            '(' ],
  [ 'IDENTIFIER', 'desc' ],
  [ 'OP',           '=>' ],
  [ 'VALUE',       'bar' ],
  [ 'OP',            ',' ],
  [ 'IDENTIFIER', 'this' ],
  [ 'OP',           '=>' ],
  [ 'KEYWORD',     'NOT' ],
  [ 'COMPARE',    'LIKE' ],
  [ 'VALUE',      'that' ],
  [ 'OP',            ',' ],
  [ 'OP',            ')' ],
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
  [ 'KEYWORD',           'AND' ],
  [ 'OP',                  '(' ],
  [ 'IDENTIFIER',  'last_name' ],
  [ 'OP',                 '=>' ],
  [ 'VALUE',            'Wall' ],
  [ 'OP',                  ',' ],
  [ 'IDENTIFIER', 'first_name' ],
  [ 'OP',                 '=>' ],
  [ 'VALUE',           'Larry' ],
  [ 'OP',                  ',' ],
  [ 'OP',                  ')' ],
  [ 'OP',                  ',' ],
  [ 'KEYWORD',            'OR' ],
  [ 'OP',                  '(' ],
  [ 'IDENTIFIER',        'bio' ],
  [ 'OP',                 '=>' ],
  [ 'COMPARE',          'LIKE' ],
  [ 'VALUE',          '%perl%' ],
  [ 'OP',                  ')' ],
  [ 'OP',                  ',' ],
  [ 'KEYWORD',            'OR' ],
  [ 'OP',                  '(' ],
  [ 'VALUE',        'one.type' ],
  [ 'OP',                 '=>' ],
  [ 'COMPARE',          'LIKE' ],
  [ 'VALUE',           'email' ],
  [ 'OP',                  ',' ],
  [ 'VALUE',       'one.value' ],
  [ 'OP',                 '=>' ],
  [ 'COMPARE',          'LIKE' ],
  [ 'VALUE',      '@cpan.org$' ],
  [ 'OP',                  ',' ],
  [ 'VALUE',      'fav_number' ],
  [ 'OP',                 '=>' ],
  [ 'COMPARE',            'GE' ],
  [ 'VALUE',              '42' ],
  [ 'OP',                  ')' ]
];
is_deeply $tokens, $expected, '... and still produce a valid list of tokens';

ok $tokens = lex("name => ANY('foo', 'bar')"),
    'We should be able to parse ANY grous';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'KEYWORD',     'ANY' ],
  [ 'OP',          '('   ],
  [ 'VALUE',       'foo' ],
  [ 'OP',          ','   ],
  [ 'VALUE',       'bar' ],
  [ 'OP',          ')'   ],
];
is_deeply $tokens, $expected, '... and get the correct tokens';

ok $tokens = lex("name => NOT ANY('foo', 'bar')"),
    '... and parse negated ANY groups';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'KEYWORD',     'NOT' ],
  [ 'KEYWORD',     'ANY' ],
  [ 'OP',          '('   ],
  [ 'VALUE',       'foo' ],
  [ 'OP',          ','   ],
  [ 'VALUE',       'bar' ],
  [ 'OP',          ')'   ],
];
is_deeply $tokens, $expected, '... and still get the correct tokens';

ok $tokens = lex('date => "xxxx-06-xxTxx:xx:xx"'),
    'We should be able to properly parse incomplete datetime strings';
$expected = [
  [ 'IDENTIFIER',           'date' ],
  [ 'OP',                     '=>' ],
  [ 'VALUE', 'xxxx-06-xxTxx:xx:xx' ],
];

is_deeply $tokens, $expected, '... and get the correct tokens';

ok $tokens = lex('person.uuid => "1234"'),
    'Fully-qualifed identifiers should be lexable';
$expected = [
  [ 'IDENTIFIER', 'person.uuid' ],
  [ 'OP',                  '=>' ],
  [ 'VALUE',             '1234' ],
];

is_deeply $tokens, $expected, '... and get the correct tokens';

