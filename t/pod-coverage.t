#!perl -w

# $Id: pod-coverage.t 5941 2004-09-17 17:04:53Z theory $

use strict;
use Test::More;
eval "use Test::Pod::Coverage 0.08";
plan skip_all => "Test::Pod::Coverage required for testing POD coverage" if $@;

all_pod_coverage_ok();
