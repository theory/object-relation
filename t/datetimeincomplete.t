#!/usr/bin/perl -w

# $Id: datetime.t 894 2004-12-04 02:48:49Z curtis $

use strict;
use Test::More tests => 24;
#use Test::More 'no_plan';

my $CLASS;
BEGIN {
    $CLASS = 'Kinetic::DateTime::Incomplete'; 
    use_ok $CLASS or die 
};

# Try now().

can_ok $CLASS, 'now';
ok my $date = $CLASS->now, "Create now DateTime";
is $date->time_zone->name, 'UTC', "Check time zone";

# Try new().
can_ok $CLASS, 'new';
ok $date = $CLASS->new(
    year   => 1964,
    month  => 10,
    day    => 16,
    hour   => 16,
    minute => 12,
    second => 47,
), "Create new DateTime";

is $date->time_zone->name, 'UTC', "Check time zone";
is $date->year, 1964, "Check year";
is $date->month, 10, "Check month";
is $date->day, 16, "Check day";
is $date->hour, 16, "Check hour";
is $date->minute, 12, "Check minute";
is $date->second, 47, "Check second";

ok $date = $CLASS->new(
    month => 7,
    day   => 14
), 'Declaring Bastille Day should work correctly';
foreach my $segment (qw/year hour minute second/) {
    ok ! defined $date->$segment, "... $segment should not be defined if it wasn't declared";
}
is $date->month, 7, '... but the month should be correct';
is $date->day, 14, '... as should the day';

can_ok $date, 'contiguous';
ok $date->contiguous, '... and dates with all components contiguous should succeed';
ok ! $CLASS->new->contiguous, '... but if no components are defined, its not contiguous';
ok ! $CLASS->new(year => 1997, day => 3)->contiguous,
    '... nor should contiguous() return true if the date components are not contiguous';
