#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
#use Test::More tests => 17;
use Test::More skip_all => "Collection not implemented yet";
use File::Spec;
use lib File::Spec->catdir(qw(t lib));
use Bricolage::Test::Setup;

BEGIN {
    use_ok('Bricolage::Util::Collection');
}

my $coll;
my @items = qw(one two three four);
ok( $coll = Bricolage::Util::Collection->new, "Create new collection" );

isa_ok($coll, 'Bricolage::Util::Collection');
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

