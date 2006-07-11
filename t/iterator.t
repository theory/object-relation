#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;

use Test::More tests => 44;
#use Test::More qw/no_plan/;
use Test::NoWarnings; # Adds an extra test.

BEGIN { use_ok('Kinetic::Util::Iterator') or die }

# Make sure we get an exception when we don't pass a code reference to the
# constructor.
eval { Kinetic::Util::Iterator->new('woot') };
ok( my $err = $@, "Caught exception" );
isa_ok( $err, 'Kinetic::Util::Exception' );
isa_ok( $err, 'Kinetic::Util::Exception::Fatal' );
isa_ok( $err, 'Kinetic::Util::Exception::Fatal::Invalid' );

my @items = qw(1 2 3 4 5 6);
my $i     = 0;

# Create a simple iterator object.
ok( my $iter = Kinetic::Util::Iterator->new( sub { $items[ $i++ ] } ),
    "Create iterator" );
isa_ok( $iter, 'Kinetic::Util::Iterator' );

# Make sure that the main methods work.
is( $iter->peek,    1, "Peek at first item" );
is( $iter->next,    1, "Check first item" );
is( $iter->peek,    2, "Peek at second item" );
is( $iter->current, 1, "Check current item is first item" );
is( $iter->next,    2, "Check second item" );
is( $iter->peek,    3, "Peek at third item" );
is( $iter->peek,    3, "Peek at third item again (cached)" );
is( $iter->current, 2, "Check current item is second item" );

# Make sure that undef finishes up the list (4 tests).
my $j = 2;
while ( my $next = $iter->next ) {
    is( $next, ++$j, "Check item # $j" );
}

# Create another iterator.
my $k = 0;
ok( $iter = Kinetic::Util::Iterator->new( sub { $items[ $k++ ] } ),
    "Create another iterator" );

# Make sure that scalar all() works.
is_deeply( scalar $iter->all, \@items, "Check scalar all()" );

# The iterator should be empty now.
is( $iter->next, undef, "Check for no more items" );

# Sneaky way to reset our test iterator.
$k = 0;

# Make sure that all() works.
is_deeply( [ $iter->all ], \@items, "Check all() returned list" );

# The iterator should be empty now.
is( $iter->next, undef, "Check for no more items" );

# Sneaky way to reset our test iterator.
$k = 0;

# Make sure that do() does its thing (6 tests).
$iter->do(
    sub {
        is( $_[0], $k, "Check do # $k" );
    }
);

# Sneaky way to reset our test iterator.
$k = 0;

# Make sure that do() sets $_ (6 tests).
$iter->do(
    sub {
        is( $_, $k, "Check do # $k" );
    }
);

# Sneaky way to reset our test iterator.
$k = 0;

# Make sure that do() does its thing and aborts when the code ref returns a
# false value (3 tests).
$iter->do(
    sub {
        return if $_[0] > 3;
        is( $_[0], $k, "Check do # $k" );
    }
);

{

    package Faux::Search;

    sub new {
        my ( $class, $param ) = @_;
        bless { param => $param } => $class;
    }

    sub param { shift->{param} }
}

my @searches = map { Faux::Search->new($_) } qw/ name rank serial /;
can_ok $iter, 'request';
ok !$iter->request,
  '... and it should return false if the request has not been set';
ok $iter->request( \@searches ), '... and setting the request should succeed';

my $expected = {
    name   => $searches[0],
    rank   => $searches[1],
    serial => $searches[2],
};
is_deeply $iter->request, $expected,
  '... and we should be able to fetch the request';
