#!/usr/bin/perl -w

# $Id: km_declare.t 2507 2006-01-11 01:12:14Z theory $

use strict;
use warnings;

use Test::More tests => 8;
#use Test::More 'no_plan';
use Test::NoWarnings;    # Adds an extra test.
use aliased 'Test::MockModule';

use Class::Meta::Declare;

my $DECLARE;

BEGIN {
    $DECLARE = 'Kinetic::Meta::Declare';
    use_ok $DECLARE, ':all' or die;
}

my $mock_declare = MockModule->new('Class::Meta::Declare');
my @args;
$mock_declare->mock( new => sub { shift; @args = @_ } );

can_ok $DECLARE, 'new';

#
# test meta defaults
#

ok $DECLARE->new(
    meta => [
        key         => 'some_object',
        plural_name => 'Some objects',
    ],
  ),
  '... and calling it with valid arguments should succeed';

my @expected = (
    'meta' => [
        key         => 'some_object',
        plural_name => 'Some objects',
        use         => 'Kinetic::Meta',
        name        => 'Some object'
    ],
);
is_deeply \@args, \@expected,
  '... and default "use" and "name" parameters should be added';

$DECLARE->new(
    meta => [
        key         => 'some_object',
        plural_name => 'Some objects',
        name        => 'Some name',
    ],
);

@expected = (
    'meta' => [
        key         => 'some_object',
        plural_name => 'Some objects',
        name        => 'Some name',
        use         => 'Kinetic::Meta',
    ],
);
is_deeply \@args, \@expected,
  '... but name should not be overridden if it is provided';

# test attribute defaults

$DECLARE->new(
    meta => [
        key         => 'some_object',
        plural_name => 'Some objects',
    ],
    attributes => [
        value => {},
    ],
);

@expected = (
    meta => [
        key         => 'some_object',
        plural_name => 'Some objects',
        use         => 'Kinetic::Meta',
        name        => 'Some object'
    ],
    attributes => [
        value => {
            'label' => 'Value',
            'type'  => $TYPE_STRING,
        }
    ]
);
is_deeply \@args, \@expected,
  'Attribute "label" and "type" should have the correct defaults';

$DECLARE->new(
    meta => [
        key         => 'some_object',
        plural_name => 'Some objects',
    ],
    attributes => [
        value => {
            'label' => 'Some Value',
            'type'  => $TYPE_WHOLE,
        },
    ],
);

@expected = (
    meta => [
        key         => 'some_object',
        plural_name => 'Some objects',
        use         => 'Kinetic::Meta',
        name        => 'Some object'
    ],
    attributes => [
        value => {
            'label' => 'Some Value',
            'type'  => $TYPE_WHOLE,
        }
    ]
);
is_deeply \@args, \@expected,
  '... but they should not be overridden if supplied';
