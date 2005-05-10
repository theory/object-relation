#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;

#use Test::More tests => 16;
use Test::More 'no_plan';
use Test::Exception;

use lib 'lib', '../lib';

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store::Search';

use Kinetic::Store qw/:all/;
use Lexer::String qw/:all/;

BEGIN {
    use_ok 'Parser::DB', qw/parse/ or die;
}

{
    package Faux::Store;
    our @ISA = 'Kinetic::Store';
    my %column;
    @column{qw/
        name 
        one__name 
        age 
        this 
        l_name 
        one__type 
        fav_number 
        one__id
    /} = undef;

    sub new { bless {} => shift }

    sub _search_data_has_column {
        shift;
        return exists $column{+shift};
    }
}

my $store = Faux::Store->new;

throws_ok { parse(lex_iterator("no_such_column => NOT 'foo'"), $store) }
    'Kinetic::Util::Exception::Fatal::Search',
    'Trying to search on a non-existent column should throw an exception';

my $name_search = Search->new(
    operator => 'EQ',
    negated  => '',
    data     => 'foo',
    column   => 'name',
);

my $between_search = Search->new(
    operator => 'BETWEEN',
    negated  => '',
    data     => [qw/bar foo/],
    column   => 'name',
);

my $age_search = Search->new(
    operator => 'EQ',
    negated  => 'NOT',
    data     => 3,
    column   => 'age',
);

can_ok 'Parser::DB', '_extract_statements';
my @statements = (1, [2, [3,[]]]);
my $statements = [Parser::DB::_extract_statements(\@statements)];
is_deeply 
    $statements,
    [1,2,3],
    '... and it should return the correct items';

my ($result, $remainder) = parse(lex_iterator("name => 'foo'"), $store);
ok $result, '... and parsing basic searches should succeed';
is_deeply $result, [$name_search],
    '... and it should return the correct results';

($result, $remainder) = parse(lex_iterator("name => NOT 'foo'"), $store);
$name_search->negated('NOT');
is_deeply $result, [$name_search],
    '... and it should return the correct results, even if we negate it';

($result, $remainder) = parse(lex_iterator("name => EQ 'foo'"), $store);
ok $result, '... even if we explicitly include the EQ';
$name_search->negated('');
is_deeply $result, [$name_search],
    '... and it should return the correct results';

($result, $remainder) = parse(lex_iterator("name => NOT EQ 'foo'"), $store);
$name_search->negated('NOT');
is_deeply $result, [$name_search],
    '... even if we explicitly include a negated EQ';

($result, $remainder) = parse(lex_iterator("name => undef"), $store);
ok $result, 'We should be able to handle undef values';
$name_search->negated('');
$name_search->data(undef);
is_deeply $result, [$name_search],
    '... and it should return the correct results';
$name_search->data('foo');

($result, $remainder) = parse(lex_iterator("name => BETWEEN ['bar', 'foo']"), $store);
ok $result, 'BETWEEN searches should be parseable';
is_deeply $result, [$between_search],
    '... and return a BETWEEN search object';

($result, $remainder) = parse(lex_iterator("name => ['bar', 'foo']"), $store);
ok $result, '... even if BETWEEN is merely implied';
is_deeply $result, [$between_search],
    '... and return a BETWEEN search object';

($result, $remainder) = parse(lex_iterator("name => NOT BETWEEN ['bar', 'foo']"), $store);
ok $result, '... and NOT BETWEEN searches should parse';
$between_search->negated('NOT');
is_deeply $result, [$between_search],
    '... and return a negated BETWEEN search object';

($result, $remainder) = parse(lex_iterator("name => NOT ['bar', 'foo']"), $store);
ok $result, '... even if negated BETWEEN is merely implied';
is_deeply $result, [$between_search],
    '... and return a negated BETWEEN search object';

($result, $remainder) = parse(lex_iterator(<<'END_SEARCH'), $store);
    age  => NOT EQ 3, 
    name => EQ 'foo',
    name => NOT BETWEEN [ 'bar', "foo" ]
END_SEARCH
ok $result, 'Compound searches should parse';
$name_search->negated('');
is_deeply $result, [$age_search, $name_search, $between_search],
    '... and return an appropriate list of search objects';

$age_search->operator('GT');
$age_search->negated('');
($result, $remainder) = parse(lex_iterator("OR(name => 'foo', age => GT 3)"), $store),
ok $result, 'We should be able to parse the OR group op';
is_deeply $result, [ 'OR', [$name_search, $age_search]],
    '... and have them correctly converted';

($result, $remainder) = parse(lex_iterator("AND(name => 'foo', age => GT 3)"), $store),
ok $result, 'We should be able to parse the AND group op';
is_deeply $result, [ ['AND', $name_search, $age_search] ],
    '... and have them correctly converted';

($result, $remainder) = parse(
    lex_iterator("name => EQ 'foo', AND(name => 'foo', age => GT 3)"), 
    $store),
ok $result, 'We should be able to parse the compound searches with group ops';
is_deeply $result, [ $name_search, ['AND', $name_search, $age_search]],
    '... and have them correctly converted';

($result, $remainder) = parse(
    lex_iterator(
        "name => EQ 'foo', 
        AND(name => 'foo', OR( name => 'foo'), age => GT 3)"
    ), $store),

is_deeply $result,
    [
        $name_search,
        [ 
            'AND',
            $name_search,
            'OR',
            [
                $name_search,
            ],
            $age_search
        ]
    ], 'Recursive group ops should succeed';


my $any_search = Search->new(
    operator => 'ANY',
    negated  => '',
    data     => [qw/foo bar baz/],
    column   => 'name',
);

($result, $remainder) = parse(lex_iterator("name => ANY('foo', 'bar', 'baz')"), $store);
ok $result, 'ANY searches should be parseable';
is_deeply $result, [$any_search],
    '... and return an ANY search object';

($result, $remainder) = parse(lex_iterator("name => ANY('foo', 'bar', 'baz',)"), $store);
is_deeply $result, [$any_search],
    '... even with a trailing comma';

#$ENV{DEBUG} = 1;
throws_ok {parse(lex_iterator("one => 3"), $store)}
    'Kinetic::Util::Exception::Fatal::Search',
    'Searching on embedded objects should fail';

($result, $remainder) = parse(lex_iterator("AND(name => 'foo', age => GT 3)"), $store);
ok $result, 'We should be able to parse AND tokens';

is_deeply $result, [['AND', $name_search, $age_search]],
    '... and have them correctly converted';

my $not_like_search = Search->new(
    operator => 'LIKE',
    negated  => 'NOT',
    data     => 'that',
    column   => 'this',
);
($result, $remainder) = parse(lex_iterator(<<'END_SEARCH'), $store);
    name => 'foo',
    AND(
        age => GT 3,
        this => NOT LIKE 'that',
    ),
END_SEARCH

is_deeply $result,[
    $name_search,
    [
        'AND',
        $age_search,
        $not_like_search,
    ]
], 'Mixing standard and AND terms should succeed';

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
($result) = parse(lex_iterator(<<'END_SEARCH'), $store);
    AND(
        name   => 'foo',
        l_name => 'something',
    ),
    OR( age => GT 3),
    OR(
      one__type   => LIKE 'email',
      fav_number => GE 42
    )
END_SEARCH
ok $result, 'Complex groupings of terms should succeed';

my $expected = [
    [
        'AND',
        $name_search,
        $lname,
    ],
    'OR',
    [
        $age_search,
    ],
    'OR',
    [
        $one_type,
        $fav_number,
    ]
];

is_deeply $result, $expected, '... and should return the correct result';


($result, $remainder) = parse(lex_iterator("one.name => 'foo'"), $store);
ok $result, 'Parsing object delimited searches should succeed';
$name_search->column('one__name');
is_deeply $result, [$name_search],
    '... and return the correct results';
