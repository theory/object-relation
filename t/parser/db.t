#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;

use Test::More tests => 16;
#use Test::More 'no_plan';
use Test::Exception;

use lib 'lib';

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store::Search';

use Kinetic::Store qw/:all/;
use Kinetic::Store::Lexer::Code qw/lex/;

BEGIN {
    use_ok 'Kinetic::Store::Parser::DB', qw/parse/ or die;
}

{
    package Faux::Store;
    my %column;
    @column{qw/name one__name age this l_name one__type fav_number one__id/} = undef;

    sub new { bless {} => shift }

    sub _search_data_has_column {
        shift;
        return exists $column{+shift};
    }
}

my $store = Faux::Store->new;

throws_ok { parse(lex([no_such_column => NOT 'foo']), $store) }
    'Kinetic::Util::Exception::Fatal::Search',
    'Trying to search on a non-existent column should throw an exception';

my $name_foo_search = Search->new(
    operator => 'EQ',
    negated  => '',
    data     => 'foo',
    column   => 'name',
);
ok my $result = parse(lex([name => 'foo']), $store),
    '... and parsing a basic tokens should succeed';
is_deeply $result, [$name_foo_search],
    '... and it should return the correct results';

my $delimiter_search = Search->new(
    operator => 'EQ',
    negated  => '',
    data     => 3,
    column   => 'one__id',
);

sub Faux::Object::id { 3 }
my $foo = bless {} => 'Faux::Object';
ok $result = parse(lex([one => $foo]), $store),
    'Parsing tokens with segment delimiters should succeed';
is_deeply $result, [$delimiter_search],
    '... and it should return the correct results';

my $age_gt_search = Search->new(
    operator => 'GT',
    negated  => '',
    data     => 3,
    column   => 'age',
);
ok $result = parse(lex([name => 'foo', age => GT 3]), $store),
    'We should be able to parse multiple tokens';
is_deeply $result, [ $name_foo_search, $age_gt_search],
    '... and have them correctly converted';

ok $result = parse(lex([OR(name => 'foo', age => GT 3)]), $store),
    'We should be able to parse OR tokens';
is_deeply $result, [ 'OR', [$name_foo_search, $age_gt_search]],
    '... and have them correctly converted';

ok $result = parse(lex([AND(name => 'foo', age => GT 3)]), $store),
    'We should be able to parse AND tokens';

is_deeply $result, [['AND', $name_foo_search, $age_gt_search]],
    '... and have them correctly converted';

my $not_like_search = Search->new(
    operator => 'LIKE',
    negated  => 'NOT',
    data     => 'that',
    column   => 'this',
);
ok $result = parse(lex([
    name => 'foo',
    AND(
        age => GT 3,
        this => NOT LIKE 'that',
    ),
]), $store), 'Mixing standard and AND terms should succeed';
is_deeply $result,[
    $name_foo_search,
    [
        'AND',
        $age_gt_search,
        $not_like_search,
    ]
], '... and return the proper token';

my $lname = Search->new(
    operator => 'EQ',
    negated  => '',
    data     => 'something',
    column   => 'l_name',
);

my $one_type = Search->new(
    operator => 'LIKE',
    negated  => '',
    data     => 'email',
    column   => 'one__type',
);

my $fav_number = Search->new(
    operator => 'GE',
    negated  => '',
    data     => 42,
    column   => 'fav_number',
);
ok $result = parse(lex([
    AND(
        name  => 'foo',
        l_name => 'something',
    ),
    OR( age => GT 3),
    OR(
      'one.type'  => LIKE 'email',
      'fav_number'    => GE 42
    )
]), $store), 'Complex groupings of terms should succeed';

my $expected = [
    [
        'AND',
        $name_foo_search,
        $lname,
    ],
    'OR',
    [
        $age_gt_search,
    ],
    'OR',
    [
        $one_type,
        $fav_number,
    ]
];

is_deeply $result, $expected, '... and should return the correct result';


