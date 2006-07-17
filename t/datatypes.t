#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 123;
#use Test::More 'no_plan';
use Test::Exception;
use Test::NoWarnings; # Adds an extra test.
use Kinetic::Util::Functions qw(:uuid);

package Kinetic::TestTypes;
use strict;
use base 'Kinetic';

BEGIN {
    Test::More->import;
    # We need to load Kinetic first, or else things just won't work!
    use_ok('Kinetic') or die;
    use_ok('Kinetic::Meta::DataTypes')     or die;
    use_ok('Kinetic::DataType::DateTime')  or die;
    use_ok('Kinetic::DataType::Duration')  or die;
    use_ok('Kinetic::DataType::MediaType') or die;
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

    # Add an Integer attribute.
    ok( $cm->add_attribute(
        name     => 'integer',
        view     => Class::Meta::PUBLIC,
        type     => 'integer',
    ), 'Add integer attribute' );

    # Add a Whole attribute.
    ok( $cm->add_attribute(
        name     => 'whole',
        view     => Class::Meta::PUBLIC,
        type     => 'whole',
        required => 1,
    ), 'Add whole attribute' );

    # Add a posint attribute.
    ok( $cm->add_attribute(
        name     => 'posint',
        view     => Class::Meta::PUBLIC,
        type     => 'posint',
    ), 'Add posint attribute' );

    # Add a DateTime attribute.
    ok( $cm->add_attribute( name     => 'datetime',
                            view     => Class::Meta::PUBLIC,
                            type     => 'datetime',
                            required => 1,
                          ),
        "Add datetime attribute" );

    # Add a Duration attribute.
    ok( $cm->add_attribute( name     => 'duration',
                            view     => Class::Meta::PUBLIC,
                            type     => 'duration',
                          ),
        "Add duration attribute" );

    # Add a Operator attribute.
    ok( $cm->add_attribute( name     => 'operator',
                            view     => Class::Meta::PUBLIC,
                            type     => 'operator',
                          ),
        "Add operator attribute" );

    # Add a Media Type attribute.
    ok( $cm->add_attribute( name     => 'media_type',
                            view     => Class::Meta::PUBLIC,
                            type     => 'media_type',
                          ),
        "Add media_type attribute" );

    # Add a Attribute attribute.
    ok( $cm->add_attribute( name     => 'attribute',
                            view     => Class::Meta::PUBLIC,
                            type     => 'attribute',
                          ),
        "Add attribute attribute" );

    # Add a class attribute.
    ok( $cm->add_attribute( name     => 'string',
                            view     => Class::Meta::PUBLIC,
                            type     => 'string',
                            context  => Class::Meta::CLASS,
                            required => 1,
                          ),
        "Add class attribute" );

    # Add a version attribute.
    ok( $cm->add_attribute( name     => 'version',
                            view     => Class::Meta::PUBLIC,
                            type     => 'version',
                            required => 1,
                          ),
        "Add version attribute" );

    # Add an gtin attribute.
    ok( $cm->add_attribute( name     => 'gtin',
                            view     => Class::Meta::PUBLIC,
                            type     => 'gtin',
                            required => 1,
                          ),
        "Add gtin attribute" );

    ok($cm->build, "Build class" );
}

# Set up phone data store classes.
STORES: {
    package Kinetic::Store::Handle::DB::Pg;
    sub new { bless {}, shift }
    package Kinetic::Store::Handle::DB::SQLite;
    sub new { bless {}, shift }
}

##############################################################################
# Do the tests.
##############################################################################
package main;
# Instantiate an object and test its accessors.
ok( my $t = Kinetic::TestTypes->new,
    'Kinetic::TestTypes->new');

# Test the UUID accessor.
my $ouuid = OSSP::uuid->new;
ok $ouuid->import(str => $t->uuid ), 'The UUID should be set';
eval { $t->uuid(create_uuid()) };
ok my $err = $@, 'Got error setting UUID to bogus value';
like $err->error, qr/Cannot assign to read-only attribute .uuid./,
    'It should be the correct error';

# Test state accessor.
is $t->state, Kinetic::DataType::State->ACTIVE, "State should be active by default";

# Make sure that automatic baking works.
$t->{state} = Kinetic::DataType::State->INACTIVE->value; # Don't try this at home!
isa_ok($t->state, 'Kinetic::DataType::State');
is $t->state, Kinetic::DataType::State->INACTIVE, "It should be the proper value.";

# Set the state directly.
ok( $t->state(Kinetic::DataType::State->ACTIVE), "Set state" );
isa_ok( $t->state, 'Kinetic::DataType::State' );
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

# Make sure that automatic baking works.
my $date = '2005-03-23T19:30:05.1234';
$t->{datetime} = $date; # Don't try this at home!
isa_ok($t->datetime, 'Kinetic::DataType::DateTime');
isa_ok($t->datetime, 'DateTime');

# Test Integer accessor.
is $t->integer, undef, 'Check for no Integer';
ok $t->integer(-12),   '... Set it to a negative integer';
is $t->integer, -12,   '... It should be set';
ok $t->integer(12),    '... Set it to a positive integer';
is $t->integer, 12,    '... It should be set';
throws_ok { $t->integer('foo' ) }
    'Kinetic::Util::Exception::Fatal::Invalid',
    '... It should throw an exception for an invalid string value';
like $@->error, qr/Value .foo. is not an integer/,
    '... It should be the correct error';
throws_ok { $t->integer( 12.2 ) }
    'Kinetic::Util::Exception::Fatal::Invalid',
    '... It should throw an exception for an invalid numeric value';
like $@->error, qr/Value .12\.2. is not an integer/,
    '... It should be the correct error';

# Test Whole accessor.
is $t->whole, undef, 'Check for no Whole';
ok $t->whole(12),    '... Set whole';
is $t->whole, 12,    '... It should be set';
ok $t->whole(0),     '... Set it to 0';
is $t->whole, 0,     '... It should be set to 0';
throws_ok { $t->whole('foo' ) }
    'Kinetic::Util::Exception::Fatal::Invalid',
    '... It should throw an exception for an invalid string value';
like $@->error, qr/Value .foo. is not a whole number/,
    '... It should be the correct error';
throws_ok { $t->whole( 12.2 ) }
    'Kinetic::Util::Exception::Fatal::Invalid',
    '... It should throw an exception for an invalid numeric value';
like $@->error, qr/Value .12\.2. is not a whole number/,
    '... It should be the correct error';
throws_ok { $t->whole( -12 ) }
    'Kinetic::Util::Exception::Fatal::Invalid',
    '... It should throw an exception for an invalid negative value';
like $@->error, qr/Value .-12. is not a whole number/,
    '... It should be the correct error';

# Test Posint accessor.
is $t->posint, undef, '... Check for no Posint';
ok $t->posint(12),    '... Set posint';
is $t->posint, 12,    '... It should be set';
throws_ok { $t->posint('foo' ) }
    'Kinetic::Util::Exception::Fatal::Invalid',
    '... It should throw an exception for an invalid string value';
like $@->error, qr/Value .foo. is not a positive integer/,
    '... It should be the correct error';
throws_ok { $t->posint( 12.2 ) }
    'Kinetic::Util::Exception::Fatal::Invalid',
    '... It should throw an exception for an invalid numeric value';
like $@->error, qr/Value .12\.2. is not a positive integer/,
    '... It should be the correct error';
throws_ok { $t->posint( -12 ) }
    'Kinetic::Util::Exception::Fatal::Invalid',
    '... It should throw an exception for an invalid negative value';
like $@->error, qr/Value .-12. is not a positive integer/,
    '... It should be the correct error';
throws_ok { $t->posint(0) }
    'Kinetic::Util::Exception::Fatal::Invalid',
    '... It should throw an exception for an 0';
like $@->error, qr/Value .0. is not a positive integer/,
    '... It should be the correct error';

# Try assigning a Kinetic::DataType::DateTime object.
my $dt = Kinetic::DataType::DateTime->now->set_time_zone('America/Los_Angeles');
ok( $t->datetime($dt), "Add DateTime object" );
is overload::StrVal($t->datetime), overload::StrVal($dt),
  "DateTime object should be the same";

is $t->my_class->attributes('datetime')->raw($t),
  $dt->clone->set_time_zone('UTC')->iso8601,
  "Make sure the raw value is a UTC string";
eval { $t->datetime('foo') };
ok $err = $@, "Caught bad DateTime exception";
isa_ok $err, 'Kinetic::Util::Exception::Fatal::Invalid';

# Test Duration accessor.
is( $t->duration, undef, 'Check for no Duration' );

# Make sure that automatic baking works.
my $duration = '@ 4541 years 4 mons 4 days 17 mins 31 secs';
$t->{duration} = $duration; # Don't try this at home!
isa_ok($t->duration, 'Kinetic::DataType::Duration');
isa_ok($t->duration, 'DateTime::Duration');

# Try assigning a Kinetic::Duration object.
$duration = Kinetic::DataType::Duration->new(
    days    => 2,
    hours   => -23,
    minutes => -59
);
ok( $t->duration($duration), "Add Duration object" );
is ref $t->duration, ref $duration, 'Duration object should be the same';

is $t->my_class->attributes('duration')->raw($t),
    'P0Y0M2DT-23H-59M0S',
    "Make sure the raw value is properly formatted";

my $store = Kinetic::Store::Handle::DB::Pg->new;
is $t->my_class->attributes('duration')->store_raw($t, $store),
    '0 years 0 mons 2 days -23 hours -59 mins 0 secs',
    'Make sure the PostgreSQL store_raw value is properly formatted';

$store = Kinetic::Store::Handle::DB::SQLite->new;
is $t->my_class->attributes('duration')->store_raw($t, $store),
    'P00000Y00M02DT-23H-59M00S',
    'Make sure the SQLite store_raw value is properly formatted';

eval { $t->duration('foo') };
ok $err = $@, "Caught bad Duration exception";
isa_ok $err, 'Kinetic::Util::Exception::Fatal::Invalid';

# Test the class attribute.
is( Kinetic::TestTypes->string, undef, 'The string should be undef' );
is $t->string, undef, "The object should see the undef, too";
ok( Kinetic::TestTypes->string('bub'), "Set the string" );
is( Kinetic::TestTypes->string, 'bub', 'The attribute should be set' );
is $t->string, 'bub', "The object should see the same value";

# Test version accessor.
is( $t->version, undef, 'Check for no Version' );

# Make sure that automatic baking works.
my $version = '1.10.3';
$t->{version} = $version; # Don't try this at home!
isa_ok($t->version, 'version');

# Try assigning a Kinetic::Version object.
$version = version->new('4.3');
ok( $t->version($version), 'Add Version object' );
is overload::StrVal($t->version), overload::StrVal($version),
    'Version object should be the same';

is $t->my_class->attributes('version')->raw($t), $version->stringify,
    'Make sure the raw value is stringified';
eval { $t->version('foo') };
ok $err = $@, "Caught bad Version exception";
isa_ok $err, 'Kinetic::Util::Exception::Fatal::Invalid';

# Test gtin accessor.
is( $t->gtin, undef, 'Check for no GTIN' );
ok( $t->gtin('036000291452'), 'Try a UPC');
ok( $t->gtin('4007630000116'), 'Try an GTIN');
is( $t->gtin, '4007630000116', 'It should be properly set');
throws_ok { $t->gtin('0036000291453') }
    'Kinetic::Util::Exception::Fatal::Invalid',
    'Make sure an invalid GTIN is caught';

# Test Operator accessor.
is( $t->operator, undef, 'Check for no Operator' );

my $op = '==';
# Try assigning a Kinetic::Operator object.
ok $t->operator($op), 'Set operator';
is $t->operator, $op, 'It should be set';
is $t->my_class->attributes('operator')->get($t), $op,
    'It should be accessable via the attribute object';
eval { $t->operator('foo') };
ok $err = $@, "Caught bad Operator exception";
isa_ok $err, 'Kinetic::Util::Exception::Fatal::Invalid';
is $err->error, "Value \x{201c}foo\x{201d} is not a valid operator",
    'It should have the proper error message';

# Test Media Type accessor.
is( $t->media_type, undef, 'Check for no Media Type' );

my $mt = Kinetic::DataType::MediaType->bake('text/plain');
# Try assigning a Kinetic::Media_Type object.
ok $t->media_type($mt), 'Set media_type';
is $t->media_type, $mt, 'It should be set';
is overload::StrVal($t->media_type), overload::StrVal($mt),
    'It should be the same object';
is $t->my_class->attributes('media_type')->get($t), $mt,
    'It should be accessable via the attribute object';

eval { $t->media_type('foo') };
ok $err = $@, "Caught bad Media_Type exception";
isa_ok $err, 'Kinetic::Util::Exception::Fatal::Invalid';
is $err->error,
    "Value \x{201c}foo\x{201d} is not a valid Kinetic::DataType::MediaType object",
    'It should have the proper error message';

# Test Attribute accessor.
is( $t->attribute, undef, 'Check for no Attribute' );

# Make sure that automatic baking works.
my $attribute = 'types.bool';
$t->{attribute} = $attribute; # Don't try this at home!
isa_ok($t->attribute, 'Kinetic::Meta::Attribute');

# Try assigning a Kinetic::Attribute object.
$attribute = Kinetic::TestTypes->my_class->attributes('bool');
ok( $t->attribute($attribute), 'Add Attribute object' );
is $t->attribute, $attribute,
    'Attribute object should be the same';

is $t->my_class->attributes('attribute')->raw($t),
    $attribute->class->key . '.' . $attribute->name,
    'Make sure the raw value is stringified';
eval { $t->attribute('foo') };
ok $err = $@, "Caught bad Attribute exception";
isa_ok $err, 'Kinetic::Util::Exception::Fatal::Invalid';

