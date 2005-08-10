package TEST::Kinetic;

# $Id: Store.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Encode qw(is_utf8);

use aliased 'Test::MockModule';

use Kinetic::Store qw/:all/;
use aliased 'Kinetic::Util::Iterator';
use aliased 'Kinetic::Util::State';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
      ? 0
      : "Not testing Data Stores"
) if caller; # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub _all_items {
    my ($test, $iterator) = @_;
    my @iterator;
    while (my $object = $iterator->next) {
        push @iterator => $test->_force_inflation($object);
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
    my $test  = shift;
    return unless $test->_should_run;
    $test->_clear_database;
    my $one = One->new;
    $one->name('divO');
    $one->description('ssalc tset');
    $one->save;
    can_ok One, 'lookup';
    my $thing = One->lookup(guid => $one->guid);
    is_deeply $test->_force_inflation($thing), $one, 'and it should return the correct object';
    foreach my $method (qw/name description guid state/) {
        is $thing->$method, $one->$method, "$method() should behave the same";
    }
    throws_ok {One->lookup(no_such_attribute => 1)}
        'Kinetic::Util::Exception::Fatal::Attribute',
        'but it should croak if you search for a non-existent attribute';
    throws_ok {One->lookup(name => 1)}
        'Kinetic::Util::Exception::Fatal::Attribute',
        'or if you search on a non-unique field';
}

sub save : Test(10) {
    my $test  = shift;
    return unless $test->_should_run;
    $test->_clear_database;
    my $one = One->new;
    $one->name('Ovid');
    $one->description('test class');

    can_ok One, 'save';
    my $dbh = $test->{dbh};
    my $result = $dbh->selectrow_hashref('SELECT id, guid, name, description, state, bool FROM one');
    ok ! $result, 'We should start with a fresh database';
    ok $one->save, 'and saving an object should be successful';
    $result = $dbh->selectrow_hashref('SELECT id, guid, name, description, state, bool FROM one');
    $result->{state} = State->new($result->{state});
    # XXX this works, but it might be a bit fragile
    is_deeply $one, $result, 'and the data should match what we pull from the database';
    is $test->_num_recs('one'), 1, 'and we should have one record in the view';

    my $one_prime = One->new;
    $one_prime->name('bob');
    $one_prime->description('some description');
    $one_prime->save;
    is $test->_num_recs('one'), 2, 'and we should have one_prime records in the view';
    $result = $dbh->selectrow_hashref('SELECT id, guid, name, description, state, bool FROM one WHERE name = \'bob\'');
    $result->{state} = State->new($result->{state});
    is_deeply $one_prime, $result, 'and the data should match what we pull from the database';
    $one_prime->name('beelzebub');
    $one_prime->save;
    my $guid = $dbh->quote($one_prime->guid);
    $result = $dbh->selectrow_hashref("SELECT id, guid, name, description, state, bool FROM one WHERE guid = $guid");
    $result->{state} = State->new($result->{state});
    is_deeply $one_prime, $result, 'and we should be able to update data';
    is $result->{name}, 'beelzebub', 'and return the correct results';
    is $test->_num_recs('one'), 2, 'without the number of records changing';
}

sub search : Test(19) {
    my $test = shift;
    return unless $test->_should_run;
    can_ok One, 'search';
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    foreach ($foo, $bar, $baz) {
        $_->name($_->name.chr(0x100));
        $_->save;
    }
    my $class = $foo->my_class;
    ok my $iterator = One->search,
        'A search with only a class should succeed';
    my @results = $test->_all_items($iterator);
    is @results, 3, 'returning all instances in the class';

    foreach my $result (@results) {
        ok is_utf8($result->name), '... and the data should be unicode strings';
    }

    ok $iterator = One->search(name => $foo->name),
        'and an exact match should succeed';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $test->_force_inflation($iterator->next), $foo,
        'and the first item should match the correct object';
    ok ! $test->_force_inflation($iterator->next), 'and there should be the correct number of objects';

    ok $iterator = One->search(name => $foo->name),
        'We should also be able to call search as a class method';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $test->_force_inflation($iterator->next), $foo,
        'and it should return the same results as an instance method';
    ok ! $test->_force_inflation($iterator->next), 'and there should be the correct number of objects';

    ok $iterator = One->search(name => ucfirst $foo->name),
        'Case-insensitive searches should work';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $test->_force_inflation($iterator->next), $foo,
         'and they should return data even if the case does not match';

    $iterator = One->search(name => $foo->name, description => 'asdf');
    ok ! $test->_force_inflation($iterator->next),
        'but searching for non-existent values will return no results';
    $foo->description('asdf');
    $foo->save;
    $iterator = One->search(name => $foo->name, description => 'asdf');
    is_deeply $test->_force_inflation($iterator->next), $foo,
        '... and it should be the correct results';
}

sub string_search : Test(19) {
    my $test = shift;
    return unless $test->_should_run;
    can_ok One, 'search';
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    foreach ($foo, $bar, $baz) {
        $_->name($_->name.chr(0x100));
        $_->save;
    }
    ok my $iterator = One->search(STRING => ''),
        'A search with only a class should succeed';
    my @results = $test->_all_items($iterator);
    is @results, 3, 'returning all instances in the class';

    foreach my $result (@results) {
        ok is_utf8($result->name), '... and the data should be unicode strings';
    }

    ok $iterator = One->search(STRING => "name => '@{[$foo->name]}'"),
        'and an exact match should succeed';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $test->_force_inflation($iterator->next), $foo,
        'and the first item should match the correct object';
    ok ! $test->_force_inflation($iterator->next), 'and there should be the correct number of objects';

    ok $iterator = One->search(STRING => "name => '@{[$foo->name]}'"),
        'We should also be able to call search as a class method';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $test->_force_inflation($iterator->next), $foo,
        'and it should return the same results as an instance method';
    ok ! $test->_force_inflation($iterator->next), 'and there should be the correct number of objects';

    ok $iterator = One->search(
        STRING => "name => '@{[ucfirst $foo->name]}'"
    ), 'Case-insensitive searches should work';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $test->_force_inflation($iterator->next), $foo,
         'and they should return data even if the case does not match';

    $iterator = One->search(
        STRING => "name => '@{[$foo->name]}', description => 'asdf'");
    ok ! $test->_force_inflation($iterator->next),
        'but searching for non-existent values will return no results';
    $foo->description('asdf');
    $foo->save;
    $iterator = One->search(
        STRING => "name => '@{[$foo->name]}', description => 'asdf'"
    );
    is_deeply $test->_force_inflation($iterator->next), $foo,
        '... and it should be the correct results';
}

sub count : Test(8) {
    my $test = shift;
    return unless $test->_should_run;
    can_ok One, 'count';
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    ok my $count = One->count,
        'A search with only a class should succeed';
    is $count, 3, 'returning a count of all instances';
    ok $count = One->count(name => 'foo'),
        'We should be able to count with a simple search';
    is $count, 1, 'returning the correct count';

    ok $count = One->count(name => GT 'c'),
        'We should be able to count with any search operators';
    is $count, 2, 'returning the correct count';

    ok ! ($count = One->count(name => 'no such name')),
        'and it should return a false count if nothing matches';
}

sub search_guids : Test(10) {
    my $test = shift;
    return unless $test->_should_run;
    can_ok One, 'search_guids';
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    ok my $guids = One->search_guids,
        'A search for guids with only a class should succeed';
    @$guids = sort @$guids;
    my @expected = sort map {$_->guid} $foo, $bar, $baz;
    is_deeply $guids, \@expected,
        'and it should return the correct list of guids';

    ok $guids = One->search_guids(name => 'foo'),
        'We should be able to search guids with a simple search';
    is_deeply $guids, [$foo->guid], 'and return the correct guids';

    ok $guids = One->search_guids(name => GT 'c', {order_by => 'name'}),
        'We should be able to search guids with any search operators';
    is_deeply $guids, [$foo->guid, $baz->guid], 'and return the correct guids';

    $guids = One->search_guids(name => 'no such name');
    is_deeply $guids, [],
        'and it should return nothing if nothing matches';

    ok my @guids = One->search_guids(name => GT 'c', {order_by => 'name'}),
        'search_guids should behave correctly in list context';
    is_deeply \@guids, [$foo->guid, $baz->guid], 'and return the correct guids';
}

1;