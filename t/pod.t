#!perl -w

# $Id: pod.t 5941 2004-09-17 17:04:53Z theory $

use strict;
use Test::More;
eval "use Test::Pod 1.06";
plan skip_all => "Test::Pod 1.06 required for testing POD" if $@;
all_pod_files_ok();
