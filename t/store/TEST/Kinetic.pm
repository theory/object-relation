package TEST::Kinetic;

# $Id: Store.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Encode qw(is_utf8);

use aliased 'Test::MockModule';

use Class::Trait qw(TEST::Kinetic::Traits::Store);
use Kinetic::Store qw/:all/;
use aliased 'Kinetic::Util::Iterator';
use aliased 'Kinetic::Util::State';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';    # contains a TestApp::Simple::One object

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
    ? 0
    : "Not testing Data Stores"
  )
  if caller;    # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub _all_items {
    my ( $test, $iterator ) = @_;
    my @iterator;
    while ( my $object = $iterator->next ) {
        push @iterator => $test->force_inflation($object);
    }
    return @iterator;
}

sub _should_run {
    my $test    = shift;
    my $store   = Kinetic::Store->new;
    my $package = ref $store;
    return ref $test eq "TEST::$package";
}

sub lookup : Test(8) {
    my $test = shift;
    return unless $test->_should_run;

    $test->clear_database;
    my $one = One->new;
    $one->name('divO');
    $one->description('ssalc tset');
    $one->save;
    can_ok One, 'lookup';
    my $thing = One->lookup( uuid => $one->uuid );
    is_deeply $test->force_inflation($thing), $one,
      'and it should return the correct object';

    foreach my $method (qw/name description uuid state/) {
        is $thing->$method, $one->$method, "$method() should behave the same";
    }
    throws_ok { One->lookup( no_such_attribute => 1 ) }
      'Kinetic::Util::Exception::Fatal::Attribute',
      'but it should croak if you search for a non-existent attribute';
    throws_ok { One->lookup( name => 1 ) }
      'Kinetic::Util::Exception::Fatal::Attribute',
      'or if you search on a non-unique field';
}

sub save : Test(10) {
    my $test = shift;
    return unless $test->_should_run;
    $test->clear_database;
    my $one = One->new;
    $one->name('Ovid');
    $one->description('test class');

    can_ok One, 'save';
    my $dbh    = $test->dbh;
    my $result =
      $dbh->selectrow_hashref(
        'SELECT id, uuid, name, description, state, bool FROM one');
    ok !$result, 'We should start with a fresh database';
    ok $one->save, 'and saving an object should be successful';
    $result =
      $dbh->selectrow_hashref(
        'SELECT id, uuid, name, description, state, bool FROM one');
    $result->{state} = State->new( $result->{state} );

    # XXX this works, but it might be a bit fragile
    is_deeply $one, $result,
      'and the data should match what we pull from the database';
    is $test->_num_recs('one'), 1, 'and we should have one record in the view';

    my $one_prime = One->new;
    $one_prime->name('bob');
    $one_prime->description('some description');
    $one_prime->save;
    is $test->_num_recs('one'), 2,
      'and we should have one_prime records in the view';
    $result =
      $dbh->selectrow_hashref(
'SELECT id, uuid, name, description, state, bool FROM one WHERE name = \'bob\''
      );
    $result->{state} = State->new( $result->{state} );
    is_deeply $one_prime, $result,
      'and the data should match what we pull from the database';
    $one_prime->name('beelzebub');
    $one_prime->save;
    my $uuid = $dbh->quote( $one_prime->uuid );
    $result =
      $dbh->selectrow_hashref(
"SELECT id, uuid, name, description, state, bool FROM one WHERE uuid = $uuid"
      );
    $result->{state} = State->new( $result->{state} );
    is_deeply $one_prime, $result, 'and we should be able to update data';
    is $result->{name}, 'beelzebub', 'and return the correct results';
    is $test->_num_recs('one'), 2, 'without the number of records changing';
}

sub basic_query : Test(19) {
    my $test = shift;
    return unless $test->_should_run;
    can_ok One, 'query';
    my ( $foo, $bar, $baz ) = $test->test_objects;
    foreach ( $foo, $bar, $baz ) {
        $_->name( $_->name . chr(0x100) );
        $_->save;
    }
    my $class = $foo->my_class;
    ok my $iterator = One->query, 'A query with only a class should succeed';
    my @results = $test->_all_items($iterator);
    is @results, 3, 'returning all instances in the class';

    foreach my $result (@results) {
        ok is_utf8( $result->name ),
          '... and the data should be unicode strings';
    }

    ok $iterator = One->query( name => $foo->name ),
      'and an exact match should succeed';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $test->force_inflation( $iterator->next ), $foo,
      'and the first item should match the correct object';
    ok !$test->force_inflation( $iterator->next ),
      'and there should be the correct number of objects';

    ok $iterator = One->query( name => $foo->name ),
      'We should also be able to call query as a class method';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $test->force_inflation( $iterator->next ), $foo,
      'and it should return the same results as an instance method';
    ok !$test->force_inflation( $iterator->next ),
      'and there should be the correct number of objects';

    ok $iterator = One->query( name => ucfirst $foo->name ),
      'Case-insensitive queries should work';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $test->force_inflation( $iterator->next ), $foo,
      'and they should return data even if the case does not match';

    $iterator = One->query( name => $foo->name, description => 'asdf' );
    ok !$test->force_inflation( $iterator->next ),
      'but querying for non-existent values will return no results';
    $foo->description('asdf');
    $foo->save;
    $iterator = One->query( name => $foo->name, description => 'asdf' );
    is_deeply $test->force_inflation( $iterator->next ), $foo,
      '... and it should be the correct results';
}

sub query_deleted : Test(7) {
    my $test = shift;
    return unless $test->_should_run;
    my ( $foo, $bar, $baz ) = $test->test_objects;
    my $class    = $foo->my_class;
    my $iterator = One->query;
    my @results  = $test->_all_items($iterator);
    is @results, 3, 'An empty query should return all records';

    $bar->delete->save;
    $iterator = One->query;
    @results  = $test->_all_items($iterator);
    is @results, 2, '... but it should not return deleted records';
    foreach my $object (@results) {
        cmp_ok $object->state, '>', State->DELETED,
          '... and the objects returned should have the correct state';
    }

    ok $iterator = One->query( state => EQ  0 + State->DELETED ),
      'Searching directly on state should succeed';
    @results = $test->_all_items($iterator);
    is @results, 1, '... and it should return the correct records';
    foreach my $object (@results) {
        cmp_ok $object->state, '==', State->DELETED,
          '... and the objects returned should have the correct state';
    }
}

sub string_query : Test(19) {
    my $test = shift;
    return unless $test->_should_run;
    can_ok One, 'query';
    my ( $foo, $bar, $baz ) = $test->test_objects;
    foreach ( $foo, $bar, $baz ) {
        $_->name( $_->name . chr(0x100) );
        $_->save;
    }
    ok my $iterator = One->query( STRING => '' ),
      'A query with only a class should succeed';
    my @results = $test->_all_items($iterator);
    is @results, 3, 'returning all instances in the class';

    foreach my $result (@results) {
        ok is_utf8( $result->name ),
          '... and the data should be unicode strings';
    }

    ok $iterator = One->query( STRING => "name => '@{[$foo->name]}'" ),
      'and an exact match should succeed';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $test->force_inflation( $iterator->next ), $foo,
      'and the first item should match the correct object';
    ok !$test->force_inflation( $iterator->next ),
      'and there should be the correct number of objects';

    ok $iterator = One->query( STRING => "name => '@{[$foo->name]}'" ),
      'We should also be able to call query as a class method';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $test->force_inflation( $iterator->next ), $foo,
      'and it should return the same results as an instance method';
    ok !$test->force_inflation( $iterator->next ),
      'and there should be the correct number of objects';

    ok $iterator = One->query( STRING => "name => '@{[ucfirst $foo->name]}'" ),
      'Case-insensitive queries should work';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $test->force_inflation( $iterator->next ), $foo,
      'and they should return data even if the case does not match';

    $iterator =
      One->query(
        STRING => "name => '@{[$foo->name]}', description => 'asdf'" );
    ok !$test->force_inflation( $iterator->next ),
      'but querying for non-existent values will return no results';
    $foo->description('asdf');
    $foo->save;
    $iterator =
      One->query(
        STRING => "name => '@{[$foo->name]}', description => 'asdf'" );
    is_deeply $test->force_inflation( $iterator->next ), $foo,
      '... and it should be the correct results';
}

sub count : Test(8) {
    my $test = shift;
    return unless $test->_should_run;
    can_ok One, 'count';
    my ( $foo, $bar, $baz ) = $test->test_objects;
    my $class = $foo->my_class;
    ok my $count = One->count, 'A count with only a class should succeed';
    is $count, 3, 'returning a count of all instances';
    ok $count = One->count( name => 'foo' ),
      'We should be able to count with a simple search';
    is $count, 1, 'returning the correct count';

    ok $count = One->count( name => GT 'c' ),
      'We should be able to count with any search operators';
    is $count, 2, 'returning the correct count';

    ok !( $count = One->count( name => 'no such name' ) ),
      'and it should return a false count if nothing matches';
}

sub query_uuids : Test(10) {
    my $test = shift;
    return unless $test->_should_run;
    can_ok One, 'query_uuids';
    my ( $foo, $bar, $baz ) = $test->test_objects;
    ok my $uuids = One->query_uuids,
      'A search for uuids with only a class should succeed';
    @$uuids = sort @$uuids;
    my @expected = sort map { $_->uuid } $foo, $bar, $baz;
    is_deeply $uuids, \@expected,
      'and it should return the correct list of uuids';

    ok $uuids = One->query_uuids( name => 'foo' ),
      'We should be able to search uuids with a simple search';
    is_deeply $uuids, [ $foo->uuid ], 'and return the correct uuids';

    ok $uuids = One->query_uuids( name => GT 'c', { order_by => 'name' } ),
      'We should be able to search uuids with any search operators';
    is_deeply $uuids, [ $foo->uuid, $baz->uuid ],
      'and return the correct uuids';

    $uuids = One->query_uuids( name => 'no such name' );
    is_deeply $uuids, [], 'and it should return nothing if nothing matches';

    ok my @uuids = One->query_uuids( name => GT 'c', { order_by => 'name' } ),
      'query_uuids should behave correctly in list context';
    is_deeply \@uuids, [ $foo->uuid, $baz->uuid ],
      'and return the correct uuids';
}

1;
