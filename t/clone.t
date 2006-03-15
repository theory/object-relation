#!/usr/bin/perl -w

# $Id$

use strict;
use Kinetic::Build::Test;
use Test::More tests => 14;
use Test::NoWarnings; # Adds an extra test.

BEGIN { use_ok 'Kinetic' or die };

package MyApp::Simple;
use base 'Kinetic';
BEGIN {
    use Test::More;
    ok my $km = Kinetic::Meta->new(
        key         => 'thingy',
        name        => 'Thingy',
        plural_name => 'Thingies',
    ), "Create Simple class";

    # Add DateTime attribute.
    ok( $km->add_attribute(
        name     => 'datetime',
        view     => Class::Meta::PUBLIC,
        type     => 'datetime',
        required => 1,
        default  => sub { Kinetic::DataType::DateTime->now },
    ), "Add datetime attribute" );

    ok $km->build, "Build Simple class";
}

package main;

# Create a simple object to clone.
ok my $kinetic = MyApp::Simple->new, "Create new Simple object";

# Simple clone.
ok my $k2 = $kinetic->clone, "Clone object";
isa_ok $k2, 'MyApp::Simple';
isa_ok $k2, 'Kinetic';
isnt overload::StrVal($k2), overload::StrVal($kinetic),
  "Make sure they're different objects";
isnt $k2->uuid, $kinetic->uuid, "Check for different UUID";
is $k2->state, $kinetic->state, "Check for same state";
is $k2->datetime, $kinetic->datetime, "Check for same datetime";
isnt overload::StrVal($k2->datetime), overload::StrVal($kinetic->datetime),
  "Make sure datetime was actually cloned";
