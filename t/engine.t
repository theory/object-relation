#!/usr/bin/perl

use strict;
use warnings;

use Kinetic::Build::Test;
use Test::More qw/no_plan/;
use Test::Exception;

my $ENGINE;

BEGIN {
    chdir 't' if -d 't';
    use lib '../lib';
    $ENGINE = 'Kinetic::Engine';
    use_ok $ENGINE or die;
}

# XXX stub test.  We don't have anything here yet.
