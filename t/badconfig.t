#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Kinetic::Build::Test;
use Test::More tests => 3;
use Test::NoWarnings; # Adds an extra test.
use File::Copy;

BEGIN {
    my $fn = $ENV{KINETIC_CONF} . '.tmp';
    SKIP: {
        skip "Cannot copy $ENV{KINETIC_CONF}", 2
          unless copy $ENV{KINETIC_CONF}, $fn;

        # Change the permissions on the config file.
        skip "Cannot chmod $fn.tmp", 2 unless chmod 0000, $fn;

        # Config.pm shouldn't be able to open it now.
        local $ENV{KINETIC_CONF} = $fn;
        eval 'use Kinetic::Util::Config';
        ok( my $err = $@, "Got error" );
        # XXX Error message defined by Config::Std.
        like( $err, qr/^Can't open/, 'Got cannot open file error');
    };
    # Clean up.
    unlink $fn if -e $fn;
}
