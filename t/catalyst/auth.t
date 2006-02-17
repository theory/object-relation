#!/usr/bin/perl

use strict;
use warnings;

use Kinetic::Util::Auth;
use Test::More tests => 17;

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

    package AuthTestApp;

    use base 'Kinetic::UI::Catalyst::Auth';

    use Kinetic::Util::Config qw(:cache);
    use Kinetic::UI::Catalyst::Cache;
    use Catalyst CACHE_CATALYST_CLASS->session_class,
      qw( Session Session::State::Cookie Session::Store::File );

    use Test::More;
    use Test::Exception;
    use aliased 'Test::MockModule';

    use Digest::MD5 qw/md5/;

    my $authenticate = sub {
        my ( $class, $user, $pass ) = @_;
        $pass = scalar reverse $pass;
        return unless $user eq $pass;
        return Faux::User->new($user);
    };

    my $SESSIONID;

    sub basic_login : Local {
        my $mock_auth = MockModule->new('Kinetic::Util::Auth');
        $mock_auth->mock( authenticate => $authenticate );

        my ( $self, $c ) = @_;

        can_ok $c, 'login';
        ok !$c->user, "We should not have a user to start with.";
        ok !$c->login( "ovid", "bad_pass" ),
          "... and logging in with a bad pass should fail";

        ok $c->login( "ovid", "divo" ),
          "... and logging in with a good pass should succeed";
        ok my $user = $c->user, '... and we should have a user object';
        isa_ok $user, 'Faux::User', '... and the object it returns';
        is $user->name, 'Mr. ovid', '... and it should have the correct data';
        is_deeply $c->session->{user}, $user,
          '... and the user should in the session';

        ok $c->login( 'bob the angry flower', 'rewolf yrgna eht bob' ),
          'A different user should be able to login on the same session';
        is $c->user->name, 'Mr. bob the angry flower',
          '... and this should replace the old user';

        can_ok $c, 'logout';
        my $old_sessionid = $c->sessionid;
        $c->logout;
        ok !$c->user,
          "... and we should not longer have a user after logging out";
        cmp_ok $c->sessionid, 'ne', $old_sessionid,
          '... and we should have a new session id';

        $c->login('ovid', 'divo'); # Leave it like this for the next test
        $c->res->body("ok");
    }

    sub next_login : Local {
        my ($self, $c) = @_;
        ok my $user = $c->user, 'We should have a user stored in the session';
        is $user->name, 'Mr. ovid', '... and it should be the correct user';
        $c->res->body("ok");
    }
    __PACKAGE__->config( { CACHE_CATALYST_CLASS->config } );
    __PACKAGE__->setup;
}

use aliased 'Test::WWW::Mechanize::Catalyst' => 'Mech', 'AuthTestApp';
my $mech = Mech->new;
$mech->get_ok( 'http://localhost/basic_login', 'basic_login should succeed' );
$mech->get_ok( 'http://localhost/next_login', 'next_login should succeed' );
