#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More;
eval "use Test::Pod::Coverage 0.08";
plan skip_all => "Test::Pod::Coverage required for testing POD coverage" if $@;

my %TODO = map { $_ => 1 } qw/
/;
diag "Don't forget to update the pod at some point"
  if %TODO;

my @modules = Test::Pod::Coverage::all_modules();
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
