#!/usr/bin/perl -w

# $Id$

use strict;
#use Test::More tests => 21;
use Test::More 'no_plan';

my $CLASS;
BEGIN { 
    $CLASS = 'Kinetic::DateTime';
    use_ok $CLASS or die;
};

# Try now().
can_ok $CLASS, 'now';
ok my $dt = Kinetic::DateTime->now, "Create now DateTime";
isa_ok $dt, $CLASS;
is $dt->time_zone->name, 'UTC', "Check time zone";

# Try new().
can_ok $CLASS, 'new';
ok $dt = Kinetic::DateTime->new(
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

can_ok $CLASS, 'new_from_iso8601';
ok my $dt2 = $CLASS->new_from_iso8601($dt->raw),
    'Create DateTime from iso8601 string';
isa_ok $dt2, $CLASS;
is_deeply $dt2, $dt, 'And it should be identical to an object created with new';
