#!perl -w

use strict;
use Test::More tests => 2;

BEGIN { use_ok 'App::Kinetic' };
isa_ok( $App::Kinetic::VERSION, 'version');
