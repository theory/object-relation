#!/usr/bin/perl -w

# $Id$

use warnings;
use strict;
use File::Find;
use File::Spec::Functions;
BEGIN {
    # All build tests execute in the sample directory with its
    # configuration file.
    chdir 't'; chdir 'sample';
    $ENV{KINETIC_CONF} = catfile 'conf', 'kinetic.conf';
}

# Make sure we get access to all lib directories we're likely to need.
use lib catdir(updir, 'app_build'),          # AppBuild test classes
        catdir(updir, 'lib'),                # Base test class, utility
        catdir(updir, updir, 'blib', 'lib'), # AppBuild library
        catdir(updir, updir, 'lib');         # Distribution library

use TEST::Class::Kinetic catdir updir, 'app_build', 'TEST';

TEST::Class::Kinetic->runall;

__END__