#!perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 2;

BEGIN {
    # Try missing file.
    local $ENV{KINETIC_CONF} = '__foo__bar__bick';
    eval 'use Kinetic::Util::Config';
    ok( my $err = $@, "Got error" );
    like( $err, qr/^No such configuration file/, 'Got no such file error');
}
