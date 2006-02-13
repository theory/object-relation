#!/usr/bin/perl -w

# $Id: workflow.t 2582 2006-02-07 02:27:45Z theory $

use strict;

#use Test::More 'no_plan';
use Test::More tests => 29;
use Test::Exception;
use Test::NoWarnings;    # Adds an extra test.

use Kinetic::Build::Test cache => { expires => 2 };
use Kinetic::Util::Config qw(CACHE_OBJECT);
my $CACHE;

BEGIN {
    $CACHE = 'Kinetic::Util::Cache';
    use_ok $CACHE or die;
}

# Force base class testing

my $cache = bless {}, $CACHE;

foreach my $method (qw/get set add remove/) {
    can_ok $cache, $method;
    throws_ok { $cache->$method }
      'Kinetic::Util::Exception::Fatal::Unimplemented',
      '... but calling it should throw an unimplemented error';
}

# Force factory testing

can_ok $CACHE, 'new';
ok $cache = $CACHE->new, '... and calling it should succeed';
isa_ok $cache, $CACHE, '... and the object it returns';
cmp_ok ref($cache), 'ne', $CACHE, '... but it is actually a subclass';

my @IDS = ();

END {
    my $cache = $CACHE->new;
    $cache->remove($_) foreach @IDS;
}
{

    package Some::Object;

    my $id = 1;

    sub new {
        my $class = shift;
        $id++;
        push @IDS => $id;
        return bless { id => $id }, $class;
    }

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

$CACHE = CACHE_OBJECT;

$cache = $CACHE->new;    # XXX reset the expire time

# we need to call this first or else a full run of the test suite might
# encounter a previously cached object.
#can_ok $cache, 'clear';
#ok $cache->clear, '... and calling it should succeed';

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
$ENV{DEBUG} = 1;
ok !$cache->add( $soldier->uuid, $soldier ),
  '... and trying to add() an existing object should fail';
$ENV{DEBUG} = 0;

my $soldier2 = Some::Object->new;
$soldier2->name('Ovid')->rank('Unlikely');
ok $cache->add( $soldier2->uuid, $soldier2 ),
  '... and trying to add() a non-cached object should succceed';
is_deeply $soldier2, $cache->get( $soldier2->uuid ),
  '... and we should be able to fetch it from the cache';

#ok $cache->clear, 'Calling clear() after adding objects should succeed';
#ok !$cache->get( $soldier->uuid ),
#  '... and fetching objects from the cache should then fail';

#ok $cache->set( $soldier->uuid, $soldier ),
#  '... and we should be able to set objects after clearing the cache';
#is_deeply $cache->get( $soldier->uuid ), $soldier, '... and fetch them again';

my $soldier3 = Some::Object->new;
$cache->set($soldier3->uuid, $soldier);

diag "Sleeping a bit to test cache expiration"
    if $ENV{TEST_VERBOSE};

sleep 2 * $CACHE->_expire_time_in_seconds();
ok !$cache->get( $soldier3->uuid ), '... and items should expire properly';

ok $cache->set( $soldier3->uuid, $soldier3 ),
  '... and adding it back to the cache should work';
is_deeply $cache->get( $soldier3->uuid ), $soldier3,
  '... and we should be able to fetch it again';

can_ok $cache, 'remove';
ok $cache->remove( $soldier->uuid ),
  '... and we should be able to remove items from the cache';
ok !$cache->get( $soldier->uuid ), '... and they should be gone';
