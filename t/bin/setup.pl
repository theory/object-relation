#!/usr/bin/perl -w

# $Id: setup.pl 2581 2006-02-07 02:19:57Z theory $

use strict;
use warnings;
use Kinetic::Build;
use Getopt::Long;

my $init = 1;
Getopt::Long::GetOptions(
    'source-dir|l=s' => \my $source_dir,
    'init|i!'        => \$init,
);

my $build = Kinetic::Build->resume;
my $kbs = $build->setup_objects('store');
$kbs->builder->quiet(1);
$kbs->builder->source_dir($source_dir) if $source_dir;
$kbs->test_setup;
$build->init_app if $init;
