#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Object::Relation::Setup;

my $setup = Object::Relation::Setup->new({ @ARGV });
$setup->teardown;
