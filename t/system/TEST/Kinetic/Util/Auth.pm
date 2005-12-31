package TEST::Kinetic::Util::Auth;

use strict;
use warnings;
use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use aliased 'Kinetic::Party::User';

sub test_auth : Test(13) {
    my $self = shift;
    ok my $auth = Kinetic::Util::Auth->new, 'Get a new auth object';
    is $auth, Kinetic::Util::Auth->new, 'It should be a singleton';

    # Test _authenticate.
    throws_ok { $auth->_authenticate }
        'Kinetic::Util::Exception::Fatal::Unimplemented',
        '_authenticate() should be unimplemented';
    like $@, qr/._authenticate. must be overridden in a subclass/,
        'It must throw the proper error message';

    # Create a user to authenticate against.
    ok my $user = User->new(
        username => 'damian',
        password => 'naimad',
    ), 'Create a new user object';
    isa_ok $user, User, 'the user';

    return 'Not testing Data Stores' unless $self->dev_testing;
    ok $user->save, 'Save the user object';

    # Try to authenticate the user.
    ok $user =  $auth->authenticate('damian', 'naimad'),
        'Authenticate the user';
    isa_ok $user, User, 'the authenticated user';

    # Try a bad username.
    throws_ok { $auth->authenticate('larry', 'naimad') }
        'Kinetic::Util::Exception::Error::Auth',
        'We should get an exception for a bad username';
    like $@, qr/Authentication failed/,
        '... And it should have the proper message';

    # Try a bad password.
    throws_ok { $auth->authenticate('damian', 'larry') }
        'Kinetic::Util::Exception::Error::Auth',
        'We should get an exception for a bad password';
    like $@, qr/Authentication failed/,
        '... And it should have the proper message';
}

1;
