#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 17;

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
        default  => sub { Kinetic::DateTime->now },
    ), "Add datetime attribute" );

    ok $km->build, "Build Simple class";
}

package main;

# Create a simple object to clone.
ok my $kinetic = MyApp::Simple->new, "Create new Simple object";
ok $kinetic->name('foo'), "Set name";
ok $kinetic->description('bar'), "Set description";

# Simple clone.
ok my $k2 = $kinetic->clone, "Clone object";
isa_ok $k2, 'MyApp::Simple';
isa_ok $k2, 'Kinetic';
isnt overload::StrVal($k2), overload::StrVal($kinetic),
  "Make sure they're different objects";
isnt $k2->guid, $kinetic->guid, "Check for different GUID";
is $k2->name, $kinetic->name, "Check for same name";
is $k2->description, $kinetic->description, "Check for same description";
is $k2->state, $kinetic->state, "Check for same state";
is $k2->datetime, $kinetic->datetime, "Check for same datetime";
isnt overload::StrVal($k2->datetime), overload::StrVal($kinetic->datetime),
  "Make sure datetime was actually cloned";
