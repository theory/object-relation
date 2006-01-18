#!/usr/bin/perl

use strict;
use warnings;

use Kinetic::Build::Test;
use Test::More qw/no_plan/;
use Test::Exception;
use Test::NoWarnings;    # Adds an extra test

my $ENGINE;

BEGIN {
    $ENV{KINETIC_CONF} = 't/conf/kinetic.conf';
    $ENGINE = 'Kinetic::Engine';
    use_ok $ENGINE or die;
}

# XXX stub test.  We don't have anything here yet.
