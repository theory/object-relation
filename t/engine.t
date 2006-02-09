#!/usr/bin/perl

use strict;
use warnings;

use Kinetic::Build::Test;
#use Test::More qw/no_plan/;
use Test::More tests => 3;
use Test::Exception;
use Test::NoWarnings;    # Adds an extra test

my $ENGINE;

BEGIN {
    use Kinetic::Util::Functions;
    my $load_store;
    {
        no warnings 'redefine';
        *Kinetic::Util::Functions::load_store = sub { $load_store++ };
    }
    $ENV{KINETIC_CONF} = 't/conf/kinetic.conf';
    $ENGINE = 'Kinetic::Engine';
    use_ok $ENGINE or die;
    ok $load_store, '... and using it should load the data store';
}

# XXX stub test.  We don't have anything here yet.
