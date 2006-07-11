#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 3;
use Test::NoWarnings; # Adds an extra test.

BEGIN {
    use_ok 'Kinetic::Build::Test', (
        store  => {
            class => 'Kinetic::Store::DB::SQLite',
            dsn   => 'dbi:SQLite:dbname=__test__',
        },
    ) or die;
}

BEGIN { use_ok( 'Kinetic::Util::Config', ':store' ) or die; }
