#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use utf8;
use Test::More tests => 27;
#use Test::More 'no_plan';
use Test::Exception;
use File::Spec;
use Kinetic::Util::Iterator;

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
my $iter  = Kinetic::Util::Iterator->new(sub {shift @items});
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


@items = qw/foo bar baz/;
$iter  = Kinetic::Util::Iterator->new(sub {shift @items});
$coll  = $CLASS->new($iter);
# can_ok $coll, 'fill';
# $coll->next; # put us at the first item
# ok $coll->fill, '... and calling it should succeed';
# is $coll->curr, 'foo', '... but our position should not change';
__END__
ok( $coll = $CLASS->new, "Create new collection" );

isa_ok($coll, '$CLASS');
is( $coll->size, 0, "Check for no items" );
is( $coll->last_index, -1, "Check for negative last index" );

ok( $coll->add(@items), "Add items" );
is( $coll->size, 4, "Check for number of items" );
is( $coll->last_index, 3, "Check for last index" );

my $i = 0;
# Four tests.
while (my $item = $coll->next) {
    is($item, $items[$i], "Check that item $i is '$items[$i++]'" );
}

is( $coll->remove(3), 'four', "Remove last item" );
$i = 0;
# Three tests.
while (my $item = $coll->next) {
    is($item, $items[$i], "Check that item $i is '$items[$i++]'" );
}

$coll->clear; # Clear array.
is( $coll->size, 0, "Check that we're back to 0" );

my $ary = $coll->array;
push @$ary, 'one';
# Try using it as an array.
#is(scalar @$coll, 0, "Check that we get zero when accessing the tied array" );

#$coll->[0] = 'foo';

