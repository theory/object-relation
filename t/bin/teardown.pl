#!/usr/bin/perl -w

# $Id: setup.pl 2581 2006-02-07 02:19:57Z theory $

use strict;
use warnings;
use Kinetic::Build;

my $build = Kinetic::Build->resume;
my $kbs = $build->setup_objects('store');
$kbs->builder->quiet(1);
$kbs->test_cleanup;
