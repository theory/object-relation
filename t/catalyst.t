#!/usr/bin/perl -w

# $Id: system.t 2569 2006-02-03 22:50:57Z theory $

use warnings;
use strict;
use lib 't/lib';
use TEST::Kinetic::TestSetup;
use TEST::Class::Kinetic 't/system';

TEST::Class::Kinetic->runall;

__END__
