#!/usr/bin/perl
use warnings;
use strict;

use Test::More 'no_plan';

use lib 'lib';
BEGIN {
    use_ok 'Stream', ':all' or die;
}

ok my $node = node(1,[2,3]), 'node() should succeed';
is_deeply $node, [1, [2,3]], '... and retun an array ref of its first two args';
is head($node), 1, 'head() should return the first element of a node';
is_deeply tail($node), [2,3], '... and tail() should return the tail of the node';

my $stream = upto(4, 6);

my @print;
{
    no warnings 'redefine';
    *Stream::_print = sub { push @print => grep /\S/ => @_ };
}
show($stream);
is_deeply \@print, [4,5,6], 'upto() should generated the correct values';

@print = ();
show(upfrom(7), 10);
is_deeply \@print, [7 .. 16], 'upfrom() should also generate the correct values';
