#!/usr/bin/perl -w

# $Id$

use warnings;
use strict;
use File::Spec::Functions;

my @scripts;
BEGIN {
    # Run setup scripts for all supported databases unless we're asked
    # not to do so.
    return if $ENV{NOSETUP} || !$ENV{KINETIC_SUPPORTED};
    for my $feature (split /\s+/, $ENV{KINETIC_SUPPORTED}) {
        my $script = catfile 't', 'store', $feature;
        next unless -e "$script\_setup.pl";
        system $^X, "$script\_setup.pl" and die;
        push @scripts, $script;
    }
}

END {
    # Run complementary teardown scripts.
    return if $ENV{NOSETUP};
    for my $script (@scripts) {
        next unless -e "$script\_teardown.pl";
        system $^X, "$script\_teardown.pl" and die;
    }
}

# Make sure we get access to all lib directories we're likely to need.
use lib 't/sample/lib', 't/store', 't/lib';

# Run the tests.
use TEST::Class::Kinetic catdir 't', 'store', 'TEST';
TEST::Class::Kinetic->runtests;

__END__
