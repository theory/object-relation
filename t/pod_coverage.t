#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More;
eval "use Test::Pod::Coverage 0.08";
plan skip_all => "Test::Pod::Coverage required for testing POD coverage" if $@;

my %TODO;
diag "Don't forget to update the pod at some point"
  if %TODO;

# we explicitly skip Kinetic::Store because some subs are
# dynamically generated and exported and this causes weird
# test failures in Kinetic::Store::DB and Kinetic::Store.

# Whether or not the POD coverage tests fails depends upon
# whether or not your are using prove or ./Build test
# This was *not* fun to debug

my @modules = grep { $_ !~ /^Kinetic::Store(?:::DB)?$/ } Test::Pod::Coverage::all_modules();
plan tests => scalar @modules;
foreach my $module (@modules) {
    if (exists $TODO{$module}) {
        TODO: {
            local $TODO = "Known incomplete POD for $module";
            pod_coverage_ok($module);
        };
    }
    else {
        pod_coverage_ok($module);
    }
}
