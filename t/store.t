#!/usr/bin/perl -w

# $Id$

use warnings;
use strict;
use File::Spec::Functions;

my (@scripts, $conf);
BEGIN {
    # Run setup scripts for all supported databases unless we're asked
    # not to do so.
    $conf = $ENV{KINETIC_CONF};
    return if $ENV{NOSETUP} || !$ENV{KINETIC_SUPPORTED};
    for my $feature (split /\s+/, $ENV{KINETIC_SUPPORTED}) {
        my $script = catfile 't', 'store', $feature;
        my $setup = "${script}_setup.pl";
        next unless -e $setup;
        system $^X, $setup and die "# $setup failed: ($!)";
        push @scripts, $script;
    }
}

sub finish {
    # Run complementary teardown scripts.
    return if $ENV{NOSETUP};
    $ENV{KINETIC_CONF} = $conf;
    for my $script (@scripts) {
        my $teardown = "${script}_teardown.pl";
        next unless -e $teardown;
        system $^X, $teardown and die "$teardown failed: ($!)";
    }
}

# Make sure we get access to all lib directories we're likely to need.
use lib 't/sample/lib', 't/store', 't/lib';

# Run the tests.
use TEST::Class::Kinetic catdir 't', 'store', 'TEST';
TEST::Class::Kinetic->runall;
finish;
__END__
