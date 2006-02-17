#!/usr/bin/perl -w

# $Id$

use strict;
use Kinetic::Build::Test;
use Test::More tests => 6;
use Test::NoWarnings;    # Adds an extra test.
use Test::Output;
use Config::Std;         # Avoid warnings;

BEGIN {
    use_ok('Kinetic::UI::Catalyst') or die;
    use_ok( 'Catalyst::Test', 'Kinetic::UI::Catalyst' ) or die;
    use_ok('Kinetic::UI::Catalyst::C::View') or die;
}

stderr_like { ok request('view')->is_success, 'View should work' }
    qr/\[\w{3}\s\w{3}\s[ 123]\d\s\d{2}:\d{2}:\d{2}\s\d{4}\] \[catalyst\] \[debug\] Can't login a user without a username/,
    'Catalyst should output debugging info';

