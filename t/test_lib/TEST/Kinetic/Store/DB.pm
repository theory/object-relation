package TEST::Kinetic::Store::DB;

# $Id$

use strict;
use warnings;

use Test::More;
use base 'TEST::Kinetic::Store';
use lib 't/lib';
use TestApp::Simple::One;
use aliased 'Test::MockModule';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Store::DB' => 'Store';

__PACKAGE__->runtests;

sub save : Test(3) {
    my $test = shift;
    my $mock = MockModule->new(Store);
    my ($update, $insert);
    $mock->mock(_update => sub { $update = 1; $insert = 0 });
    $mock->mock(_insert => sub { $update = 0; $insert = 1 });
    my $object = {};
    can_ok Store, 'save';
    Store->save($object);
    ok $insert, 'and calling it with an object with no id key should call _insert()';
    $object->{id} = 1;
    Store->save($object);
    ok $update, 'and calling it with an object with an id key should call _update()';
}

sub insert : Test(7) {
    my $mock_store = MockModule->new(Store);
    my ($SQL, $BIND);
    $mock_store->mock(_do_sql =>
        sub {
            my $self = shift;
            $SQL     = shift;
            $BIND    = shift;
            $self
        }
    );

    my $class = Meta->for_key('one');
    my $ctor  = $class->constructors('new');
    my $one = $ctor->call($class->package);
    $mock_store->mock(_set_id => sub { $one->{id} = 2002 } );
    $one->name('Ovid');
    $one->description('test class');

    can_ok Store, '_insert';
    my $expected    = q{INSERT INTO one (guid, name, description, state, bool) VALUES (?, ?, ?, ?, ?)};
    my $bind_params = [
        'Ovid',
        'test class',
        '1', # state: Active
        '1'  # bool
    ];
    ok ! exists $one->{id}, 'And a new object should not have an id';
    ok Store->_insert($one),
        'and calling it should succeed';
    is $SQL, $expected,
        'and it should generate the correct sql';
    my $uuid = shift @$BIND;
    is_deeply $BIND, $bind_params,
        'and the correct bind params';
    ok exists $one->{id}, 'and an id should be created';
    is $one->{id}, 2002, 'and it should have the last insert id the database returned';
}

sub update : Test(6) {
    my $mock_store = MockModule->new(Store);
    my ($SQL, $BIND);
    $mock_store->mock(_do_sql =>
        sub {
            my $self = shift;
            $SQL     = shift;
            $BIND    = shift;
            $self
        }
    );

    my $class = Meta->for_key('one');
    my $ctor  = $class->constructors('new');
    my $one = $ctor->call($class->package);
    $one->name('Ovid');
    $one->description('test class');
    can_ok Store, '_update';
    $one->{id} = 42;
    # XXX The guid should not change, should it?  I should
    # exclude it from this?
    my $expected = "UPDATE one SET guid = ?, name = ?, description = ?, "
                  ."state = ?, bool = ? WHERE guid = ?";
    my $bind_params = [
        'Ovid',
        'test class',
        '1', # state: Active
        '1'  # bool
    ];
    ok Store->_update($one),
        'and calling it should succeed';
    is $SQL, $expected,
        'and it should generate the correct sql';
    my $uuid  = shift @$BIND;
    my $uuid2 = pop @$BIND;
    is $uuid, $uuid2, 'and the uuid should not change if we have not changed it';
    is_deeply $BIND, $bind_params,
        'and the correct bind params';
    is $one->{id}, 42, 'and the private id should not be changed';
}
