#!/usr/bin/perl -w

# $Id$

use warnings;
use strict;
use File::Find;
use File::Spec::Functions;
use File::Copy;
use File::Path;


BEGIN {
    # All build tests execute in the sample directory with its
    # configuration file.
    chdir 't'; chdir 'sample';
    $ENV{KINETIC_CONF} = catfile 'conf', 'kinetic.conf';

    # Copy the config file to the sample/conf directory.
    mkpath 'conf';
    my $from = catfile updir, updir, qw(conf kinetic.conf);
    my $to   = catdir(qw(conf kinetic.conf));
    copy $from, $to or die "Cannot copy $from to $to: $!\n";

}

END { rmtree 'conf' }

# Make sure we get access to all lib directories we're likely to need.
use lib catdir(updir, 'build'),              # Build test classes
        catdir(updir, 'lib'),                # Base test class, utility
        catdir(updir, updir, 'blib', 'lib'), # Build library
        catdir(updir, updir, 'lib');         # Distribution library

use TEST::Class::Kinetic catdir updir, 'build';

TEST::Class::Kinetic->runall;

__END__
