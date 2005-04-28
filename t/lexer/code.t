#!/usr/bin/perl
use warnings;
use strict;

use Test::More tests => 77;
#use Test::More 'no_plan';

use lib 'lib';
BEGIN {
    use_ok 'Kinetic::Store', qw/:all/             or die;
    use_ok 'Kinetic::Store::Lexer::Code', qw/lex/ or die;
}

ok my $tokens = lex([name => 'foo']),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', '', 'EQ', 'foo' ]],
    '... and basic tokens should lex correctly';

ok my $term = EQ 'foo', 'EQ $value should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], [ '', 'EQ', 'foo'],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => EQ 'foo']),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', '', 'EQ', 'foo' ]],
    '... and EQ tokens should lex correctly';

ok $term = LIKE 'foo', 'LIKE $value should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], [ '', 'LIKE', 'foo'],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => LIKE 'foo']),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', '', 'LIKE', 'foo' ]],
    '... and LIKE tokens should lex correctly';
ok $term = GT 'foo', 'GT $value should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], ['', 'GT', 'foo'],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => GT 'foo']),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', '', 'GT', 'foo' ]],
    '... and GT tokens should lex correctly';

ok $term = LT 'foo', 'LT $value should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], ['', 'LT', 'foo'],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => LT 'foo']),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', '', 'LT', 'foo' ]],
    '... and LT tokens should lex correctly';

ok $term = GE 'foo', 'GE $value should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], ['', 'GE', 'foo'],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => GE 'foo']),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', '', 'GE', 'foo' ]],
    '... and GE tokens should lex correctly';

ok $term = LE 'foo', 'LE $value should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], ['', 'LE', 'foo'],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => LE 'foo']),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', '', 'LE', 'foo' ]],
    '... and LE tokens should lex correctly';

ok $term = NE 'foo', 'NE $value should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], ['', 'NE', 'foo'],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => NE 'foo']),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', '', 'NE', 'foo' ]],
    '... and NE tokens should lex correctly';

ok $term = MATCH 'foo', 'MATCH $value should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], ['', 'MATCH', 'foo'],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => MATCH 'foo']),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', '', 'MATCH', 'foo' ]],
    '... and MATCH tokens should lex correctly';

# and now for the tough stuff ...

ok $term = NOT 'foo', 'NOT $value should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], ['NOT', 'EQ', 'foo'],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => NOT 'foo']),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', 'NOT', 'EQ', 'foo' ]],
    '... and NOT tokens should lex correctly';

ok $term = NOT ['foo', 'bar'], 'NOT \@value should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], ['NOT', 'BETWEEN', ['foo', 'bar']],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => NOT ['foo', 'bar']]),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', 'NOT', 'BETWEEN', ['foo', 'bar'] ]],
    '... and NOT \@value tokens should lex correctly';

ok $term = NOT EQ 'foo', 'NOT EQ $value should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], ['NOT', 'EQ', 'foo'],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => NOT EQ 'foo']),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', 'NOT', 'EQ', 'foo' ]],
    '... and NOT EQ tokens should lex correctly';

ok $tokens = lex([ name => NOT LIKE 'bar%', count => GT 3]),
    'Compound terms should lex';
is_deeply $tokens, [
    [ qw/ name NOT LIKE bar% /],
    [ 'count', '', 'GT', 3 ]
], '... and return the correct tokens';


ok $term = EQ ['foo', 'bar'], 'EQ \@value should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], ['', 'BETWEEN', ['foo', 'bar']],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => ['foo', 'bar']]),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', '', 'BETWEEN', ['foo', 'bar'] ]],
    '... and EQ tokens should lex correctly';

ok $term = ANY('foo', 'bar', 'baz'), 'ANY(@values) should succeed';
isa_ok $term, 'CODE', '... and the result it returns';
is_deeply [$term->()], ['', 'ANY', ['foo', 'bar', 'baz']],
    '... and the subref should generate the proper token parts';
ok $tokens = lex([name => ANY('foo', 'bar', 'baz')]),
    '... and it should succeed if the token can be lexed';
is_deeply $tokens, [[ 'name', '', 'ANY', ['foo', 'bar', 'baz'] ]],
    '... and ANY tokens should lex correctly';

ok $tokens = lex([
    AND(
        desc => 'bar',
        this => NOT LIKE 'that',
    ),
]), 'Grouping terms like AND() should succeed';
is_deeply $tokens,[
    [
        'AND',
        ['desc', '', 'EQ', 'bar'],
        [qw/this NOT LIKE that/],
    ]
], '... and return the proper token';

ok $tokens = lex([
    name => 'foo',
    AND(
        desc => 'bar',
        this => NOT LIKE 'that',
    ),
]), 'Grouping terms like AND() should succeed';
is_deeply $tokens,[
    [ 'name', '', 'EQ', 'foo' ],
    [
        'AND',
        ['desc', '', 'EQ', 'bar'],
        [qw/this NOT LIKE that/],
    ]
], '... and return the proper token';

ok $tokens = lex([
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
]), 'Complex groupings of terms should succeed';

my $expected = [
     [
       'AND',
       [ 'last_name', '', 'EQ', 'Wall' ],
       [ 'first_name', '', 'EQ', 'Larry' ]
     ],
     'OR',
     [
       [ 'bio', '', 'LIKE', '%perl%' ]
     ],
     'OR',
     [
       [ 'one.type', '', 'LIKE', 'email' ],
       [ 'one.value', '', 'LIKE', '@cpan\\.org$' ],
       [ 'fav_number', '', 'GE', 42 ]
     ]
];

is_deeply $tokens, $expected, '... and should return the correct tokens';
