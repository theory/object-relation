#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use utf8;

use Test::More tests => 186;
#use Test::More 'no_plan';
use Test::NoWarnings;    # Adds an extra test.
use Test::Exception;
use File::Spec;
use aliased 'Object::Relation::Iterator';

FAUX: {

    package Faux;
    use Object::Relation::Functions qw(:uuid);

    sub new {
        my ( $class, $name ) = @_;
        bless {
            uuid => undef,
            name => $name,
            uuid => create_uuid(),
        }, $class;
    }

    sub id   { shift->{uuid} }
    sub name { shift->{name} }
    sub uuid { shift->{uuid} }
    sub save { shift }
}

my $CLASS;

BEGIN {
    $CLASS = 'Object::Relation::Collection';
    use_ok $CLASS or die;
}

can_ok $CLASS, 'new';
throws_ok { $CLASS->new }
  qr/Argument “.*” is not a valid Object::Relation::Iterator object/,
  '... and calling it without an argument should die';

throws_ok { $CLASS->new({ iter => sub { } }) }
  qr/Argument “.*” is not a valid Object::Relation::Iterator object/,
  '... and as should calling with without a proper iterator object';

#
# A collection of unsaved objects (they don't yet have UUIDs)
#

my @items = map { Faux->new($_) } qw/fee fie foe fum/;
my @copy  = @items;
my $iter  = Iterator->new( sub { shift @copy } );
ok my $coll = $CLASS->new( { iter => $iter } ),
  'Calling new() with a valid collection object should succeed';
isa_ok $coll, $CLASS => '... and the object it returns';

can_ok $coll, 'package';
ok !defined $coll->package,
  '... and the collection package should be undefined for untyped collections';

can_ok $coll, 'next';
is $coll->next->name, 'fee',
  '... and it should return the correct value (fee)';
is $coll->next->name, 'fie',
  '... and it should return the correct value (fie)';
is $coll->next->name, 'foe',
  '... and it should return the correct value (foe)';
is $coll->next->name, 'fum',
  '... and it should return the correct value (fum)';
ok !defined $coll->next,
  '... but when we get to the end it should return undef';

#
# A collection of saved objects (they do have UUIDs)
#

$_->save foreach @items;

$iter = Iterator->new( sub { shift @items } );
ok $coll = $CLASS->new( { iter => $iter } ),
  'Calling new() with saved objects should succeed';
isa_ok $coll, $CLASS => '... and the object it returns';

ok !defined $coll->package,
  '... and the collection package should be undefined for untyped collections';

is $coll->next->name, 'fee',
  '... and it should return the correct value (fee)';
is $coll->next->name, 'fie',
  '... and it should return the correct value (fie)';
is $coll->next->name, 'foe',
  '... and it should return the correct value (foe)';
is $coll->next->name, 'fum',
  '... and it should return the correct value (fum)';
ok !defined $coll->next,
  '... but when we get to the end it should return undef';

#
# A wee bit more internals testing.
#

ok my $array = $coll->_array, '... and we should be the AsHash object';
my @keys = $array->keys;
my $ouuid = OSSP::uuid->new;
is scalar( grep { $ouuid->import(str => $_) } @keys ), scalar(@keys),
  '... and all of the keys should match a UUID';

can_ok $coll, 'curr';
is $coll->curr->name, 'fum',
  '... and it should return the current value the collection is pointing to.';

#
# Now let's walk backwards through the collection
#

can_ok $coll, 'prev';
is $coll->prev->name, 'foe',
  '... and it should return the previous value in the collection.';
is $coll->curr->name, 'foe', '... and curr() should also point to that value';
is $coll->prev->name, 'fie',
  '... and we should still be able to fetch the previous value in the collection';
is $coll->prev->name, 'fee', '... all the way back to the first';
ok !defined $coll->prev, '... but before the beginning, there was nothing.';
is $coll->curr->name, 'fee',
  '... and curr() should still point to the correct item';
is $coll->next->name, 'fie', '... and next() should behave appropriately';
is $coll->curr->name, 'fie',
  '... and stress testing curr() should still work';
is $coll->next->name, 'foe',
  '... and we should be able to keep walking forward';
is $coll->next->name, 'fum', '... until the last position';
ok !defined $coll->next, '... but there exists nothing after the end';
is $coll->curr->name, 'fum', '... and curr() *still* works :)';

#
# Let's get items by index
#

@items = map { Faux->new($_)->save } qw/zero one two three four five six/;
$iter = Iterator->new( sub { shift @items } );
$coll = $CLASS->new( { iter => $iter } );
can_ok $coll, 'get';
$coll->next;    # kick it up one
is $coll->get(4)->name, 'four',
  '... and it should return the item at the appropriate index';
is $coll->curr->name, 'zero',
  '... but this should not affect the "current" item';

is $coll->get(1)->name, 'one',
  '... and we should be able to get an earlier index';
is $coll->curr->name, 'zero',
  '... and this still should not affect the current item';

ok !$coll->is_assigned, 'is_assigned() should be false';
can_ok $coll, 'set';
ok $coll->set( 3, Faux->new('trois') ), 'Set item 4';
ok $coll->is_assigned, 'And now is_assigned() should be true';
is $coll->get(3)->name, 'trois',
  '... and we should be able to set items to new values';
is $coll->curr->name, 'zero',
  '... but this should not affect the position of the collection';

can_ok $coll, 'index';
@items = map { Faux->new($_) } qw/zero one two three four five six/;
$iter = Iterator->new( sub { shift @items } );
$coll = $CLASS->new( { iter => $iter } );
ok !defined $coll->index,
  '... and it should return undef if the collection is not pointing at anything.';
for ( 0 .. 6 ) {
    $coll->next;
    is $coll->index, $_,
      '... and it should return the correct index for subsequent items';
}
$coll->next;
is $coll->index, 6,
  '... but it should never return a number greater than the number of items';
for ( reverse 0 .. 5 ) {
    $coll->prev;
    is $coll->index, $_,
      '... and it should return the correct index for previous items';
}
$coll->prev;
is $coll->index, 0,
  '... even if we try to move before the beginning of the list';

can_ok $CLASS, 'from_list';
ok $coll = $CLASS->from_list(
    { list => [ map { Faux->new($_) } qw/zero un deux trois quatre/ ] } ),
  '... and calling it should succeed';
isa_ok $coll, $CLASS, '... and the object it returns';
foreach (qw/zero un deux trois quatre/) {
    is $coll->next->name, $_, '... and it should return the correct items';
}

$coll = $CLASS->from_list(
    { list => [ map { Faux->new($_) } qw/zero un deux trois quatre/ ] } );
can_ok $coll, 'reset';
$coll->next for 0 .. 3;
$coll->reset;
ok !defined $coll->index, '... and it should reset the collection';
is $coll->next->name, 'zero',
  '... and the collection should behave like a new collection';

$coll = $CLASS->from_list(
    { list => [ map { Faux->new($_) } qw/zero un deux trois quatre/ ] } );
can_ok $coll, 'size';
is $coll->size, 5,
  '... and it should return the number of items in the collection';

$coll = $CLASS->from_list(
    { list => [ map { Faux->new($_) } qw/zero un deux trois quatre/ ] } );
can_ok $coll, 'clear';
$coll->next;
$coll->next;
$coll->clear;
is $coll->size, 0, '... and the size of a cleared collection should be zero';
ok !defined $coll->index, '... and index() should return undef';
ok !defined $coll->next,  '... and next() should return undef';
ok !defined $coll->index, '... and index() should still return undef';

$coll = $CLASS->from_list(
    { list => [ map { Faux->new($_) } qw/zero un deux trois quatre/ ] } );
can_ok $coll, 'all';
@items = map { $_->name } $coll->all;
is_deeply \@items, [qw/zero un deux trois quatre/],
  '... and it should return a list of all items in the collection';
my $all = $coll->all;
$_ = $_->name foreach @$all;
is_deeply $all, [qw/zero un deux trois quatre/],
  '... and it should return an array ref of all items in scalar context';

$coll = $CLASS->from_list(
    { list => [ map { Faux->new($_) } qw/zero un deux trois quatre cinq/ ] }
);
can_ok $coll, 'do';
@items = ();
my $sub = sub {
    my $item = shift;
    return if 'quatre' eq $item->name;
    push @items => $item->name;
};
$coll->do($sub);
is_deeply \@items, [qw/zero un deux trois/],
  '... and it should call the sub correctly';

can_ok $CLASS, 'empty';
ok $coll = $CLASS->empty, '... and calling it should succeed';
isa_ok $coll, $CLASS, '... and the object it returns';
my @all = $coll->all;
ok !@all, '... and the collection should be empty';

#
# testing primitives
#
my @list = ( 1 .. 4 );
ok $coll = $CLASS->from_list( { list => \@list } ),
  'We should be able to create a collection of integers';
is $coll->next, 1, '... and we should be able to get the next() value';
is_deeply [ $coll->all ], [ 1 .. 4 ],
  '... and it should contain the correct integers';
is $coll->next, 1, '... and generally just behave like a normal collection';
is $coll->next, 2, '... and generally just behave like a normal collection';

ok $coll = $CLASS->from_list( { list => [1,1] } ),
    'Create a collection with duplicate items';
is $coll->size, 1, 'The size should reflect the removal of the dupes';

#
# Testing add().
#

@list = map { Faux->new($_) } qw/zero un deux trois quatre/;
ok $coll = $CLASS->new({ iter => Iterator->new( sub { shift @list }) }),
    'Create a new collection with five objects';

my @add = map { Faux->new($_) } qw/cinq six sept/;
can_ok $coll, 'add', 'added';
ok $coll->add(@add), 'Add some items to the collection';
is_deeply scalar $coll->added, \@add, 'added() should return the added items';

push @add, map { Faux->new($_) } qw/huit neuf/;
ok $coll->add(@add[3..4]), 'Add some more items to the collection';
is scalar @list, 5, 'The list should still be five items long';
is_deeply scalar $coll->added, \@add,
    'added() should return the all of the added items';

my $faux = Faux->new('dix');
ok $coll->set(0, $faux), 'Set the first item to a new object';
is scalar $coll->added, undef, 'added() should now return undef';

is $coll->get(0), $faux, 'The first item should be the one we set';
is $coll->get(5), $add[0], 'The sixth item should be the first added';

is $coll->size, 10, 'The size of the collection should be 10';
is $coll->get(5), $add[0], 'The sixth item should be the first added';
ok $coll->add($add[0]), 'Add a pre-existing item to the collection';
is $coll->size, 10, 'The size of the collection should still be 10';

ok $coll = $CLASS->empty, 'Create a new empty collection';
ok $coll->add(@add), 'Add some items to it';
ok $coll->set(0, $faux), 'Set the first item to a different value';
is $coll->added, undef, 'added() should now return undef';
ok $coll->add(@add), 'Add all of the items again';
is $coll->size, 5, 'The size should be five';
is_deeply scalar $coll->all, [$faux, @add[1..4]],
    'The items should be as expected';
@list = map { Faux->new($_) } qw/zero un deux trois quatre/;
ok $coll->add(@list), 'Add more items';
is $coll->size, 10, 'There should now be ten items in the collection';

#
# Testing remove()
#
can_ok $coll, qw(remove removed);
ok $coll->remove($add[1]), 'Remove an object';
is $coll->size, 9, 'The size should now be nine';

@list = map { Faux->new($_) } qw/zero un deux trois quatre/;
ok $coll = $CLASS->new({ iter => Iterator->new( sub { shift @list }) }),
    'Create a new collection with five objects';
ok $coll->add(@add), 'Add some items';
ok $coll->remove($add[1]), 'Delete an item';
is_deeply scalar $coll->removed, [$add[1]],
    'removed() should return the removed item';
ok $coll->add($add[1]), 'Add the item again';
ok !$coll->is_assigned, 'is_assigned() should still be false';
is $coll->get(9), $add[1], 'The last item should be the added item';
is $coll->size, 10, 'The collection should have ten items';
ok $coll->remove(@add), 'Remove the added items';
is_deeply [ sort $coll->removed ], [ sort @add ],
    'removed() should return all of the removed items';
is $coll->size, 5, 'The collection should now have five items';
ok $coll->set(2, $add[1]), 'Set the third item to a new value';
is $coll->get(2), $add[1], 'The third item should be the new value';
ok $coll->is_assigned, 'is_assigned() should now be true';
is $coll->added, undef, 'added() should return undef';
is $coll->removed, undef, 'reemoved() should also return undef';
ok $coll->add($add[1]), 'Add a pre-existing item to the collection';
is $coll->size, 5, 'The size of the collection should still be 5';

#
# Testing assign()
#
ok $coll = $CLASS->from_list({ list => \@list }),
    'Create a new collection from_list()';
can_ok $coll, 'assign', 'is_assigned';
ok $coll->is_assigned, 'is_assigned() should return true';

ok $coll = $CLASS->empty, 'Create a new empty collection';
ok !$coll->is_assigned, 'is_assigned() should return false';

ok $coll->assign(@add), 'Assign all new values';
ok $coll->is_assigned, 'The assigned boolean should be true';
is $coll->size, 5, 'The collection should now contain five objects';
is $coll->index, undef, 'The index should be undefined';
is $coll->added, undef, 'added() should be undefined';
is $coll->get(0), $add[0], 'The first assigned value should be at 0';
is_deeply scalar $coll->all, \@add,
    'all() should return all of the assigned items';
ok $coll->assign(@add, @add), 'Assign with duplicate items';
is $coll->size, 5, 'The size should reflect removal of the dupes';
is_deeply scalar $coll->all, \@add,
    'all() should return all of the assigned items';

#
# Testing clear()
#
@list = map { Faux->new($_) } qw/zero un deux trois quatre/;
ok $coll = $CLASS->new({ iter => Iterator->new( sub { shift @list } ) }),
    'Create a new collection';
can_ok $coll, qw(clear is_cleared);
is $coll->size, 5,       'The collection should have five items';
ok !$coll->is_cleared,   'is_cleared() should return false';
ok $coll->add($faux),    'Add an item to the collection';
is $coll->size, 6,       'The collection should now have six items';
ok $coll->added,         'added() should return a value';
ok $coll->remove($faux), 'Remove the added item';
is $coll->size, 5,       'The collection should be back to five items';
ok !$coll->added,        'added() should no longer return a value';
ok $coll->removed,       'remove() should return a value';
ok $coll->clear,         'Clear the collection';
ok $coll->is_cleared,    'is_cleared() should return true';
ok !$coll->added,        'added() should still not return a value';
ok !$coll->removed,      'removed() also should not return a value';
is $coll->size, 0,       'The size should be 0';

@list = map { Faux->new($_) } qw/zero un deux trois quatre/;
ok $coll = $CLASS->from_list({ list => \@list }),
    'Create a new collection from_list()';
ok $coll->is_assigned,  'is_assigned() should return true';
ok !$coll->is_cleared,  'is_cleared() should return false';
is $coll->size, 5,      'The collection should contain five items';
ok $coll->clear,        'Clear the collection';
ok !$coll->is_assigned, 'is_assigned() should return false';
ok $coll->is_cleared,   'is_cleared() should return true';
is $coll->size, 0,      'The size should be 0';
