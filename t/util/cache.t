#!/usr/bin/perl -w

# $Id: workflow.t 2582 2006-02-07 02:27:45Z theory $

use strict;

#use Test::More 'no_plan';

use Test::More tests => 16;
use Test::Exception;
use Test::NoWarnings;    # Adds an extra test.

my $CACHE;

BEGIN {
    $CACHE = 'Kinetic::Util::Cache';
    use_ok $CACHE or die;
}

can_ok $CACHE, 'new';
ok my $cache = $CACHE->new, '... and calling it should succeed';
isa_ok $cache, $CACHE, '... and the object it returns';
cmp_ok ref($cache), 'ne', $CACHE, '... but it is actually a subclass';

$cache = bless {}, $CACHE;    # Force base class testing

foreach my $method (qw/get set add empty remove/) {
    can_ok $cache, $method;
    throws_ok { $cache->$method }
      'Kinetic::Util::Exception::Fatal::Unimplemented',
      '... but calling it should throw an unimplemented error';
}
