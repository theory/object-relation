#!/usr/bin/perl
use warnings;
use strict;

use Test::More tests => 16;
#use Test::More 'no_plan';

use lib 'lib/', '../lib/';

BEGIN {
    use_ok 'Kinetic::HOP::Stream', ':all' or die;
}

my @exported = qw(
  cut_loops
  cutsort
  drop
  filter
  head
  iterate_function
  list_to_stream
  merge
  node
  promise
  show
  tail
  transform
  upfrom
  upto
);

foreach my $function (@exported) {
    no strict 'refs';
    ok defined &$function, "&$function should be exported to our namespace";
}
