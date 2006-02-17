#!/usr/bin/perl

use strict;
use warnings;

use Kinetic::Util::Cache;
use Test::More tests => 9;

{

    package Faux::User;

    sub new {
        my ( $class, $user ) = @_;
        bless { user => $user }, $class;
    }

    sub name {
        my $self = shift;
        return "Mr. $self->{user}";
    }
}

{

    package CacheTestApp;

    use Kinetic::Util::Config qw(:cache);
    use Kinetic::UI::Catalyst::Cache;
    use Catalyst CACHE_CATALYST_CLASS->session_class,
      qw( Session Session::State::Cookie Session::Store::File );

    use Test::More;
    use Test::Exception;
    use aliased 'Test::MockModule';

    sub store_in_cache : Local {
        my ( $self, $c ) = @_;

        my $cache
          = 'Catalyst::Plugin::' . CACHE_CATALYST_CLASS->session_class;
        isa_ok $c, $cache, 'And the context';
        can_ok $c, 'session';
        my $user = Faux::User->new('Bob');
        $c->session->{user} = $user;
        $c->res->body("ok");
    }

    sub retrieve_from_cache : Local {
        my ( $self, $c ) = @_;

        my $cache
          = 'Catalyst::Plugin::' . CACHE_CATALYST_CLASS->session_class;
        isa_ok $c, $cache, 'And the context';
        can_ok $c, 'session';
        ok my $user = $c->session->{user},
          'We should be able to fetch items from the cache';
        isa_ok $user, 'Faux::User', '... and the object it returns';
        is $user->name, 'Mr. Bob', '... and it should be the correct object';
        $c->res->body("ok");
    }

    __PACKAGE__->config( { CACHE_CATALYST_CLASS->config } );
    __PACKAGE__->setup;
}

use aliased 'Test::WWW::Mechanize::Catalyst' => 'Mech', 'CacheTestApp';
my $mech = Mech->new;
$mech->get_ok( 'http://localhost/store_in_cache',
    'store_in_cache should succeed' );
$mech->get_ok(
    'http://localhost/retrieve_from_cache',
    'retrieve_from_cache should succeed'
);
