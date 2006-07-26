#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 14;
use Test::NoWarnings; # Adds an extra test.

BEGIN { use_ok 'Object::Relation::Base' or die };

package MyApp::Simple;
use base 'Object::Relation::Base';
BEGIN {
    use Test::More;
    ok my $km = Object::Relation::Meta->new(
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
        default  => sub { Object::Relation::DataType::DateTime->now },
    ), "Add datetime attribute" );

    ok $km->build, "Build Simple class";
}

package main;

# Create a simple object to clone.
ok my $obj_rel = MyApp::Simple->new, "Create new Simple object";

# Simple clone.
ok my $k2 = $obj_rel->clone, "Clone object";
isa_ok $k2, 'MyApp::Simple';
isa_ok $k2, 'Object::Relation::Base';
isnt overload::StrVal($k2), overload::StrVal($obj_rel),
  "Make sure they're different objects";
isnt $k2->uuid, $obj_rel->uuid, "Check for different UUID";
is $k2->state, $obj_rel->state, "Check for same state";
is $k2->datetime, $obj_rel->datetime, "Check for same datetime";
isnt overload::StrVal($k2->datetime), overload::StrVal($obj_rel->datetime),
  "Make sure datetime was actually cloned";
