#!/usr/bin/perl
use warnings;
use strict;

use Test::More tests => 6;
#use Test::More 'no_plan';

use lib 'lib/', '../lib/';

BEGIN {
    use_ok 'Kinetic::HOP::Lexer', ':all' or die;
}

my @exported = qw(
  allinput
  blocks
  iterator_to_stream
  make_lexer
  tokens
);

foreach my $function (@exported) {
    no strict 'refs';
    ok defined &$function, "&$function should be exported to our namespace";
}
