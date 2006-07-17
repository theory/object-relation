#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 29;
#use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.

my $CLASS;
BEGIN {
    $CLASS = 'Kinetic::Store::DataType::DateTime';
    use_ok $CLASS, 'is_iso8601' or die;
};

# Try now().
can_ok $CLASS, 'now';
ok my $dt = Kinetic::Store::DataType::DateTime->now, "Create now DateTime";
isa_ok $dt, $CLASS;
is $dt->time_zone->name, 'UTC', "Check time zone";

# Try new().
can_ok $CLASS, 'new';
ok $dt = Kinetic::Store::DataType::DateTime->new(
    year   => 1964,
    month  => 10,
    day    => 16,
    hour   => 16,
    minute => 12,
    second => 47,
), "Create new DateTime";

isa_ok $dt, $CLASS;
is $dt->time_zone->name, 'UTC', "Check time zone";
is $dt->year, 1964, "Check year";
is $dt->month, 10, "Check month";
is $dt->day, 16, "Check day";
is $dt->hour, 16, "Check hour";
is $dt->minute, 12, "Check minute";
is $dt->second, 47, "Check second";

can_ok $dt, 'raw';
is $dt->raw, '1964-10-16T16:12:47', 'Check raw is iso8601 compliant';

can_ok $CLASS, 'parse_iso8601_date';
ok my $date = $CLASS->parse_iso8601_date('1964-10-16T17:12:47.0'),
    '... and we should be able to parse an iso8601 date';
my $expected_date = {
    year       => 1964,
    month      => 10,
    day        => 16,
    hour       => 17,
    minute     => 12,
    second     => 47,
    nanosecond => 0
};
is_deeply $date, $expected_date, '... and it should return the expected date parts';

can_ok $CLASS, 'bake';
ok my $dt2 = $CLASS->bake($dt->raw),
    'Create DateTime from iso8601 string';
isa_ok $dt2, $CLASS;
is_deeply $dt2, $dt, 'And it should be identical to an object created with new';

ok defined *is_iso8601{CODE}, 
    'is_iso8601() should be exported to our namespace';
ok is_iso8601('1964-10-16T17:12:47.0'),
    '... and it should identify ISO 8601 dates';
ok is_iso8601('1964-10-16T17:12:47'),
    '... even if we leave off the nanoseconds';
ok ! is_iso8601('1964-10-16 17:12:47'),
    '... but it will not match a non-iso date';
