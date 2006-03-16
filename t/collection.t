#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use utf8;
use Kinetic::Build::Test;

use Test::More tests => 102;
#use Test::More 'no_plan';
use Test::NoWarnings;    # Adds an extra test.
use Test::Exception;
use File::Spec;
use aliased 'Kinetic::Util::Iterator';
use Kinetic::Util::Constants '$UUID_RE';
use Data::UUID;

{

    package Faux;

    sub new {
        my ( $class, $name ) = @_;
        bless {
            uuid => undef,
            name => $name,
        }, $class;
    }

    sub id   { shift->{uuid} }
    sub name { shift->{name} }
    sub uuid { shift->{uuid} }
    sub save { $_[0]->{uuid} ||= Data::UUID->new->create_str; $_[0] }
}

my $CLASS;

BEGIN {
    $CLASS = 'Kinetic::Util::Collection';
    use_ok $CLASS or die;
}

can_ok $CLASS, 'new';
throws_ok { $CLASS->new }
  qr/Argument “.*” is not a valid Kinetic::Util::Iterator object/,
  '... and calling it without an argument should die';

throws_ok {
    $CLASS->new(
        {   iter => sub { }
        }
    );
  }
  qr/Argument “.*” is not a valid Kinetic::Util::Iterator object/,
  '... and as should calling with without a proper iterator object';

#
# A collection of unsaved objects (they don't yet have UUIDs)
#

my @items = map { Faux->new($_) } qw/fee fie foe fum/;
my @copy  = @items;
my $iter  = Iterator->new( sub { shift @copy } );
ok my $coll = $CLASS->new( { iter => $iter } ),
  'Calling new() with a valid iterator object should succeed';
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
# A bit of internals testing to ensure that objects don't need a UUID to be
# saved correctly.
#
# Sorry 'bout that.
#

can_ok $coll, '_array';
ok my $array = $coll->_array, '... and we should be the AsHash object';
my @keys = $array->keys;
ok !grep {/$UUID_RE/} @keys, '... and none of the keys should match a UUID';

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

ok $array = $coll->_array, '... and we should be the AsHash object';
@keys = $array->keys;
is scalar( grep {/$UUID_RE/} @keys ), scalar(@keys),
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

can_ok $coll, 'set';
$coll->set( 3, Faux->new('trois') );
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
use Data::Dumper;
my @list = ( 1 .. 4 );
ok $coll = $CLASS->from_list( { list => \@list } ),
  'We should be able to create a collection of integers';
is $coll->next, 1, '... and we should be able to get the next() value';
is_deeply [ $coll->all ], [ 1 .. 4 ],
  '... and it should contain the correct integers';
is $coll->next, 1, '... and generally just behave like a normal collection';
is $coll->next, 2, '... and generally just behave like a normal collection';

throws_ok {$coll = $CLASS->from_list( { list => [1,1] } )}
    'Kinetic::Util::Exception::Fatal',
    'Trying to assign duplicate items to a collection should fail';
like $@, qr/^Cannot assign duplicate values to a collection: 1/,
    '... with an appropriate error message';
