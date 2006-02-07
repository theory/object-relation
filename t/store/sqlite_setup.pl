#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use File::Path;
use File::Spec::Functions;
use Kinetic::Build;

mkpath catdir 't', 'data';
my $build = Kinetic::Build->resume;
my $kbs = $build->notes('build_store');
$kbs->builder->source_dir('t/sample/lib');
$kbs->test_setup;
