#!/usr/bin/perl -w

# $Id: setup.t 3046 2006-07-18 05:43:21Z theory $

use strict;
use warnings;
use Test::More tests => 2;
use Test::NoWarnings; # Adds an extra test.

BEGIN {
    use_ok 'Kinetic::Store::Setup::DB::Pg' or die;
}
