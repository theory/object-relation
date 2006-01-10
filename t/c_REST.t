#!/usr/bin/perl -w

# $Id: basic.t 2441 2005-12-24 00:39:59Z theory $

use strict;
use Kinetic::Build::Test;
use Test::More tests => 5;
use Test::NoWarnings;    # Adds an extra test.
use Test::Output;

BEGIN {
    use_ok( 'Catalyst::Test', 'Kinetic::UI::Catalyst' ) or die;
    use_ok('Kinetic::UI::Catalyst::C::REST') or die;
}

stderr_like { ok request('rest')->is_success, 'REST should work' }
    qr/\[\w{3}\s\w{3}\s[ 123]\d\s\d{2}:\d{2}:\d{2}\s\d{4}\] \[catalyst\] \[debug\] login failed/,
    'Catalyst should output debugging info';
