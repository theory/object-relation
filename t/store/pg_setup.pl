#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Kinetic::Build;

my $build = Kinetic::Build->resume;
my $kbs = $build->notes('build_store');
$kbs->builder->source_dir('t/sample/lib');
$kbs->test_setup;
