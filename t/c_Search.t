#!/usr/bin/perl -w

# $Id$

use strict;
use Kinetic::Build::Test;
use Test::More tests => 6;
use Test::NoWarnings;    # Adds an extra test.
use Test::Output;

BEGIN {

    # XXX Catalyst tests must not be run from the t/ directory
    use_ok('Kinetic::UI::Catalyst') or die;
    use_ok( 'Catalyst::Test', 'Kinetic::UI::Catalyst' ) or die;
    use_ok('Kinetic::UI::Catalyst::C::Search') or die;
}

stderr_like { ok request('search')->is_success, 'Search should work' }
    qr/\[\w{3}\s\w{3}\s[ 123]\d\s\d{2}:\d{2}:\d{2}\s\d{4}\] \[catalyst\] \[debug\] Can't login a user without a username/,
    'Catalyst should output debugging info';

