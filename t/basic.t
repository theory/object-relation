#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 11;

BEGIN {
    use_ok 'Kinetic';
    use_ok 'Kinetic::Base';
};

isa_ok( $Kinetic::VERSION, 'version');

package MyApp::TestThingy;
use base 'Kinetic::Base';
BEGIN {
    use Test::More;
    ok my $km = Kinetic::Meta->new(
        key         => 'thingy',
        name        => 'Thingy',
        plural_name => 'Thingies',
    ), "Create TestThingy class";
    ok $km->build, "Build TestThingy class";
}

package main;

ok my $kinetic = MyApp::TestThingy->new, "Create new TestThingy";
isa_ok $kinetic, 'MyApp::TestThingy';
isa_ok $kinetic, 'Kinetic::Base';

is $kinetic->name, undef, "Check for undefined name";
ok $kinetic->name('foo'), "Set name to 'foo'";
is $kinetic->name, 'foo', "Check for name 'foo'";


