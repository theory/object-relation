#!/usr/bin/perl
use warnings;
use strict;

use Test::More tests => 21;
#use Test::More 'no_plan';

use lib 'lib/', '../lib/';

BEGIN {
    use_ok 'Kinetic::HOP::Stream', ':all' or die;
}

my @exported = qw(
  drop
  filter
  head
  iterator_to_stream
  list_to_stream
  merge
  node
  promise
  show
  tail
  transform
);

foreach my $function (@exported) {
    no strict 'refs';
    ok defined &$function, "&$function should be exported to our namespace";
}

ok my $stream = node( 3, 4 ), 'Calling node() should succeed';
is_deeply $stream, [ 3, 4 ], '... returning a stream node';
ok my $new_stream = node( 7, $stream ),
  '... and a node may be in the node() arguments';
is_deeply $new_stream, [ 7, $stream ], '... and the new node should be correct';

is head($new_stream), 7, 'head() should return the head of a node';
is tail($new_stream), $stream, 'tail() should return the tail of a node';

ok my $head = drop($new_stream), 'drop() should succeed';
is $head, 7, '... returning the head of the node';
is_deeply $new_stream, $stream,
  '... and setting the tail of the node as the node';
