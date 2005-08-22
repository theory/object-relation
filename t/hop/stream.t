#!/usr/bin/perl
use warnings;
use strict;

#use Test::More tests => 41;
use Test::More 'no_plan';

use lib 'lib/', '../lib/';

BEGIN {
    use_ok 'Kinetic::HOP::Stream', ':all' or die;
}

my @exported = qw(node head tail drop upto upfrom show promise
  filter transform merge list_to_stream cutsort
  iterate_function cut_loops);

foreach my $function (@exported) {
    no strict 'refs';
    ok defined &$function, "&$function should be exported to our namespace";
}
