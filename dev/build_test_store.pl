#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use lib 'lib';
BEGIN { $ENV{KINETIC_CONF} ||= 't/conf/kinetic.conf' }
use Kinetic::Build;
use Kinetic::AppBuild;

my $build = Kinetic::Build->resume;
my $kbs = $build->setup_objects('store');
$build = $kbs->builder; # Because it gets loaded again.
$build->install_base('t/sample');
$build->quiet(1);
bless $build => 'Kinetic::AppBuild';
$kbs->test_setup;
$build->init_app;
$build->init_app( 'TestApp::Simple' ); # Let it use the Kinetic version.

