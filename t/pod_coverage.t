#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More;
eval "use Test::Pod::Coverage 0.08";
plan skip_all => "Test::Pod::Coverage required for testing POD coverage" if $@;

my %TODO;
diag "Don't forget to update the pod at some point"
  if %TODO;

# Whether or not the POD coverage tests fails depends upon
# whether or not your are using prove or ./Build test
# This was *not* fun to debug

my %exceptions = (
    'Kinetic::Store'         => qr/^(ASC|DESC|EQ|NE)$/,
    'Kinetic::Store::DB'     => qr/^(Incomplete|Iterator|Meta|Search)$/,
    'Kinetic::Store::Search' => qr/^(Incomplete)$/,
);

my @modules = grep { ! exists $exceptions{$_} } Test::Pod::Coverage::all_modules();
plan tests => scalar @modules + keys %exceptions;

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

while (my ($module, $subs_to_ignore) = each %exceptions) {
    pod_coverage_ok( $module, { trustme => [$subs_to_ignore] } );
}
