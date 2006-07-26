#!/usr/bin/perl
use warnings;
use strict;

use Test::More tests => 41;
#use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.

use lib 'lib';
use HOP::Stream 'drop';
use aliased 'Object::Relation::DataType::DateTime::Incomplete';
BEGIN {
    use_ok 'Object::Relation::Handle', qw/:all/             or die;
    use_ok 'Object::Relation::Lexer::Code', qw/code_lexer_stream/ or die;
}

*lex = \&Object::Relation::Lexer::Code::_lex;

ok my $tokens = lex([name => 'foo']),
    '... and we should be able to lex a basic string';

my $expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and it should return the correct tokens';

my $stream = code_lexer_stream([name => 'foo']);
my @tokens;
while (my $node = drop($stream)) {
    push @tokens => $node;
}
is_deeply \@tokens, $expected, 'Streams should also return the correct tokens';

ok $tokens = lex(['some.name' => 'foo']),
    'We should be able to lex even if the identifier has a dot';

$expected = [
  [ 'IDENTIFIER', 'some.name' ],
  [ 'OP',                '=>' ],
  [ 'VALUE',            'foo' ],
];
is_deeply $tokens, $expected,
    '... and it should return the correct tokens';

ok $tokens = lex([name => undef]),
    'We should be able to lex an undef value';

$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'UNDEF',     'undef' ],
];

is_deeply $tokens, $expected,
    '... and it should return the correct tokens';

$tokens = lex([name => 'undef']);

$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'VALUE',     'undef' ],
];

is_deeply $tokens, $expected,
    '... but it should identify "undef" as a value if it is quoted';

ok $tokens = lex(['object.name' => 'foo']),
    'We should be able to lex identifiers with dots in the name';

$expected = [
  [ 'IDENTIFIER', 'object.name' ],
  [ 'OP',                  '=>' ],
  [ 'VALUE',              'foo' ],
];
is_deeply $tokens, $expected,
    '... and get the correct results';

ok $tokens = lex([name => EQ 'foo']),
    'We should be able to handle search keywords';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'COMPARE',      'EQ' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and it should handle keywords correctly';

ok $tokens = lex([name => LIKE 'foo']),
    '... and it should succeed if the string can be lexed';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'COMPARE',    'LIKE' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and LIKE keywords and normal commas should be properly lexed';

ok $tokens = lex([name => LIKE 'foo', age => GT 3]),
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

ok $tokens = lex([name => NOT "foo"]), 'NOT should parse correctly';
$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'KEYWORD',     'NOT' ],
  [ 'VALUE',       'foo' ],
];
is_deeply $tokens, $expected,
    '... and produce the correct tokens';

ok $tokens = lex([name => ['foo', 'bar']]), 
    'We should be able to parse bracketed lists';
$expected = [
  [ 'IDENTIFIER', 'name'     ],
  [ 'OP',           '=>'     ],
  [ 'KEYWORD',     'BETWEEN' ],
  [ 'OP',          '['       ],
  [ 'VALUE',       'foo'     ],
  [ 'OP',          ','       ],
  [ 'VALUE',       'bar'     ],
  [ 'OP',          ']'       ],
];
is_deeply $tokens, $expected, '... and get the correct tokens';

ok $tokens = lex([name => NOT ['foo', 'bar']]), 
    'We should be able to parse negated bracketed lists';
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

ok $tokens = lex([name => NOT BETWEEN ['foo', 'bar']]), 
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

ok $tokens = lex([
    AND(
        desc => 'bar',
        this => NOT LIKE 'that',
    )
]), 'AND and parens should also parse';
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
#  [ 'OP',     ',' ], it's not relevant to the parser, but the
#                            code lexer doesn't know that the comma is there
  [ 'OP',            ')' ],
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
  [ 'KEYWORD',           'AND' ],
  [ 'OP',                  '(' ],
  [ 'IDENTIFIER',  'last_name' ],
  [ 'OP',                 '=>' ],
  [ 'VALUE',            'Wall' ],
  [ 'OP',                  ',' ],
  [ 'IDENTIFIER', 'first_name' ],
  [ 'OP',                 '=>' ],
  [ 'VALUE',           'Larry' ],
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
  [ 'IDENTIFIER',   'one.type' ],
  [ 'OP',                 '=>' ],
  [ 'COMPARE',          'LIKE' ],
  [ 'VALUE',           'email' ],
  [ 'OP',                  ',' ],
  [ 'IDENTIFIER',  'one.value' ],
  [ 'OP',                 '=>' ],
  [ 'COMPARE',          'LIKE' ],
  [ 'VALUE',      '@cpan.org$' ],
  [ 'OP',                  ',' ],
  [ 'IDENTIFIER', 'fav_number' ],
  [ 'OP',                 '=>' ],
  [ 'COMPARE',            'GE' ],
  [ 'VALUE',              '42' ],
  [ 'OP',                  ')' ]
];
is_deeply $tokens, $expected, '... and still produce a valid list of tokens';

# the following searches will not work with the String lexer

{
    package Test::String;
    use overload '""' => \&to_string;
    sub new       { my ($pkg, $val) = @_; bless \$val => $pkg; }
    sub to_string { ${$_[0]} }
}

my $foo = Test::String->new('foo');
ok $tokens = lex([name => $foo]),
    'We should be able to lex an overloaded string';

$expected = [
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'VALUE',        $foo ],
];
is_deeply $tokens, $expected,
    '... and it should return the correct tokens';

ok $tokens = lex([name => ANY('foo', 'bar')]),
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

ok $tokens = lex([name => NOT ANY('foo', 'bar')]),
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

my $y1968 = Incomplete->new(year => 1968);
my $y1966 = Incomplete->new(year => 1966);

ok $tokens = lex([
    date => LT $y1968,
    date => GT $y1966,
    name => LIKE '%vid',
]), 'LT/GT code should be lexable';
$expected = [
  [ 'IDENTIFIER', 'date' ],
  [ 'OP',           '=>' ],
  [ 'COMPARE',      'LT' ],
  [ 'VALUE',      $y1968 ],
  [ 'OP',            ',' ],
  [ 'IDENTIFIER', 'date' ],
  [ 'OP',           '=>' ],
  [ 'COMPARE',      'GT' ],
  [ 'VALUE',      $y1966 ],
  [ 'OP',            ',' ],
  [ 'IDENTIFIER', 'name' ],
  [ 'OP',           '=>' ],
  [ 'COMPARE',    'LIKE' ],
  [ 'VALUE',      '%vid' ],
];
is_deeply $tokens, $expected, '... and it should return the correct tokens';

ok $tokens = lex([
    'person.uuid' => EQ '1234',
    date          => LT $y1968,
    name          => LIKE '%vid',
]), 'Fully-qualifed identifiers should be lexable';
$expected = [
  [ 'IDENTIFIER', 'person.uuid' ],
  [ 'OP',                  '=>' ],
  [ 'COMPARE',             'EQ' ],
  [ 'VALUE',             '1234' ],
  [ 'OP',                   ',' ],
  [ 'IDENTIFIER',        'date' ],
  [ 'OP',                  '=>' ],
  [ 'COMPARE',             'LT' ],
  [ 'VALUE',             $y1968 ],
  [ 'OP',                   ',' ],
  [ 'IDENTIFIER',        'name' ],
  [ 'OP',                  '=>' ],
  [ 'COMPARE',           'LIKE' ],
  [ 'VALUE',             '%vid' ],
];
is_deeply $tokens, $expected, '... and it should return the correct tokens';
