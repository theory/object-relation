#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More;
use Class::Std; # Avoid warnings;
eval "use Test::Pod::Coverage 0.08";
plan skip_all => "Test::Pod::Coverage required for testing POD coverage" if $@;

my $aliased = qr/^[[:upper:]][[:alpha:]]*$/;
my @modules =  Test::Pod::Coverage::all_modules();
plan tests => scalar @modules;

foreach my $module (@modules) {
    pod_coverage_ok( $module, { trustme => [ $aliased ] } );
}
