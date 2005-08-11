#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;

use Test::More tests => 82;
#use Test::More 'no_plan';
use Test::Exception;

use lib 'lib', '../lib';

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store::Search';
use aliased 'Kinetic::DateTime::Incomplete';

use Kinetic::Store qw/:all/;
use Kinetic::Store::Lexer::String qw/string_lexer_stream/;
use Kinetic::Store::Lexer::Code   qw/code_lexer_stream/;

BEGIN {
    use_ok 'Kinetic::Store::Parser::DB', qw/parse/ or die;
}

my @tokens = (
    [ VALUE =>     3 ],
    [ FOO   => 'bar' ],
);

my $faux_stream = [
    [ VALUE => 7 ],
    sub { shift @tokens }
];

#*search_value = \&Kinetic::Store::Parser::DB::_search_value;
#diag Dumper (search_value($faux_stream)->());
#diag Dumper $faux_stream->();
#diag Dumper string_lexer_stream("name => 'bar'");

{
    package Faux::Store;
    our @ISA = 'Kinetic::Store';
    my %column;
    @column{qw/
        name 
        one__name 
        age 
        date
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

throws_ok { parse(string_lexer_stream("no_such_column => NOT 'foo'"), $store) }
    'Kinetic::Util::Exception::Fatal::Search',
    'Trying to string search on a non-existent column should throw an exception';

throws_ok { parse(code_lexer_stream([no_such_column => NOT 'foo']), $store) }
    'Kinetic::Util::Exception::Fatal::Search',
    'Trying to code search on a non-existent column should throw an exception';

throws_ok {parse(string_lexer_stream("name => 'foo', 'bar'"), $store)}
    'Kinetic::Util::Exception::Fatal::Search',
    'Unparseable string searches should throw an exception';

throws_ok {parse(code_lexer_stream([name => 'foo', 'bar']), $store)}
    'Kinetic::Util::Exception::Fatal::Search',
    'Unparseable code searches should throw an exception';

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

can_ok 'Kinetic::Store::Parser::DB', '_extract_statements';
my @statements = (1, [2, [3,[]]]);
my $statements = [Kinetic::Store::Parser::DB::_extract_statements(\@statements)];
is_deeply 
    $statements,
    [1,2,3],
    '... and it should return the correct items';

my $result = parse(string_lexer_stream("name => 'foo'"), $store);
ok $result, '... and string parsing basic searches should succeed';
is_deeply $result, [$name_search],
    '... and it should return the correct results';
$result = parse(code_lexer_stream([name => 'foo']), $store);
ok $result, '... and code parsing basic searches should succeed';
is_deeply $result, [$name_search],
    '... and it should return the correct results';

$result = parse(string_lexer_stream("name => NOT 'foo'"), $store);
$name_search->negated('NOT');
is_deeply $result, [$name_search],
    '... and strings should return the correct results, even if we negate it';

$result = parse(code_lexer_stream([name => NOT 'foo']), $store);
$name_search->negated('NOT');
is_deeply $result, [$name_search],
    '... and code should return the correct results, even if we negate it';

$result = parse(string_lexer_stream("name => EQ 'foo'"), $store);
ok $result, '... even if the string explicitly includes the EQ';
$name_search->negated('');
is_deeply $result, [$name_search],
    '... and it should return the correct results';

$result = parse(code_lexer_stream([name => EQ 'foo']), $store);
ok $result, '... even if the code explicitly includes the EQ';
is_deeply $result, [$name_search],
    '... and it should return the correct results';

$result = parse(string_lexer_stream("name => NOT EQ 'foo'"), $store);
$name_search->negated('NOT');
is_deeply $result, [$name_search],
    '... even if the string explicitly includes a negated EQ';

$result = parse(code_lexer_stream([name => NOT EQ 'foo']), $store);
is_deeply $result, [$name_search],
    '... even if the code explicitly includes a negated EQ';

$result = parse(string_lexer_stream("name => undef"), $store);
ok $result, 'Strings should be able to handle undef values';
$name_search->negated('');
$name_search->data(undef);
is_deeply $result, [$name_search],
    '... and should return the correct results';

$result = parse(code_lexer_stream([name => undef]), $store);
ok $result, 'Code should be able to handle undef values';
is_deeply $result, [$name_search],
    '... and should return the correct results';

$name_search->data('foo');
$result = parse(string_lexer_stream("name => BETWEEN ['bar', 'foo']"), $store);
ok $result, 'BETWEEN string searches should be parseable';
is_deeply $result, [$between_search],
    '... and return a BETWEEN search object';

$result = parse(string_lexer_stream("name => ['bar', 'foo']"), $store);
ok $result, '... even if BETWEEN is merely implied';
is_deeply $result, [$between_search],
    '... and return a BETWEEN search object';

$result = parse(string_lexer_stream("name => NOT BETWEEN ['bar', 'foo']"), $store);
ok $result, '... and NOT BETWEEN searches should parse';
$between_search->negated('NOT');
is_deeply $result, [$between_search],
    '... and return a negated BETWEEN search object';

$result = parse(string_lexer_stream("name => NOT ['bar', 'foo']"), $store);
ok $result, '... even if negated BETWEEN is merely implied';
is_deeply $result, [$between_search],
    '... and return a negated BETWEEN search object';

$between_search->negated('');
$result = parse(code_lexer_stream([name => BETWEEN ['bar', 'foo']]), $store);
ok $result, 'BETWEEN code searches should be parseable';
is_deeply $result, [$between_search],
    '... and return a BETWEEN search object';

$result = parse(code_lexer_stream([name => ['bar', 'foo']]), $store);
ok $result, '... even if BETWEEN is merely implied';
is_deeply $result, [$between_search],
    '... and return a BETWEEN search object';

$result = parse(code_lexer_stream([name => NOT BETWEEN ['bar', 'foo']]), $store);
ok $result, '... and NOT BETWEEN searches should parse';
$between_search->negated('NOT');
is_deeply $result, [$between_search],
    '... and return a negated BETWEEN search object';

$result = parse(code_lexer_stream([name => NOT ['bar', 'foo']]), $store);
ok $result, '... even if negated BETWEEN is merely implied';
is_deeply $result, [$between_search],
    '... and return a negated BETWEEN search object';

$result = parse(string_lexer_stream(<<'END_SEARCH'), $store);
    age  => NOT EQ 3, 
    name => EQ 'foo',
    name => NOT BETWEEN [ 'bar', "foo" ]
END_SEARCH
ok $result, 'Compound string searches should parse';
$name_search->negated('');
is_deeply $result, [$age_search, $name_search, $between_search],
    '... and return an appropriate list of search objects';

ok $result = parse(code_lexer_stream([
    age  => NOT EQ 3, 
    name => EQ 'foo',
    name => NOT BETWEEN [ 'bar', "foo" ]
]), $store), 'Compound code searches should parse';
$name_search->negated('');
is_deeply $result, [$age_search, $name_search, $between_search],
    '... and return an appropriate list of search objects';

$age_search->operator('GT');
$age_search->negated('');
ok $result = parse(string_lexer_stream("OR(name => 'foo', age => GT 3)"), $store),
    'Strings should be able to parse the OR group op';
is_deeply $result, [ 'OR', [$name_search, $age_search]],
    '... and have them correctly converted';

ok $result = parse(code_lexer_stream([OR(name => 'foo', age => GT 3)]), $store),
    'Code should be able to parse the OR group op';
is_deeply $result, [ 'OR', [$name_search, $age_search]],
    '... and have them correctly converted';

ok $result = parse(string_lexer_stream("AND(name => 'foo', age => GT 3)"), $store),
    'Strings should be able to parse the AND group op';
is_deeply $result, [ ['AND', $name_search, $age_search] ],
    '... and have them correctly converted';

ok $result = parse(code_lexer_stream([AND(name => 'foo', age => GT 3)]), $store),
    'Code should be able to parse the AND group op';
is_deeply $result, [ ['AND', $name_search, $age_search] ],
    '... and have them correctly converted';

ok $result = parse(
    string_lexer_stream("name => EQ 'foo', AND(name => 'foo', age => GT 3)"), 
    $store),
    'Strings should be able to parse the compound searches with group ops';
is_deeply $result, [ $name_search, ['AND', $name_search, $age_search]],
    '... and have them correctly converted';

ok $result = parse(
    code_lexer_stream([name => EQ 'foo', AND(name => 'foo', age => GT 3)]),
    $store),
    'Code should be able to parse the compound searches with group ops';
is_deeply $result, [ $name_search, ['AND', $name_search, $age_search]],
    '... and have them correctly converted';

$result = parse(
    string_lexer_stream(
        "name => EQ 'foo', 
        AND(name => 'foo', OR( name => 'foo'), age => GT 3)"
    ), $store),

my $expected = [
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
];
is_deeply $result, $expected, 'Parsing string recursive group ops should succeed';

$result = parse(code_lexer_stream([
    name => EQ 'foo', 
    AND(name => 'foo', OR( name => 'foo'), age => GT 3)
]), $store),
is_deeply $result, $expected, 'Parsing code recursive group ops should succeed';

my $any_search = Search->new(
    operator => 'ANY',
    negated  => '',
    data     => [qw/foo bar baz/],
    column   => 'name',
);

$result = parse(string_lexer_stream("name => ANY('foo', 'bar', 'baz')"), $store);
ok $result, 'ANY string searches should be parseable';
is_deeply $result, [$any_search],
    '... and return an ANY search object';

$result = parse(string_lexer_stream("name => ANY('foo', 'bar', 'baz',)"), $store);
is_deeply $result, [$any_search],
    '... even with a trailing comma';

$result = parse(code_lexer_stream([name => ANY('foo', 'bar', 'baz')]), $store);
ok $result, 'ANY code searches should be parseable';
is_deeply $result, [$any_search],
    '... and return an ANY search object';

$result = parse(code_lexer_stream([name => ANY('foo', 'bar', 'baz',)]), $store);
is_deeply $result, [$any_search],
    '... even with a trailing comma';

throws_ok {parse(string_lexer_stream("one => 3"), $store)}
    'Kinetic::Util::Exception::Fatal::Search',
    'String searching on embedded objects should fail';

$result = parse(string_lexer_stream("AND(name => 'foo', age => GT 3)"), $store);
ok $result, 'Strings should be able to parse AND tokens';

is_deeply $result, [['AND', $name_search, $age_search]],
    '... and have them correctly converted';

$result = parse(code_lexer_stream([AND(name => 'foo', age => GT 3)]), $store);
ok $result, 'Code should be able to parse AND tokens';

is_deeply $result, [['AND', $name_search, $age_search]],
    '... and have them correctly converted';

my $not_like_search = Search->new(
    operator => 'LIKE',
    negated  => 'NOT',
    data     => 'that',
    column   => 'this',
);
$result = parse(string_lexer_stream(<<'END_SEARCH'), $store);
    name => 'foo',
    AND(
        age => GT 3,
        this => NOT LIKE 'that',
    ),
END_SEARCH

$expected = [
    $name_search,
    [
        'AND',
        $age_search,
        $not_like_search,
    ]
];
is_deeply $result, $expected, 'Strings mixing standard and AND terms should succeed';

$result = parse(code_lexer_stream([
    name => 'foo',
    AND(
        age => GT 3,
        this => NOT LIKE 'that',
    ),
]), $store);
is_deeply $result, $expected, 'Code mixing standard and AND terms should succeed';

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
ok $result = parse(string_lexer_stream(<<'END_SEARCH'), $store), 'Complex string groupings of terms should succeed';
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

$expected = [
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

ok $result = parse(code_lexer_stream([
    AND(
        name   => 'foo',
        l_name => 'something',
    ),
    OR( age => GT 3),
    OR(
      one__type   => LIKE 'email',
      fav_number => GE 42
    )
]), $store), 'Complex code groupings of terms should succeed';
is_deeply $result, $expected, '... and should return the correct result';

$name_search->column('one__name');
$result = parse(string_lexer_stream("one.name => 'foo'"), $store);
ok $result, 'String parsing object delimited searches should succeed';
is_deeply $result, [$name_search],
    '... and return the correct results';

$result = parse(code_lexer_stream(['one.name' => 'foo']), $store);
ok $result, 'Code parsing object delimited searches should succeed';
is_deeply $result, [$name_search],
    '... and return the correct results';

my $y1968 = Incomplete->new(year => 1968);
my $y1966 = Incomplete->new(year => 1966);

my $search1968 = Search->new(
    operator => 'LT',
    negated  => '',
    data     => $y1968,
    column   => 'date',
);

my $search1966 = Search->new(
    operator => 'GT',
    negated  => '',
    data     => $y1966,
    column   => 'date',
);

my $search_like = Search->new(
    operator => 'LIKE',
    negated  => '',
    data     => '%vid',
    column   => 'name',
);
ok $result = parse(string_lexer_stream(<<'END_SEARCH'), $store), 'String LT/GT searches should be parseable';
    date => LT '1968-xx-xxTxx:xx:xx',
    date => GT '1966-xx-xxTxx:xx:xx',
    name => LIKE '%vid',
END_SEARCH

is_deeply $result, [$search1968, $search1966, $search_like], 
    '... and it should return the correct results';

ok $result = parse(code_lexer_stream([
    date => LT $y1968,
    date => GT $y1966,
    name => LIKE '%vid',
]), $store), 'Code LT/GT code should be parseable';

is_deeply $result, [$search1968, $search1966, $search_like], 
    '... and it should return the correct results';
