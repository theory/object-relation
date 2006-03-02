package TEST::Kinetic::UI::Catalyst;

use strict;
use warnings;
use Test::More;
use Test::Output;

use aliased 'Kinetic::Party::User';
use base 'TEST::Class::Kinetic';
use aliased 'Test::WWW::Mechanize::Catalyst', 'Mech', 'Kinetic::UI::Catalyst';

use Readonly;
Readonly my $TIMESTAMP =>
  '\[\w{3}\s\w{3}\s[123 ]\d\s\d{2}:\d{2}:\d{2}\s\d{4}\] \[catalyst\]';

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
    ? 0
    : "Not testing Data Stores"
  )
  if caller;    # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

use aliased 'Test::MockModule';

sub class_key {'kinetic'}
sub class     { Kinetic::Meta->for_key( shift->class_key ) }

sub dbh {
    my $self = shift;
    return $self->{dbh} unless @_;
    $self->{dbh} = shift;
    return $self;
}

sub setup : Test(setup) {
    my $self = shift;
    return $self unless $self->dev_testing;

    my $store = Kinetic::Store->new;

    if ( $store->isa('Kinetic::Store::DB') ) {

        # Set up a mocked database handle with a running transaction.
        my $db_mock = MockModule->new('Kinetic::Store::DB');
        $self->{db_mock} = $db_mock;
        my $dbh = $store->_dbh;

        $db_mock->mock( _dbh        => $dbh );
        $db_mock->mock( _begin_work => $store );
        $db_mock->mock( _commit     => $store );
        $db_mock->mock( _rollback   => $store );

        $dbh->begin_work;
        $self->dbh($dbh);
    }

    $self->{user}{ovid} = User->new(
        username => 'ovid',
        password => 'ovidius',
    )->save;
    $self->{user}{theory} = User->new(
        username => 'theory',
        password => 'theory',
    )->save;

    # XXX Add support for non-DB data stores when/if necessary.
    return $self;
}

sub teardown : Test(teardown) {
    my $self = shift;
    return $self unless $self->dev_testing;

    # If we mocked DB and have a db handle, unmock and rollback.
    my $db_mock = delete $self->{db_mock} or return $self;
    $db_mock->unmock_all;
    my $dbh = $self->dbh or return $self;
    $dbh->rollback;

    # XXX Add support for non-DB data stores when/if necessary.
    return $self;
}

sub shutdown : Test(shutdown) {
    my $self = shift;
    return $self unless $self->dev_testing;

    # If there's a database handle, disconnect!
    my $dbh = $self->dbh or return $self;
    $dbh->disconnect;

    # XXX Add support for non-DB data stores when/if necessary.
    return $self;
}

sub _test_load : Test(1) {
    my $self      = shift;
    my $class_pkg = $self->test_class;
    use_ok $class_pkg or die;
}

sub login_logout_roundtrip : Test(17) {
    my $self = shift;
    my $mech = Mech->new;
    stderr_like {
        $mech->get_ok( 'http://localhost/', 'basic login should succeed' );
      }
      qr/$TIMESTAMP \[debug\] Can't login a user without a username/,
      '... telling us that we need to login';
    $mech->content_lacks(
        'Login failed.',
        '... but should not tell us the login failed the first time we are there'
    );
    stderr_like {
        ok $mech->submit_form(
            form_name => 'login',
            fields    => {
                username => 'No such user',
                password => 'No such pass',
            },
          ),
          'Submitting the form with bad credentials should succeed';
      }
      qr/$TIMESTAMP \[debug\] login failed/,
      '... and we should get a proper log message';
    $mech->content_contains(
        'Login failed.',
        '... and the user should be told the login failed'
    );
    my $response;
    stderr_like {
        ok $response = $mech->submit_form(
            form_name => 'login',
            fields    => {
                username => 'ovid',
                password => 'ovidius',
            },
          ),
          'Submitting the form with good credentials should succeed';
      }
      qr/$TIMESTAMP \[debug\] login succeeded/,
      '... and we should get a proper log message';
    is $response->code, 200, '... and the request should succeed';

    $mech->content_lacks(
        'Login failed.',
        '... and we should not get a "Login failed" message'
    );
    $mech->content_contains(
        'Logout',
        'We should have a logout label'
    );
    ok my @links = $mech->find_all_links( url_regex => qr/logout/ ),
      '... and a link to go with it';

    # Note that we're not testing the number of logout links because it's
    # possibly we'll want more than one in the future (top and bottom?)
    my $link = shift @links;
    is $link->url,  '/logout', '... and it should have the correct URL';
    is $link->text, 'Logout',  '... and the correct text';

    stderr_like {
        $mech->follow_link_ok(
            { text => 'Logout' },
            'We should be able to logout'
        );
      }
      qr/$TIMESTAMP \[debug\] Can't login a user without a username/,
      '... telling us that we need to login';
    $mech->content_lacks(
        'Login failed.',
        '... but should not tell us the login failed'
    );
}

sub mutiple_logins : Test(15) {
    my $self = shift;
    my $mech = Mech->new;
    my $response;
    my $url = 'http://localhost/search/';
    stderr_like {
        $mech->get_ok(
            $url,
            'Trying to fetch a page before we log in should succeed'
        );
      }
      qr/$TIMESTAMP \[debug\] Can't login a user without a username/,
      '... telling us that we need to login';
    stderr_like {
        ok $response = $mech->submit_form(
            form_name => 'login',
            fields    => {
                username => 'ovid',
                password => 'ovidius',
            },
          ),
          'Submitting the form with good credentials should succeed';
      }
      qr/$TIMESTAMP \[debug\] login succeeded/,
      '... and we should get a proper log message';

    is $response->code, 200, '... and the request should succeed';

    $mech->content_contains(
        'Logout',
        'We should have a logout label'
    );
    $mech->content_contains(
        'ovid',
        '... and the username of the logged in user'
    );
    $mech->get_ok(
        "$url?username=theory&password=theory",
        'Trying to force a different user should succeed'
    );

    $mech->content_contains(
        'Logout',
        'We should have a logout label'
    );

    # testing that only the "official" auth mechanism works
    $mech->content_contains( '<p>ovid <a href="/logout">Logout</a></p>',
         '... but only the old user should remain' );

    stderr_like {
        $mech->follow_link_ok(
            { text => 'Logout' },
            'We should be able to logout'
        );
      }
      qr/$TIMESTAMP \[debug\] Can't login a user without a username/,
      '... telling us that we need to login';
    stderr_like {
        ok $response = $mech->submit_form(
            form_name => 'login',
            fields    => {
                username => 'theory',
                password => 'theory',
            },
          ),
          'Logging in with a different user should succeed';
      }
      qr/$TIMESTAMP \[debug\] login succeeded/,
      '... and we should get a proper log message';

    $mech->content_contains( '<p>theory <a href="/logout">Logout</a></p>',
         '... with the new user being logged in' );
}

1;
