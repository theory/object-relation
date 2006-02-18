#!/usr/bin/perl -w

# $Id: system.t 2569 2006-02-03 22:50:57Z theory $

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
        my $script = catfile 't', 'system', $feature;
        my $setup = "${script}_setup.pl";
        next unless -e $setup;
        system $^X, $setup and die "# $setup failed: ($!)";
        push @scripts, $script;
    }
}

END {
    # Run complementary teardown scripts.
    return if $ENV{NOSETUP};
    $ENV{KINETIC_CONF} = $conf;

    # Disconnect!
    my $store = Kinetic::Store->new;
    if (my $dbh = $store->{dbh}) {
        $dbh->disconnect;
    }

    for my $script (@scripts) {
        my $teardown = "${script}_teardown.pl";
        next unless -e $teardown;
        system $^X, $teardown and die "# $teardown failed: ($!)";
    }
}

# Make sure we get access to all lib directories we're likely to need.
use lib 't/catalyst', 't/lib', 'lib';
use Kinetic::Store;

# Run the tests.
use TEST::Class::Kinetic catdir 't', 'catalyst', 'TEST';
TEST::Class::Kinetic->runall;

__END__
