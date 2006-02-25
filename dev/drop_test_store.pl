#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use lib 'lib';
use Kinetic::Build;

my $build = Kinetic::Build->resume;
my $kbs = $build->setup_objects('store');
$kbs->builder->quiet(1);
$kbs->test_cleanup;
