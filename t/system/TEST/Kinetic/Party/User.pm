package TEST::Kinetic::Party::User;

# $Id$

use strict;
use warnings;
use Test::Exception;

use base 'TEST::Kinetic::Party::Person';
use Test::More;

sub class_key { 'usr' }

sub attr_values {
    return {
        username => 'larry',
        password => 'yrral',
    }
}

sub test_password : Test(12) {
    my $self = shift;
    ok my $user = Kinetic::Party::User->new(
        username => 'foody',
        password => 'ydoof',
    ), 'Create a new user object';

    can_ok $user, 'compare_password';
    ok $user->compare_password('ydoof'), 'The password should check out';
    ok !$user->compare_password('bad'), 'A bad password should not';

    throws_ok { $user->password('a') }
        'Kinetic::Util::Exception::Error::Password',
        'A short password should throw an exception';
    like $@->error, qr/Password must be as least \d+ characters/,
        'And it should have the proper message';

    throws_ok { $user->password }
        'Kinetic::Util::Exception::Fatal::Attribute',
        'Fetching the password should throw an exception';
    like $@->error, qr/Attribute .password. is write-only/,
        'And it should have the proper message';

    # Make sure that it still works after a save.
    return 'Not testing Data Stores' unless $self->dev_testing;

    ok $user->save, 'Save the user object';
    ok $user = Kinetic::Party::User->lookup( username => 'foody' ),
        'Look up the user by username';
    ok $user->compare_password('ydoof'), 'The password should still check out';
    ok !$user->compare_password('bad'), 'A bad password still should not';
}

1;
__END__
