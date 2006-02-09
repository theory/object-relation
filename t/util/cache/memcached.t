#!/usr/bin/perl -w

# $Id: workflow.t 2582 2006-02-07 02:27:45Z theory $

use strict;

use Test::More;

use Test::Exception;
use Kinetic::Util::Config qw/CACHE_OBJECT/;

my $CACHE;

BEGIN {
    $CACHE = 'Kinetic::Util::Cache::Memcached';
    if ( CACHE_OBJECT ne $CACHE ) {
        plan skip_all => "Not testing the memcached based caching";
    }
    else {

        plan 'no_plan';
        #plan tests => 9;
    }
    use_ok $CACHE or die;
}

# must be specified *after* a possible no_plan
use Test::NoWarnings;    # Adds an extra test.

can_ok $CACHE, 'new';
ok my $cache = $CACHE->new, '... and calling it should succeed';
isa_ok $cache, $CACHE, '... and the object it returns';

foreach my $method (qw/get set add/) {
    can_ok $cache, $method;
    throws_ok { $cache->$method }
      'Kinetic::Util::Exception::Fatal::Unimplemented',
      '... but calling it should throw an unimplemented error';
}
