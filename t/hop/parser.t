#!/usr/bin/perl
use warnings;
use strict;

use Test::More tests => 17;
#use Test::More 'no_plan';

use lib 'lib/', '../lib/';

BEGIN {
    use_ok 'Kinetic::HOP::Parser', ':all' or die;
}

my @exported = qw(
  action
  alternate 
  concatenate 
  debug
  End_of_Input
  error
  list_of
  lookfor
  match 
  nothing
  null_list 
  operator 
  parser
  star 
  T 
  test
);

foreach my $function (@exported) {
    no strict 'refs';
    ok defined &$function, "&$function should be exported to our namespace";
}
