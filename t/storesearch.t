#!/usr/bin/perl -w

# $Id: storesearch.t 894 2004-12-04 02:48:49Z curtis $

use strict;
use Test::More tests => 44;
#use Test::More 'no_plan';
use Test::Exception;

my $CLASS;
BEGIN {
    $CLASS = 'Kinetic::Store::Search'; 
    use_ok $CLASS or die 
};

# Try now().

can_ok $CLASS, 'new';
ok my $search = $CLASS->new, "... and calling it should succeed";
isa_ok $search, $CLASS, "... and the object it returns";

throws_ok { $CLASS->new(foobar => 1, negated => 2, barfoo => 3)}
    qr/\QUnknown attributes to ${CLASS}::new (barfoo foobar)\E/,
    '... but it should die if unknown search attributes are specified';

foreach my $attribute (qw/attr data negated operator place_holder search_class/) {
    can_ok $search, $attribute;
    ok ! defined $search->$attribute, '... and its initial value should be undefined';
    ok $search->$attribute(scalar reverse $attribute),
        '... but setting it to a new value should succeed';
    is $search->$attribute, scalar(reverse $attribute),
        '... and now it should return the new value';
}

can_ok $search, 'search_method';
my %operators = (
    EQ      => '_EQ_SEARCH',
    NOT     => '_EQ_SEARCH',
    LIKE    => '_LIKE_SEARCH',
    MATCH   => '_MATCH_SEARCH', 
    BETWEEN => '_BETWEEN_SEARCH',
    GT      => '_GT_SEARCH',
    LT      => '_LT_SEARCH',
    GE      => '_GE_SEARCH',
    LE      => '_LE_SEARCH',
    NE      => '_EQ_SEARCH',
    ANY     => '_ANY_SEARCH',
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
