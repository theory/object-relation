#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 5;
use Test::NoWarnings; # Adds an extra test.

BEGIN {
    use_ok 'Kinetic::Build::Test', (
        store  => {
            class => 'Kinetic::Store::DB::SQLite',
            file => '__test__',
        },
    ) or die;
}

BEGIN { use_ok( 'Kinetic::Util::Config', ':store' ) or die; }

is STORE_CLASS, 'Kinetic::Store::DB::SQLite', 'Store class should be SQLite';
is STORE_FILE,  '__test__',                   'Database file should be changed';
