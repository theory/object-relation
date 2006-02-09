#!/usr/bin/perl -w

# $Id: workflow.t 2582 2006-02-07 02:27:45Z theory $

use strict;

use Test::More;

use Test::Exception;
use Kinetic::Util::Config qw/CACHE_OBJECT/;

my $CACHE;

BEGIN {
    $CACHE = 'Kinetic::Util::Cache::File';
    if ( CACHE_OBJECT ne $CACHE ) {
        plan skip_all => "Not testing the memcached based caching";
    }
    else {

        #plan 'no_plan';
        plan tests => 26;
    }
    use_ok $CACHE or die;
}
use Test::NoWarnings;    # Adds an extra test.

{

    package Some::Object;

    my $id = 1;
    sub new { bless { id => $id++ }, shift }

    sub uuid { shift->{id} }

    sub name {
        my $self = shift;
        return $self->{name} unless @_;
        $self->{name} = shift;
        return $self;
    }

    sub rank {
        my $self = shift;
        return $self->{rank} unless @_;
        $self->{rank} = shift;
        return $self;
    }

    sub full { return join ' ', @{ +shift }{qw/rank name/} }
}

{
    no warnings 'redefine';
    no strict 'refs';
    *{"${CACHE}::_expire_time_in_seconds"} = sub {2};
}
can_ok $CACHE, 'new';
ok my $cache = $CACHE->new, '... and calling it should succeed';
isa_ok $cache, $CACHE, '... and the object it returns';

# we need to call this first or else a full run of the test suite might
# encounter a previously cached object.
can_ok $cache, 'empty';
ok $cache->empty, '... and calling it should succeed';

my $soldier = Some::Object->new;
$soldier->name('Bob')->rank('Private');

can_ok $cache, 'set';
ok $cache->set( $soldier->uuid, $soldier ),
  '... and storing an object in the cache should succeed';

can_ok $cache, 'get';
ok my $copy = $cache->get( $soldier->uuid ),
  '... and fetching an object from the cache should succeed';
is_deeply $soldier, $copy, '... and the copy should match the original';

can_ok $cache, 'add';
ok !$cache->add( $soldier->uuid, $soldier ),
  '... and trying to add() an existing object should fail';

my $soldier2 = Some::Object->new;
$soldier2->name('Ovid')->rank('Unlikely');
ok $cache->add( $soldier2->uuid, $soldier2 ),
  '... and trying to add() a non-cached object should succceed';
is_deeply $soldier2, $cache->get( $soldier2->uuid ),
  '... and we should be able to fetch it from the cache';

ok $cache->empty, 'Calling empty() after adding objects should succeed';
ok !$cache->get( $soldier->uuid ),
  '... and fetching objects from the cache should then fail';

ok $cache->set( $soldier->uuid, $soldier ),
  '... and we should be able to set objects after emptying the cache';
is_deeply $cache->get( $soldier->uuid ), $soldier, '... and fetch them again';

diag "Sleeping a bit to test cache expiration";

sleep 2 * $CACHE->_expire_time_in_seconds();
ok !$cache->get( $soldier->uuid ), '... and items should expire properly';

ok $cache->set( $soldier->uuid, $soldier ),
  '... and adding it back to the cache should work';
is_deeply $cache->get( $soldier->uuid ), $soldier,
  '... and we should be able to fetch it again';

can_ok $cache, 'remove';
ok $cache->remove( $soldier->uuid ),
  '... and we should be able to remove items from the cache';
ok !$cache->get( $soldier->uuid ), '... and they should be gone';
