#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use utf8;
use Test::More tests => 83;
#use Test::More 'no_plan';
use Test::Exception;
use File::Spec;
use aliased 'Kinetic::Util::Iterator';

my $CLASS;
BEGIN {
    $CLASS = 'Kinetic::Util::Collection';
    use_ok $CLASS or die;
}

can_ok $CLASS, 'new';
throws_ok {$CLASS->new}
    qr/Argument “.*” is not a valid Kinetic::Util::Iterator object/,
    '... and calling it without an argument should die';

throws_ok {$CLASS->new(sub{})}
    qr/Argument “.*” is not a valid Kinetic::Util::Iterator object/,
    '... and as should calling with without a proper iterator object';

my @items = qw/fee fie foe fum/;
my $iter  = Iterator->new(sub {shift @items});
ok my $coll = $CLASS->new($iter),
  'Calling new() with a valid iterator object should succeed';
isa_ok $coll, $CLASS => '... and the object it returns';

can_ok $coll, 'next';
is $coll->next, 'fee',
  '... and it should return the correct value (fee)';
is $coll->next, 'fie',
  '... and it should return the correct value (fie)';
is $coll->next, 'foe',
  '... and it should return the correct value (foe)';
is $coll->next, 'fum',
  '... and it should return the correct value (fum)';
ok ! defined $coll->next,
  '... but when we get to the end it should return undef';

can_ok $coll, 'curr';
is $coll->curr, 'fum',
  '... and it should return the current value the collection is pointing to.';

can_ok $coll, 'prev';
is $coll->prev, 'foe',
  '... and it should return the previous value in the collection.';
is $coll->curr, 'foe',
  '... and curr() should also point to that value';
is $coll->prev, 'fie',
  '... and we should still be able to fetch the previous value in the collection';
is $coll->prev, 'fee',
  '... all the way back to the first';
ok ! defined $coll->prev,
  '... but before the beginning, there was nothing.';
is $coll->curr, 'fee',
  '... and curr() should still point to the correct item';
is $coll->next, 'fie',
  '... and next() should behave appropriately';
is $coll->curr, 'fie',
  '... and stress testing curr() should still work';
is $coll->next, 'foe',
  '... and we should be able to keep walking forward';
is $coll->next, 'fum',
  '... until the last position';
ok ! defined $coll->next,
  '... but there exists nothing after the end';
is $coll->curr, 'fum',
  '... and curr() *still* works :)';


@items = qw/zero one two three four five six/;
$iter  = Iterator->new(sub {shift @items});
$coll  = $CLASS->new($iter);
can_ok $coll, 'get';
$coll->next; # kick it up one
is $coll->get(4), 'four', '... and it should return the item at the appropriate index';
is $coll->curr, 'zero', '... but this should not affect the "current" item';

is $coll->get(1), 'one', '... and we should be able to get an earlier index';
is $coll->curr, 'zero', '... and this still should not affect the current item';

can_ok $coll, 'set';
$coll->set(3, 'trois');
is $coll->get(3), 'trois', '... and we should be able to set items to new values';
is $coll->curr, 'zero', '... but this should not affect the position of the collection';

can_ok $coll, 'index';
@items = qw/zero one two three four five six/;
$iter = Iterator->new( sub {shift @items});
$coll = $CLASS->new($iter);
ok ! defined $coll->index, '... and it should return undef if the collection is not pointing at anything.';
for ( 0 .. 6 ) {
    $coll->next;
    is $coll->index, $_, '... and it should return the correct index for subsequent items';
}
$coll->next;
is $coll->index, 6, '... but it should never return a number greater than the number of items';
for (reverse 0 .. 5) {
    $coll->prev;
    is $coll->index, $_, '... and it should return the correct index for previous items';
}
$coll->prev;
is $coll->index, 0, '... even if we try to move before the beginning of the list';

can_ok $CLASS, 'from_list';
ok $coll = $CLASS->from_list(qw/zero un deux trois quatre/), '... and calling it should succeed';
isa_ok $coll, $CLASS, '... and the object it returns';
foreach (qw/zero un deux trois quatre/) {
    is $coll->next, $_, '... and it should return the correct items';
}

$coll = $CLASS->from_list(qw/zero un deux trois quatre/);
can_ok $coll, 'reset';
$coll->next for 0 .. 3;
$coll->reset;
ok ! defined $coll->index, '... and it should reset the collection';
is $coll->next, 'zero', '... and the collection should behave like a new collection';

$coll = $CLASS->from_list(qw/zero un deux trois quatre/);
can_ok $coll, 'size';
is $coll->size, 5, '... and it should return the number of items in the collection';

$coll = $CLASS->from_list(qw/zero un deux trois quatre/);
can_ok $coll, 'clear';
$coll->next;
$coll->next;
$coll->clear;
is $coll->size, 0, '... and the size of a cleared collection should be zero';
ok ! defined $coll->index, '... and index() should return undef';
ok ! defined $coll->next, '... and next() should return undef';
ok ! defined $coll->index, '... and index() should still return undef';

$coll = $CLASS->from_list(qw/zero un deux trois quatre/);
can_ok $coll, 'all';
@items = $coll->all;
is_deeply \@items, [qw/zero un deux trois quatre/],
    '... and it should return a list of all items in the collection';
is_deeply scalar $coll->all, [qw/zero un deux trois quatre/],
    '... and it should return an array ref of all items in scalar context';

$coll = $CLASS->from_list(qw/zero un deux trois quatre cinq/);
can_ok $coll, 'splice';
@items = $coll->splice;
ok ! @items, '... and calling it with no arguments should produce no results';
@items = $coll->splice(4);
is_deeply \@items, [qw/quatre cinq/], '... and it should behave just like splice';
is_deeply scalar $coll->all, [qw/zero un deux trois/],
    '... and the collection should have the correct remaining elements';
@items = $coll->splice(1,1);
is_deeply \@items, [qw/un/], '... and the two argument splice should behave correctly';
is_deeply scalar $coll->all, [qw/zero deux trois/], '... and leave the correct elements';
@items = $coll->splice(1,1,qw/1 2/);
is_deeply \@items, ['deux'], '... and the three argument splice should behave correctly';
is_deeply scalar $coll->all, [qw/zero 1 2 trois/],
    '... and the collection should have the correct elements remaining';

$coll = $CLASS->from_list(qw/zero un deux trois quatre cinq/);
can_ok $coll, 'do';
@items = ();
my $sub = sub {
    return if 'quatre' eq $_[0];
    push @items => shift;
};
$coll->do($sub);
is_deeply \@items, [qw/zero un deux trois/],
    '... and it should call the sub correctly';
