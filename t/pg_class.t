#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 1;
use Kinetic::Build::Test (
    store => { class   => 'Kinetic::Store::DB::Pg' },
    pg =>    { db_name => '__test__' },
);

# XXX To be written. Will execute a full suite of tests of the PostgreSQL
# store.
ok 1;

