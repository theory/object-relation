#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use utf8;

use Test::More tests => 76;
#use Test::More 'no_plan';
use Test::NoWarnings;    # Adds an extra test.
use Test::Exception;
use File::Spec;
use Kinetic::Store::Meta;
use aliased 'Kinetic::Util::Iterator';
use aliased 'Test::MockModule';

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

    package Faux::Subclass;
    our @ISA = 'Faux';

    package Faux::Unrelated;

    sub new {
        my ( $class, $name ) = @_;
        bless {
            name => $name,
        }, $class;
    }
}
{

    package Faux::Class;

    my %class_for = (
        faux      => 'Faux',
        subclass  => 'Faux::Subclass',
        unrelated => 'Faux::Unrelated',
    );

    sub new {
        my ( $class, $key ) = @_;
        my $kinetic_class = $class_for{$key} or return;
        bless {
            package => $kinetic_class,
        }, $class;
    }

    sub package {
        my ($self) = @_;
        return $self->{package};
    }
}

my $CLASS;

BEGIN {
    $CLASS = 'Kinetic::Util::Collection';
    use_ok $CLASS or die;
}

my $mock_k_class = MockModule->new('Kinetic::Store::Meta');
$mock_k_class->mock(
    for_key => sub {
        my ( $class, $key ) = @_;
        Faux::Class->new($key);
    }
);

can_ok $CLASS, 'new';
throws_ok { $CLASS->new } 'Kinetic::Util::Exception::Fatal::Invalid',
  '... and calling it without an argument should die';

throws_ok {
    $CLASS->new(
        {   iter => sub { }
        }
    );
  }
  'Kinetic::Util::Exception::Fatal::Invalid',
  '... and as should calling with without a proper iterator object';

throws_ok {
    $CLASS->new(
        {   iter => Iterator->new( sub { } ),
            key  => 'no_such_key',
        }
    );
  }
  'Kinetic::Util::Exception::Fatal::InvalidClass',
  '... and as should calling with without valid key';

my @items = map { Faux->new($_) } qw/fee fie foe fum/;
my $iter = Iterator->new( sub { shift @items } );
ok my $coll = $CLASS->new( { iter => $iter, key => 'faux' } ),
  'Calling new() with a valid key should succeed';
isa_ok $coll, $CLASS => '... and the object it returns';

can_ok $coll, 'package';
is $coll->package, 'Faux', '... and the collection package should be correct';

@Kinetic::Util::Collection::Faux::ISA = $CLASS;
my @items2 = map { Faux->new($_) } qw/fee fie foe fum/;
my $iter2 = Iterator->new( sub { shift @items2 } );
ok my $coll_from_package
  = Kinetic::Util::Collection::Faux->new( { iter => $iter } ),
  'Creating a collection from a subclass should succeed';

is $coll_from_package->package, 'Faux',
  '... and it should be for the correct package';
is_deeply $coll_from_package, $coll, '... and be set up correctly';

#
# Testing a basic type
#

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
# Testing a subclass (succeeds with subclasses)
#

@items = map { Faux->new($_) } qw/fee fie foe/;
push @items, Faux::Subclass->new('fum');
$iter = Iterator->new( sub { shift @items } );
ok $coll = $CLASS->new( { iter => $iter, key => 'faux' } ),
  'Calling new() with a valid key should succeed';
isa_ok $coll, $CLASS => '... and the object it returns';

can_ok $coll, 'next';
is $coll->next->name, 'fee',
  '... and it should return the correct value (fee)';
is $coll->next->name, 'fie',
  '... and it should return the correct value (fie)';
is $coll->next->name, 'foe',
  '... and it should return the correct value (foe)';
is $coll->next->name, 'fum',
  '... and it should even work with subclasses of the collection type';
ok !defined $coll->next,
  '... but when we get to the end it should return undef';

can_ok $coll, 'curr';
is $coll->curr->name, 'fum',
  '... and it should return the current value the collection is pointing to.';

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
# Testing a bad type (failing with unrelated classes)
#

@items = map { Faux->new($_) } qw/fee fie foe/;
push @items, Faux::Unrelated->new('fum');
$iter = Iterator->new( sub { shift @items } );
ok $coll = $CLASS->new( { iter => $iter, key => 'faux' } ),
  'Calling new() with a valid key should succeed';
isa_ok $coll, $CLASS => '... and the object it returns';

can_ok $coll, 'next';
is $coll->next->name, 'fee',
  '... and it should return the correct value (fee)';
is $coll->next->name, 'fie',
  '... and it should return the correct value (fie)';
is $coll->next->name, 'foe',
  '... and it should return the correct value (foe)';

#
# Testing a bad type (failing with superclasses)
#

@items = map { Faux::Subclass->new($_) } qw/fee fie foe/;
push @items, Faux->new('fum');
$iter = Iterator->new( sub { shift @items } );
ok $coll = $CLASS->new( { iter => $iter, key => 'subclass' } ),
  'Calling new() with a valid key should succeed';
isa_ok $coll, $CLASS => '... and the object it returns';

can_ok $coll, 'next';
is $coll->next->name, 'fee',
  '... and it should return the correct value (fee)';
is $coll->next->name, 'fie',
  '... and it should return the correct value (fie)';
is $coll->next->name, 'foe',
  '... and it should return the correct value (foe)';

throws_ok { $coll->next->name } 'Kinetic::Util::Exception::Fatal::Invalid',
  '... but it should throw an exception when it hits a bad type';

@items = map { Faux->new($_) } qw/zero one two three four five six/;
$iter = Iterator->new( sub { shift @items } );
$coll = $CLASS->new( { iter => $iter, key => 'faux' } );

can_ok $coll, 'set';
$coll->next;    # kick it to the first position
$coll->set( 3, Faux->new('trois') );
is $coll->get(3)->name, 'trois',
  '... and we should be able to set items to new values';
is $coll->curr->name, 'zero',
  '... but this should not affect the position of the collection';

throws_ok { $coll->set( 4, Faux::Unrelated->new('boom!') ) }
  'Kinetic::Util::Exception::Fatal::Invalid',
  'Setting a collection item to an invalid type should be fatal';

can_ok $CLASS, 'from_list';
ok $coll = $CLASS->from_list(
    {   list => [ map { Faux->new($_) } qw/zero un deux trois quatre/ ],
        key  => 'faux'
    }
  ),
  '... and calling it should succeed';
isa_ok $coll, $CLASS, '... and the object it returns';
ok $coll->isa("$CLASS\::Faux") , '... and it should be the proper class';
foreach (qw/zero un deux trois quatre/) {
    is $coll->next->name, $_, '... and it should return the correct items';
}

ok my $new_coll = $coll->from_list(
    { list => [ map { Faux->new($_) } qw/zero un deux trois quatre/ ] }
  ),
  'New collections should be able to get the type from the old collection';
isa_ok $new_coll, $CLASS, '... and the object it returns';
ok $new_coll->isa("$CLASS\::Faux") , '... and it should be the proper class';
foreach (qw/zero un deux trois quatre/) {
    is $new_coll->next->name, $_, '... and it should return the correct items';
}
