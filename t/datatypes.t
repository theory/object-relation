#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 25;
use Data::UUID;

package Kinetic::TestTypes;
use strict;
use Kinetic::Util::State;

BEGIN {
    Test::More->import;
    # We need to load Kinetic first, or else things just won't work!
    use_ok('Kinetic');
    use_ok('Kinetic::Meta::DataTypes');
}

BEGIN {
    ok( my $cm = Class::Meta->new(
        key     => 'types',
        name    => 'Testing DataTypes',
    ), "Create new CM object" );

    ok( $cm->add_constructor(name => 'new'), "Create new() constructor" );

    # Add a GUID Attribute.
    my $ug = Data::UUID->new;
    ok( $cm->add_attribute( name     => 'guid',
                            view     => Class::Meta::PUBLIC,
                            type     => 'guid',
                            required => 1,
                            default  => sub { $ug->create_str },
                            authz    => Class::Meta::READ,
                          ),
        "Add guid attribute" );

    # Add a state attribute.
    ok( $cm->add_attribute( name     => 'state',
                            context  => Class::Meta::CLASS,
                            label    => 'State',
                            required => 1,
                            type     => 'state'
                          ),
        "Add state attribute" );

    # Add boolean attribute.
    ok( $cm->add_attribute( name     => 'bool',
                            view     => Class::Meta::PUBLIC,
                            type     => 'bool',
                            required => 1,
                            default  => 1,
                          ),
        "Add boolean attribute" );

    # Add DateTime attribute.
    ok( $cm->add_attribute( name     => 'datetime',
                            view     => Class::Meta::PUBLIC,
                            type     => 'datetime',
                            required => 1,
                          ),
        "Add datetime attribute" );


    ok($cm->build, "Build class" );
}

##############################################################################
# Do the tests.
##############################################################################
package main;
# Instantiate an object and test its accessors.
ok( my $t = Kinetic::TestTypes->new,
    'Kinetic::TestTypes->new');

# Test the GUID accessor.
ok(my $guid = $t->guid, "Get GUID" );
ok( Data::UUID->new->from_string($guid), "It's a valid GUID" );

# Make sure we can't set it.
eval { $t->guid($guid) };
ok( $@, "Got error setting GUID" );

# Test state accessor.
ok( $t->state(Kinetic::Util::State->ACTIVE), "Set state" );
isa_ok( $t->state, 'Kinetic::Util::State' );

# Make sure an invalid value throws an exception.
eval { $t->state('foo') };
ok( $@, "Got error with invalid state object" );

# And an undefined value is not okay.
eval { $t->state(undef) };
ok( $@, "Got error with undef for state object" );

# Test boolean accessor.
ok( $t->bool, "Check bool" );
$t->bool(undef);
ok( ! $t->bool, "Check false bool" );

# Test DateTime accessor.
is( $t->datetime, undef, 'Check for no DateTime' );
ok( $t->datetime(Kinetic::DateTime->now), "Add DateTime object" );
isa_ok($t->datetime, 'Kinetic::DateTime');
isa_ok($t->datetime, 'DateTime');
eval { $t->datetime('foo') };
ok my $err = $@, "Caught bad DateTime exception";
isa_ok $err, 'Kinetic::Util::Exception::Fatal::Invalid';
