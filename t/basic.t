#!perl -w

# $Id$

use strict;
use Test::More tests => 2;

BEGIN { use_ok 'Kinetic' };
isa_ok( $Kinetic::VERSION, 'version');
