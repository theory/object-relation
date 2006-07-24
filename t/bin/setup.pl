#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use aliased 'Kinetic::Store::Setup';
use Test::More;
use aliased 'Test::MockModule';

my $mock = MockModule->new(Setup);
$mock->mock(notify => sub { shift; diag @_ }) if $ENV{TEST_VERBOSE};

my $setup = Setup->new({
    verbose => $ENV{TEST_VERBOSE},
    @ARGV
});

$setup->class_dirs('t/sample/lib');
$setup->setup;
