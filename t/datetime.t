#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 11;

BEGIN { use_ok 'Kinetic::DateTime' or die };

# Try now().
ok my $dt = Kinetic::DateTime->now, "Create now DateTime";
is $dt->time_zone->name, 'UTC', "Check time zone";

# Try new().
ok $dt = Kinetic::DateTime->new(
    year   => 1964,
    month  => 10,
    day    => 16,
    hour   => 16,
    minute => 12,
    second => 47,
), "Create new DateTime";

is $dt->time_zone->name, 'UTC', "Check time zone";
is $dt->year, 1964, "Check year";
is $dt->month, 10, "Check month";
is $dt->day, 16, "Check day";
is $dt->hour, 16, "Check hour";
is $dt->minute, 12, "Check minute";
is $dt->second, 47, "Check second";
