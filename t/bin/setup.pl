#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Kinetic::Store::Setup;

my $setup = Kinetic::Store::Setup->new({ @ARGV });

$setup->class_dirs('t/sample/lib');
$setup->setup;
