#!perl -w

# $Id$

use strict;
use warnings;
use File::Spec;
use lib 't/lib';
use Kinetic::TestSetup;
use Test::More tests => 2;
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
        eval 'use Kinetic::Config';
        ok( my $err = $@, "Got error" );
        like( $err, qr/^Cannot open/, 'Got cannot open file error');
    };
    # Clean up.
    unlink $fn if -e $fn;
}
