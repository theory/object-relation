package TEST::Kinetic::Store;

# $Id: SQLite.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;

use aliased 'Test::MockModule';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Store' => 'Store', ':all';

use aliased 'Kinetic::Util::Iterator';
use aliased 'Kinetic::Util::State';
use aliased 'Kinetic::DateTime';
use aliased 'Kinetic::DateTime::Incomplete';
use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

__PACKAGE__->runtests unless caller;

sub _num_recs {
    my ($test, $table) = @_;
    my $result = $test->{dbh}->selectrow_arrayref("SELECT count(*) FROM $table");
    return $result->[0];
}

sub setup : Test(setup) {
    my $test = shift;
    my $store = Store->new;
    $test->{dbh} = $store->_dbh;
    $test->{dbh}->begin_work;
    $test->{dbi_mock} = MockModule->new('DBI::db', no_auto => 1);
    $test->{dbi_mock}->mock(begin_work => 1);
    $test->{dbi_mock}->mock(commit => 1);
    $test->{db_mock} = MockModule->new('Kinetic::Store::DB');
    $test->{db_mock}->mock(_dbh => $test->{dbh});
    my $foo = One->new;
    $foo->name('foo');
    Store->save($foo);
    my $bar = One->new;
    $bar->name('bar');
    Store->save($bar);
    my $baz = One->new;
    $baz->name('snorfleglitz');
    Store->save($baz);
    $test->{test_objects} = [$foo, $bar, $baz];
}

sub teardown : Test(teardown) {
    my $test = shift;
    delete($test->{dbi_mock})->unmock_all;
    $test->{dbh}->rollback;
    delete($test->{db_mock})->unmock_all;
}

sub shutdown : Test(shutdown) {
    my $test = shift;
    $test->{dbh}->disconnect;
}

sub _clear_database {
    # Call this method if you have a test which needs an empty database.
    my $test = shift;
    $test->{dbi_mock}->unmock_all;
    $test->{dbh}->rollback;
    $test->{dbh}->begin_work;
    $test->{dbi_mock}->mock(begin_work => 1);
    $test->{dbi_mock}->mock(commit => 1);
}

sub save : Test(10) {
    my $test  = shift;
    $test->_clear_database;
    my $one = One->new;
    $one->name('Ovid');
    $one->description('test class');

    can_ok Store, 'save';
    my $dbh = $test->{dbh};
    my $result = $dbh->selectrow_hashref('SELECT id, guid, name, description, state, bool FROM one');
    ok ! $result, 'We should start with a fresh database';
    ok Store->save($one), 'and saving an object should be successful';
    $result = $dbh->selectrow_hashref('SELECT id, guid, name, description, state, bool FROM one');
    $result->{state} = State->new($result->{state});
    # XXX this works, but it might be a bit fragile
    is_deeply $one, $result, 'and the data should match what we pull from the database';
    is $test->_num_recs('one'), 1, 'and we should have one record in the view';

    my $two = One->new;
    $two->name('bob');
    $two->description('some description');
    Store->save($two);
    is $test->_num_recs('one'), 2, 'and we should have two records in the view';
    $result = $dbh->selectrow_hashref('SELECT id, guid, name, description, state, bool FROM one WHERE name = \'bob\'');
    $result->{state} = State->new($result->{state});
    is_deeply $two, $result, 'and the data should match what we pull from the database';
    $two->name('beelzebub');
    Store->save($two);
    my $guid = $dbh->quote($two->guid);
    $result = $dbh->selectrow_hashref("SELECT id, guid, name, description, state, bool FROM one WHERE guid = $guid");
    $result->{state} = State->new($result->{state});
    is_deeply $two, $result, 'and we should be able to update data';
    is $result->{name}, 'beelzebub', 'and return the correct results';
    is $test->_num_recs('one'), 2, 'without the number of records changing';
}

sub constructor : Test(5) {
    my $test = shift;
    (my $class = ref $test) =~ s/^TEST:://;
    can_ok $class => 'new';
    ok my $store = $class->new;
    isa_ok $store, $class;
    isa_ok $store, 'Kinetic::Store';

    my $store2 = $class->new;
    isnt "$store", "$store2", '... and a singleton should not be returned';
}

sub does_import : Test(71) {
    can_ok Store, 'import';
    # comparison
    foreach my $sub (qw/EQ NOT LIKE GT LT GE LE NE MATCH/) {
        can_ok __PACKAGE__, $sub;
        no strict 'refs';
        my $result = [$sub->(7)->()];
        is_deeply $result, [$sub, 7],
            'and it should return its name and args';
    }
    # sorting
    foreach my $sub (qw/ASC DESC/) {
        can_ok __PACKAGE__, $sub;
        no strict 'refs';
        my $result = [$sub->()->()];
        is_deeply $result, [$sub],
            'and it should return its name and args';
    }
    # logical
    foreach my $sub (qw/AND OR ANY/) {
        can_ok __PACKAGE__, $sub;
        no strict 'refs';
        my $result = [$sub->(qw/foo bar/)->()];
        is_deeply $result, [$sub, [qw/foo bar/]],
            'Not yet sure of the semantics of the logical operators';
    }
    {
        package Foo;
        use Kinetic::Store ':comparison';
        foreach my $sub (qw/EQ NOT LIKE GT LT GE LE NE MATCH/) {
            TEST::Kinetic::Store::ok UNIVERSAL::can(Foo => $sub),
                '":comparison" should export the correct methods';
        }
        foreach my $sub (qw/AND OR ANY ASC DESC/) {
            TEST::Kinetic::Store::ok ! UNIVERSAL::can(Foo => $sub),
                '":comparison" should not export unrequested methods';
        }
    }
    {
        package Bar;
        use Kinetic::Store ':logical';
        foreach my $sub (qw/AND OR ANY/) {
            TEST::Kinetic::Store::ok UNIVERSAL::can(Bar => $sub),
                '":logical" should export the correct methods';
        }
        foreach my $sub (qw/EQ NOT LIKE GT LT GE LE ASC DESC NE MATCH/) {
            TEST::Kinetic::Store::ok ! UNIVERSAL::can(Bar => $sub),
                '":logical" should not export unrequested methods';
        }
    }
    {
        package Baz;
        use Kinetic::Store ':sorting';
        foreach my $sub (qw/ASC DESC/) {
            TEST::Kinetic::Store::ok UNIVERSAL::can(Baz => $sub),
                '":sorting" should export the correct methods';
        }
        foreach my $sub (qw/EQ NOT LIKE GT LT GE LE AND OR ANY NE MATCH/) {
            TEST::Kinetic::Store::ok ! UNIVERSAL::can(Baz => $sub),
                '":sorting" should not export unrequested methods';
        }
    }
}

1;
