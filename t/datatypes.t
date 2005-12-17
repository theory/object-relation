#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 38;
use Kinetic::Util::Functions qw(:uuid);


package Kinetic::TestTypes;
use strict;
use base 'Kinetic';

BEGIN {
    Test::More->import;
    # We need to load Kinetic first, or else things just won't work!
    use_ok('Kinetic') or die;
    use_ok('Kinetic::Meta::DataTypes') or die;
}

BEGIN {
    ok( my $cm = Kinetic::Meta->new(
        key     => 'types',
        name    => 'Testing DataTypes',
    ), "Create new CM object" );

    ok( $cm->add_constructor(name => 'new'), "Create new() constructor" );

    # Add boolean attribute.
    ok( $cm->add_attribute( name     => 'bool',
                            view     => Class::Meta::PUBLIC,
                            type     => 'bool',
                            required => 1,
                            default  => 1,
                          ),
        "Add boolean attribute" );

    # Add a DateTime attribute.
    ok( $cm->add_attribute( name     => 'datetime',
                            view     => Class::Meta::PUBLIC,
                            type     => 'datetime',
                            required => 1,
                          ),
        "Add datetime attribute" );

    # Add a class attribute.
    ok( $cm->add_attribute( name     => 'string',
                            view     => Class::Meta::PUBLIC,
                            type     => 'string',
                            context  => Class::Meta::CLASS,
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

# Test the UUID accessor.
eval { $t->uuid('foo') };
ok my $err = $@, 'Got error setting UUID to bogus value';
like $err->error, qr/Value .foo. is not a UUID/,
    'It should be the correct error';

my $uuid = create_uuid();
ok $t->uuid($uuid), 'Set the UUID';
is $t->uuid, $uuid, 'Check the UUID';

# Make sure we can't set it again.
eval { $t->uuid(create_uuid()) };
ok( $err = $@, "Got error setting UUID to a new value" );
like $err->error, qr/Attribute .uuid. can be set only once/,
    'It should be the correct error';

# Test state accessor.
is $t->state, Kinetic::Util::State->ACTIVE, "State should be active by default";

# Make sure that automatic bakeing works.
$t->{state} = Kinetic::Util::State->INACTIVE->value; # Don't try this at home!
isa_ok($t->state, 'Kinetic::Util::State');
is $t->state, Kinetic::Util::State->INACTIVE, "It should be the proper value.";

# Set the state directly.
ok( $t->state(Kinetic::Util::State->ACTIVE), "Set state" );
isa_ok( $t->state, 'Kinetic::Util::State' );
# Make sure we get its raw value.
is $t->my_class->attributes('state')->raw($t),
  $t->state->value, "Make sure the raw value is a number";

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

# Make sure that automatic bakeing works.
my $date = '2005-03-23T19:30:05.1234';
$t->{datetime} = $date; # Don't try this at home!
isa_ok($t->datetime, 'Kinetic::DateTime');
isa_ok($t->datetime, 'DateTime');

# Try assigning a Kinetic::DateTime object.
my $dt = Kinetic::DateTime->now->set_time_zone('America/Los_Angeles');
ok( $t->datetime($dt), "Add DateTime object" );
is overload::StrVal($t->datetime), overload::StrVal($dt),
  "DateTime object should be the same";

is $t->my_class->attributes('datetime')->raw($t),
  $dt->clone->set_time_zone('UTC')->iso8601,
  "Make sure the raw value is a UTC string";
eval { $t->datetime('foo') };
ok my $err = $@, "Caught bad DateTime exception";
isa_ok $err, 'Kinetic::Util::Exception::Fatal::Invalid';

# Test the class attribute.
is( Kinetic::TestTypes->string, undef, 'The string should be undef' );
is $t->string, undef, "The object should see the undef, too";
ok( Kinetic::TestTypes->string('bub'), "Set the string" );
is( Kinetic::TestTypes->string, 'bub', 'The attribute should be set' );
is $t->string, 'bub', "The object should see the same value";

