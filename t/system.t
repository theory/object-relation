#!/usr/bin/perl -w

# $Id$

use warnings;
use strict;
use lib 't/lib';
use TEST::Kinetic::TestSetup;
use TEST::Class::Kinetic 't/system';

TEST::Class::Kinetic->runall;

__END__
