#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 57;
#use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.
use Test::Exception;

use aliased 'Kinetic::Store::DataType::DateTime::Incomplete';
my $CLASS;
BEGIN {
    $CLASS = 'Kinetic::Store::Search';
    use_ok $CLASS or die
};

{
    package Faux::Class;
    sub new { bless {}, shift }
    sub key { 'faux' }
}

can_ok $CLASS, 'new';
ok my $search = $CLASS->new(class => Faux::Class->new),
  '... and calling it should succeed';
isa_ok $search, $CLASS, '... and the object it returns';

throws_ok { $CLASS->new(foobar => 1, negated => 2, barfoo => 3)}
    'Kinetic::Store::Exception::Fatal::Search',
    '... but it should die if unknown search attributes are specified';

foreach my $attribute (qw/param negated operator class/) {
    can_ok $search, $attribute;
    if ($attribute eq 'class') {
        isa_ok $search->$attribute, 'Faux::Class',
            '... and the class object should be set';
    }
    else {
        ok ! defined $search->$attribute,
            '... and its initial value should be undefined';
    }
    ok $search->$attribute(scalar reverse $attribute),
        '... but setting it to a new value should succeed';
    if ('column' eq $attribute) {
        is $search->$attribute, 'faux.' . scalar(reverse $attribute),
            '... and now it should return the new value';
    }
    else {
        is $search->$attribute, scalar(reverse $attribute),
            '... and now it should return the new value';
    }
}

can_ok $search, 'data';
$search->operator('cthulhu');
my $operator = $search->operator;
ok ! defined $search->data, '... and its initial value should be undef';
ok $search->data('phooey'), '... but settting it to a new value should succeed';
is $search->data, 'phooey', '... and it should now return the new value';
is $search->operator, $operator,
    '... and if operator was defined, it should not change if data is set';

$search->operator(undef);
$search->data([qw/some info/]);
is $search->operator, 'BETWEEN',
    'Setting data() to an aref when operator is undef sets operator to BETWEEN';

$search->operator(undef);
$search->data('something other than an arrray ref');
is $search->operator, 'EQ',
    '... otherwise, an undef operator should be switched to EQ';

$search->operator(0);
$search->data([qw/some info/]);
is $search->operator, 'BETWEEN',
    'Setting data() to an aref when operator is false sets operator to BETWEEN';

$search->operator('');
$search->data('something other than an arrray ref');
is $search->operator, 'EQ',
    '... otherwise, an undef operator should be switched to EQ';
can_ok $search, 'search_method';
my %operators = (
    EQ      => '_EQ_SEARCH',
    NOT     => '_EQ_SEARCH',
    LIKE    => '_LIKE_SEARCH',
    MATCH   => '_MATCH_SEARCH',
    GT      => '_GT_LT_SEARCH',
    LT      => '_GT_LT_SEARCH',
    GE      => '_GT_LT_SEARCH',
    LE      => '_GT_LT_SEARCH',
    NE      => '_EQ_SEARCH',
);
while (my ($operator, $method) = each %operators) {
    $search->operator($operator);
    is $search->search_method, $method,
        "... and it should return the correct method for $operator searches";
}

$search->data(undef);
foreach my $operator (qw/EQ NOT NE/) {
    $search->operator($operator);
    is $search->search_method, '_NULL_SEARCH',
        "$operator should default to a _NULL_SEARCH if the search value is undef";
}

$search->data(Incomplete->now);
foreach my $operator (qw/EQ NOT NE/) {
    $search->operator($operator);
    is $search->search_method, '_date_handler',
        "$operator should default to a _EQ_INCOMPLETE_DATE_SEARCH if the search value is an incomplete date";
}

$search->operator('BETWEEN');
$search->data('foobar');
throws_ok {$search->search_method}
    'Kinetic::Store::Exception::Fatal::Panic',
    'BETWEEN searches without an arrayref for the data should panic';

$search->data([1]),
throws_ok {$search->search_method}
    'Kinetic::Store::Exception::Fatal::Search',
    '... and the should die if there is only one term in the array ref';

$search->data([1, 2, 3]),
throws_ok {$search->search_method}
    'Kinetic::Store::Exception::Fatal::Search',
    '... or if there are more than two terms.';

$search->data([ [] => {} ]);
throws_ok {$search->search_method}
    'Kinetic::Store::Exception::Fatal::Search',
    '... of if the ref types of the two terms do not match';

$search->data([1 => 2]);
is $search->search_method, '_BETWEEN_SEARCH',
    'A BETWEEN search with most arguments should default to the _BETWEEN_SEARCH method';

$search->data([Incomplete->now => Incomplete->now]);
is $search->search_method, '_date_handler',
    '... and with incomplete date arguments should default to the correct method';

$search->operator('ANY');
$search->data('foobar');
throws_ok {$search->search_method}
    'Kinetic::Store::Exception::Fatal::Panic',
    'ANY searches without an arrayref for the data should panic';

$search->data([ [], {}, 1 ]);
throws_ok {$search->search_method}
    'Kinetic::Store::Exception::Fatal::Search',
    '... of if the ref types of the terms do not match';

$search->data([1 => 2]);
is $search->search_method, '_ANY_SEARCH',
    'An ANY search with most arguments should default to the _ANY_SEARCH method';

$search->data([Incomplete->now => Incomplete->now]);
is $search->search_method, '_date_handler',
    '... and with incomplete date arguments should default to the correct method';
