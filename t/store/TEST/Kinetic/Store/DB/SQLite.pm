package TEST::Kinetic::Store::DB::SQLite;

# $Id: SQLite.pm 1099 2005-01-12 06:17:57Z theory $

use strict;
use warnings;
use DBI;
use Encode qw(is_utf8);

use base 'TEST::Kinetic::Store::DB';
#use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;

use aliased 'Test::MockModule';
use aliased 'Sub::Override';

use Kinetic::Store qw/:all/;
use aliased 'Kinetic::Build';
use aliased 'Kinetic::Build::Store::DB::SQLite' => 'SQLiteBuild';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Util::Iterator';
use aliased 'Kinetic::Util::State';
use aliased 'Kinetic::DateTime';
use aliased 'Kinetic::DateTime::Incomplete';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

# Skip all of the tests in this class if SQLite isn't supported.
__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->supported('sqlite')
      ? 0
      : "Not testing SQLite"
) if caller; # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub Store () { 'Kinetic::Store::DB::SQLite' }

sub _all_items {
    my $iterator = shift;
    my @iterator;
    while (my $object = $iterator->next) {
        push @iterator => $object;
    }
    return @iterator;
}

sub _num_recs {
    my ($self, $table) = @_;
    my $result = Store->_dbh->selectrow_arrayref("SELECT count(*) FROM $table");
    return $result->[0];
}

sub setup : Test(setup) {
    my $test = shift;
    $test->{dbh} = $test->test_class->_dbh;
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

sub _clear_database {
    # Call this method if you have a test which needs an empty database.
    my $test = shift;
    $test->{dbi_mock}->unmock_all;
    $test->{dbh}->rollback;
    $test->{dbh}->begin_work;
    $test->{dbi_mock}->mock(begin_work => 1);
    $test->{dbi_mock}->mock(commit => 1);
}

sub search_incomplete_date_boundaries : Test(6) {
    my $test = shift;
    $test->_clear_database;

    my $june17 = Two->new;
    $june17->name('june17');
    $june17->one->name('june17_one_name');
    $june17->date(DateTime->new( 
        year  => 1968,
        month => 6,
        day   => 17 
    ));
    my $june16 = Two->new;
    $june16->name('june16');
    $june16->one->name('june16_one_name');
    $june16->date(DateTime->new( 
        year  => 1967,
        month => 06,
        day   => 16 
    ));
    my $july16 = Two->new;
    $july16->name('july16');
    $july16->one->name('july16_one_name');
    $july16->date(DateTime->new( 
        year  => 1967,
        month => 07,
        day   => 16 
    ));
    Store->save($_) foreach $june17, $june16, $july16;
    my $class    = $june17->my_class;
    my $store    = Store->new;
    my $bad_date = Incomplete->new(month => 6, hour => 23); 

    throws_ok {Store->search($class, date => GT $bad_date)}
        qr/You cannot do GT or LT type searches with non-contiguous dates/,
        'Non-contiguous dates should throw an exception with GT/LT searches';

    my $bad_date1 = Incomplete->new(month => 7, hour => 22);
    throws_ok {Store->search($class, date => [$bad_date => $bad_date1])}
        qr/You cannot do range searches with non-contiguous dates/,
        'Non-contiguous dates should throw an exception with range searches';

    my ($first, $second) = (Incomplete->new(month => 6), Incomplete->new(day => 3));
    throws_ok {Store->search($class, date => [$first => $second])}
        qr/BETWEEN search dates must have identical segments defined/,
        'BETWEEN search dates without identically defined segments will die';

    my $date1    = Incomplete->new( month => 6, day   => 17 );
    my $iterator = Store->search($class, date => GE $date1);
    my @results  = _all_items($iterator);
    is @results, 2, 'We should be able to search on incomplete dates';
    is_deeply \@results, [$june17, $july16], '... and get the correct results';

    throws_ok {Store->search($class, date => ANY($date1, {}))}
        qr/All types to an ANY search must match/,
        'ANY searches with incomplete dates must have all types matching';    
}

sub search_incomplete_dates : Test(25) {
    my $test = shift;
    $test->_clear_database;
    my $theory = Two->new;
    $theory->name('David');
    $theory->one->name('david_one_name');
    $theory->date(DateTime->new( 
        year  => 1968,
        month => 12,
        day   => 19 
    ));
    my $ovid = Two->new;
    $ovid->name('Ovid');
    $ovid->one->name('ovid_one_name');
    $ovid->date(DateTime->new( 
        year  => 1967,
        month => 06,
        day   => 20 
    ));
    my $usa = Two->new;
    $usa->one->name('usa_one_name');
    $usa->name('USA');
    $usa->date(DateTime->new(
        year  => 1976, # yeah, I know
        month => 7,
        day   => 4,
    ));
    my $lil = Two->new;
    $lil->one->name('Lil');
    $lil->name('Lil_one_name');
    $lil->date(DateTime->new(
        year  => 1976,
        month => 1,
        day   => 9,
    )); 
    Store->save($_) foreach $theory, $ovid, $usa, $lil;

    my $class    = $ovid->my_class;
    my $store    = Store->new;
    my $june     = Incomplete->new(month => 6); 
    my $iterator = $store->search($class, date => $june);
    my @results  = _all_items($iterator);
    is @results, 1, 'We should be able to search on incomplete dates';
    is_deeply \@results, [$ovid], '... and get the correct results';

    my $bicentennial = Incomplete->new(year => 1976);
    $iterator        = $store->search($class, date => $bicentennial, { order_by => 'date' });
    @results         = _all_items($iterator);
    is @results, 2, '... even if we have multiple results';
    is_deeply \@results, [$lil, $usa], '... but they had better be the correct results';
    
    $bicentennial->set(day => 4);
    $iterator        = $store->search($class, date => $bicentennial, { order_by => 'date' });
    @results         = _all_items($iterator);
    is @results, 1, '... even if we have just a year and a day';
    is_deeply \@results, [$usa], '... but they had better be the correct results';

    my $bad_date = Incomplete->new(year => 1776);
    $iterator    = $store->search($class, date => $bad_date);
    @results     = _all_items($iterator);
    ok ! @results, '... but searching in a non-existent date should fail, even if it is an incomplete date';

    $june = Incomplete->new(
        month => '06',
        day   => '16',
    );
    $iterator = $store->search($class, date => GE $june, {order_by => 'date'});
    @results  = _all_items($iterator);
    is @results, 3, 'Incomplete dates should recognize GE';
    is_deeply \@results, [$ovid, $theory, $usa], '... and get the correct results';

    $june = Incomplete->new(month => 6);
    $iterator = $store->search($class, date => GT $june, {order_by => 'date'});
    @results  = _all_items($iterator);
    is @results, 2, 'Incomplete dates should recognize GT';
    is_deeply \@results, [$theory, $usa], '... and get the correct results';

    $june->set(day => 20);
    $iterator = $store->search($class, date => LE $june, {order_by => 'date'});
    @results  = _all_items($iterator);
    is @results, 2, 'Incomplete dates should recognize LE';
    is_deeply \@results, [$ovid, $lil], '... and get the correct results';

    $iterator = $store->search($class, date => LT $june, {order_by => 'date'});
    @results  = _all_items($iterator);
    is @results, 1, 'Incomplete dates should recognize LT';
    is_deeply \@results, [$lil], '... and get the correct results';

    my $y1968 = Incomplete->new(year => 1968);
    my $y1966 = Incomplete->new(year => 1966);
    $iterator = $store->search($class, 
        date => LT $y1968,
        date => GT $y1966,
        name => LIKE '%vid', 
        {order_by => 'date'}
    );
    @results  = _all_items($iterator);
    is @results, 1, 'Incomplete dates should recognize LT';
    is_deeply \@results, [$ovid], '... and get the correct results';

    $iterator = $store->search($class, 
        date => [$y1966 => $y1968],
        name => LIKE 'Ovi%', 
        {order_by => 'date'}
    );
    @results  = _all_items($iterator);
    is @results, 1, 'Incomplete dates should recognize BETWEEN';
    is_deeply \@results, [$ovid], '... and get the correct results';

    $iterator = $store->search($class, 
        date => [$y1966 => $y1968],
        name => LIKE '%vid', 
        {order_by => 'date'}
    );
    @results  = _all_items($iterator);
    is @results, 2, 'Incomplete dates should recognize BETWEEN with complex queries';
    is_deeply \@results, [$ovid, $theory], '... and get the correct results';

    my $date1    = Incomplete->new( month => 6, day => 20 );
    my $date2    = Incomplete->new( year => 1976, month => 1 );
    $iterator = Store->search($class, 
        date => ANY($date1, $date2),
        {order_by => 'date'}
    );
    @results  = _all_items($iterator);
    is @results, 2, 'We should be able to search on ANY incomplete dates with ANY';
    is_deeply \@results, [$ovid, $lil], '... and get the correct results';

    my $date3 = Incomplete->new(year => 1976, day => 4);
    $iterator = Store->search($class, 
        date => ANY($date1, $date2, $date3),
        {order_by => 'date'}
    );
    @results  = _all_items($iterator);
    is @results, 3, '... and ANY incomplete searches should allow non-contiguous dates';
    is_deeply \@results, [$ovid, $lil, $usa], '... and get the correct results';
}

sub search : Test(19) {
    my $test = shift;
    can_ok Store, 'search';
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    ok my $iterator = $store->search($class),
        'A search with only a class should succeed';
    my @results = _all_items($iterator);
    is @results, 3, 'returning all instances in the class';
    foreach my $result (@results) {
        ok is_utf8($result->name), '... and the data should be unicode strings';
    }

    ok $iterator = $store->search($class, name => 'foo'),
        'and an exact match should succeed';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $iterator->next, $foo,
        'and the first item should match the correct object';
    ok ! $iterator->next, 'and there should be the correct number of objects';

    ok $iterator = Store->search($class, name => 'foo'),
        'We should also be able to call search as a class method';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $iterator->next, $foo,
        'and it should return the same results as an instance method';
    ok ! $iterator->next, 'and there should be the correct number of objects';

    ok $iterator = Store->search($class, name => 'Foo'),
        'Case-insensitive searches should work with SQLite';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $iterator->next, $foo,
         'and they should return data even if the case does not match';

    $iterator = $store->search($class, name => 'foo', description => 'asdf');
    ok ! $iterator->next,
        'but searching for non-existent values will return no results';
    $foo->description('asdf');
    Store->save($foo);
    $iterator = $store->search($class, name => 'foo', description => 'asdf');
    is_deeply $iterator->next, $foo,
        '... and it should be the correct results';
}

sub search_dates : Test(8) {
    my $test = shift;
    $test->_clear_database;
    my $theory = Two->new;
    $theory->name('David');
    $theory->one->name('david_one_name');
    $theory->date(DateTime->new( 
        year  => 1968,
        month => 12,
        day   => 19 
    ));
    my $ovid = Two->new;
    $ovid->name('Ovid');
    $ovid->one->name('ovid_one_name');
    $ovid->date(DateTime->new( 
        year  => 1967,
        month => 06,
        day   => 20 
    ));
    my $usa = Two->new;
    $usa->one->name('usa_one_name');
    $usa->name('USA');
    $usa->date(DateTime->new(
        year  => 1976, # yeah, I know
        month => 7,
        day   => 4,
    ));
    Store->save($_) foreach $theory, $ovid, $usa;

    my $class   = $ovid->my_class;
    my $store = Store->new;
    my $iterator = Store->search($class, date => GT $theory->date);
    my @results = _all_items($iterator);
    is @results, 1, 'We should be able to search on date fields of objects';
    is_deeply \@results, [$usa], '... and get the correct results';

    ok $iterator = Store->search($class, 
        date => GE $theory->date,
        { order_by => 'date' }
    );
    @results = _all_items($iterator);
    is @results, 2, 'We should be able to search on date fields of objects';
    is_deeply \@results, [$theory, $usa], '... and get the correct results';

    ok $iterator = Store->search($class, date => $theory->date);
    @results = _all_items($iterator);
    is @results, 1, 'We should be able to search on date fields of objects';
    is_deeply \@results, [$theory], '... and get the correct results';
}

sub search_compound : Test(9) {
    my $test = shift;
    $test->_clear_database;
    can_ok Store, 'search';
    my $foo = Two->new;
    $foo->name('foo');
    $foo->age(13);
    $foo->one->name('foo_name');
    Store->save($foo);
    my $bar = Two->new;
    $bar->name('bar');
    $bar->age(29);
    $bar->one->name('bar_name');
    Store->save($bar);
    my $baz = Two->new;
    $baz->age(33);
    $baz->name('snorfleglitz');
    $baz->one->name('snorfleglitz_rulez_d00d');
    Store->save($baz);
    my $class   = $foo->my_class;
    my $store = Store->new;
    my $iterator = Store->search($class, 'one.name' => 'foo_name');
    my @results = _all_items($iterator);
    is @results, 1, 'We should be able to search on the key fields of contained objects';
    is_deeply \@results, [$foo], '... and get the correct results';

    $iterator = Store->search($class, 
        'one.name' => LIKE '%name',
        {order_by => 'one.name'}
    );
    @results = _all_items($iterator);
    is @results, 2, '... and we should even be able to order by those fields';
    is_deeply \@results, [$bar,$foo], '... and get the correct results';

    my $one = $foo->one;
    $iterator = Store->search($class, one => $one);
    @results = _all_items($iterator);
    is @results, 1, '... and we should be able to search on just an object';
    is_deeply $results[0], $foo, 
        '... and it should return the correct object';
    $iterator = Store->search($class, 
        one => $one, OR('one.name' => 'bar_name'),
        {order_by => 'one.name'},
    );
    @results = _all_items($iterator);
    is @results, 2, '... and we should even be able to order by those fields';
    is_deeply \@results, [$bar,$foo], '... and get the correct results';
}

sub limit : Test(12) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    ok my $iterator = $store->search(
        $class, { 
            limit    => 2,
            order_by => 'name',
        }),
        'A search with a limit should succeed';
    my @results = _all_items($iterator);
    is @results, 2, 'returning no more than the number of objects specified in the limit';

    $iterator = $store->search( $class, { 
        limit    => 4,
        order_by => 'name',
    });
    @results = _all_items($iterator);
    is @results, 3, 'but no more than the number of objects available';

    $iterator = $store->search( $class, { 
        limit    => 0,
        order_by => 'name',
    });
    @results = _all_items($iterator);
    ok ! @results, 'and no objects if the limit is 0';

    for my $letter ( 'a' .. 'z' ) {
        my $object = One->new;
        $object->name($letter);
        Store->save($object);
    }
    $iterator = $store->search( $class, { 
        limit    => 30,
        order_by => 'name',
    });
    @results = _all_items($iterator);
    is @results, 29, 'We should have all 26 letters of the alphabet plus the original three objects';

    $iterator = $store->search( $class, name => LIKE '_', { 
        limit    => 30,
        order_by => 'name',
    });
    @results = _all_items($iterator);
    is @results, 26, 'We should have all 26 letters of the alphabet';
    
    $iterator = $store->search( $class, name => LIKE '_', { 
        limit    => 13,
        order_by => 'name',
    });
    @results = _all_items($iterator);
    is @results, 13, 'We should have 13 letters of the alphabet';
    my @letters = map $_->name => @results;
    is_deeply \@letters, ['a' .. 'm'], 'and they should be the first 13 letters';

    $iterator = $store->search( $class, name => LIKE '_', { 
        limit    => 13,
        order_by => 'name',
        offset   => 13,
    });
    @results = _all_items($iterator);
    is @results, 13, 'We should have 13 letters of the alphabet';
    @letters = map $_->name => @results;
    is_deeply \@letters, ['n' .. 'z'], 'and they should be the last 13 letters';

    $iterator = $store->search( $class, name => LIKE '_', { 
        limit    => 24,
        order_by => 'name',
        offset   => 1,
    });
    @results = _all_items($iterator);
    is @results, 24, 'We should have 24 letters of the alphabet';
    @letters = map $_->name => @results;
    is_deeply \@letters, ['b' .. 'y'], 'and they should be all but the first and last letters';
}

sub full_text_search : Test(1) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    throws_ok {$store->search($class => 'full text search string')}
        qr/SQLite does not support full-text searches/,
        'SQLite should die if a full text search is attempted';
}

sub count : Test(8) {
    my $test = shift;
    can_ok Store, 'count';
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    ok my $count = Store->count($class),
        'A search with only a class should succeed';
    is $count, 3, 'returning a count of all instances';
    ok $count = Store->count($class, name => 'foo'),
        'We should be able to count with a simple search';
    is $count, 1, 'returning the correct count';

    ok $count = Store->count($class, name => GT 'c'),
        'We should be able to count with any search operators';
    is $count, 2, 'returning the correct count';

    ok ! ($count = Store->count($class, name => 'no such name')),
        'and it should return a false count if nothing matches';
}

sub search_guids : Test(10) {
    my $test = shift;
    can_ok Store, 'search_guids';
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    ok my $guids = Store->search_guids($class),
        'A search for guids with only a class should succeed';
    @$guids = sort @$guids;
    my @expected = sort map {$_->guid} $foo, $bar, $baz;
    is_deeply $guids, \@expected,
        'and it should return the correct list of guids';

    ok $guids = Store->search_guids($class, name => 'foo'),
        'We should be able to search guids with a simple search';
    is_deeply $guids, [$foo->guid], 'and return the correct guids';

    ok $guids = Store->search_guids($class, name => GT 'c', {order_by => 'name'}),
        'We should be able to search guids with any search operators';
    is_deeply $guids, [$foo->guid, $baz->guid], 'and return the correct guids';

    $guids = Store->search_guids($class, name => 'no such name');
    is_deeply $guids, [],
        'and it should return nothing if nothing matches';

    ok my @guids = Store->search_guids($class, name => GT 'c', {order_by => 'name'}),
        'search_guids should behave correctly in list context';
    is_deeply \@guids, [$foo->guid, $baz->guid], 'and return the correct guids';
}

sub where_token : Test(2) {
    my $store = Store->new;
    $store->{search_data}{fields} = ['name']; # so it doesn't think it's an object search
    throws_ok {$store->_make_where_token('name', MATCH '(a|b)%')}
        qr/MATCH:  SQLite does not support regular expressions/,
        'Trying to use a regex match with SQLite should croak';

    throws_ok {$store->_make_where_token('name', NOT MATCH '(a|b)%')}
        qr/MATCH:  SQLite does not support regular expressions/,
        'Trying to use a regex match with SQLite should croak even if we are trying to negate it';
}

sub search_or : Test(13) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    ok my $iterator = $store->search(
        $class,
        name => 'foo', OR(name => LIKE 'snorf%'),
        {order_by => 'name', sort_order => DESC}
    );
    my @items = _all_items($iterator);
    is @items, 2, 'OR should return the correct number of items';
    is_deeply \@items, [$baz, $foo],
        'and should include the correct items';
   
    ok $iterator = $store->search(
        $class,
        name => 'foo', OR(description => NOT undef),
        {order_by => 'name', sort_order => DESC}
    );
    @items = _all_items($iterator);
    is @items, 1, 'OR matches should return the correct number of items';
    is_deeply \@items, [$foo],
        'and should include the correct items';

    $bar->description('giggling pastries');
    Store->save($bar);
    ok $iterator = $store->search(
        $class,
        name => 'foo', OR(description => NOT undef),
        {order_by => 'name', sort_order => DESC}
    );
    @items = _all_items($iterator);
    is @items, 2, 'OR matches should return the correct number of items';
    is_deeply \@items, [$foo, $bar],
        'and should include the correct items';

    ok $iterator = $store->search(
        $class,
        name => 'foo', OR description => NOT undef,
    );
    @items = sort {$a->name cmp $b->name} _all_items($iterator);
    is @items, 2, 'OR should succeed even without parens';
    is_deeply \@items, [$bar, $foo],
        'and should include the correct items';

    throws_ok { $iterator = $store->search(
        $class,
        name => 'foo', OR description => NOT undef,
        {order_by => 'name'}
    ) }
    qr/\QI don't know what to do with a HASH for (description IS NOT NULL)\E/,
    'but it will choke without parens if you pass constraints';
}

sub search_and : Test(15) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    ok my $iterator = $store->search(
        $class,
        AND(name => 'foo', name => LIKE 'snorf%'),
        {order_by => 'name', sort_order => DESC}
    );
    my @items = _all_items($iterator);
    is @items, 0, 'AND should return the correct number of items';
    is_deeply \@items, [],
        'and should include the correct items';

    ok $iterator = $store->search(
        $class,
        AND(name => 'foo', description => NOT undef),
        {order_by => 'name', sort_order => DESC}
    );
    @items = _all_items($iterator);
    is @items, 0, 'AND matches should return the correct number of items';
    is_deeply \@items, [],
        'and should include the correct items';

    $bar->description('giggling pastries');
    Store->save($bar);
    ok $iterator = $store->search(
        $class,
        AND(name => 'bar', description => NOT undef),
        {order_by => 'name', sort_order => DESC}
    );
    @items = _all_items($iterator);
    is @items, 1, 'OR matches should return the correct number of items';
    is_deeply \@items, [$bar],
        'and should include the correct items';

    $foo->description('We Want Revolution');
    Store->save($foo);
    ok $iterator = $store->search(
        $class,
        AND(description => NOT undef, OR(name => 'foo', name => 'bar')),
        {order_by => 'name', sort_order => DESC}
    );
    @items = _all_items($iterator);
    is @items, 2, 'ComplexAND/OR matches should return the correct number of items';
    is_deeply \@items, [$foo, $bar],
        'and should include the correct items';

    ok $iterator = $store->search(
        $class,
        description => NOT undef,
        OR (name => 'foo', name => 'bar'),
        {order_by => 'name', sort_order => DESC}
    );
    is @items, 2, 'ComplexAND/OR matches should return the correct number of items';
    is_deeply \@items, [$foo, $bar],
        'and should include the correct items';
}

sub search_overloaded : Test(11) {
    {
        package Test::String;
        use overload '""' => \&to_string;
        sub new       { my ($pkg, $val) = @_; bless \$val => $pkg; }
        sub to_string { ${$_[0]} }
    }
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;

    $bar->description('giggling pastries');
    Store->save($bar);
    my $bname = Test::String->new('bar');
    ok my $iterator = $store->search(
        $class,
        AND(name => $bname, description => NOT undef),
        {order_by => 'name', sort_order => DESC}
    );
    my @items = _all_items($iterator);
    is @items, 1, 'OR matches should return the correct number of items';
    is_deeply \@items, [$bar],
        'and should include the correct items';

    $foo->description('We Want Revolution');
    Store->save($foo);
    ok $iterator = $store->search(
        $class,
        AND(description => NOT undef, OR(name => 'foo', name => $bname)),
        {order_by => 'name', sort_order => DESC}
    );
    @items = _all_items($iterator);
    is @items, 2, 'ComplexAND/OR matches should return the correct number of items';
    is_deeply \@items, [$foo, $bar],
        'and should include the correct items';

    ok $iterator = $store->search(
        $class,
        description => NOT undef,
        OR (name => 'foo', name => $bname),
        {order_by => 'name', sort_order => DESC}
    );
    is @items, 2, 'ComplexAND/OR matches should return the correct number of items';
    is_deeply \@items, [$foo, $bar],
        'and should include the correct items';

    {
        package Test::Number;
        use overload '""' => \&to_string;
        sub new       { my ($pkg, $val) = @_; bless \$val => $pkg; }
        sub to_string { ${$_[0]} }
    }
    $foo = Two->new;
    $foo->name('foo');
    $foo->age(13);
    $foo->one->name('foo_name');
    Store->save($foo);
    $bar = Two->new;
    $bar->name('bar');
    $bar->age(29);
    $bar->one->name('bar_name');
    Store->save($bar);
    $baz = Two->new;
    $baz->age(33);
    $baz->name('snorfleglitz');
    $baz->one->name('snorfleglitz_rulez_d00d');
    Store->save($baz);
    $class   = $foo->my_class;
    my $twelve = Test::Number->new(12);
    my $thirty = Test::Number->new(30);
    $iterator = Store->search($class, age => [$twelve => $thirty]);
    my @results = _all_items($iterator);
    is @results, 2, 'Searching on a range should return the correct number of results';
    @results = sort { $a->age <=> $b->age } @results;
    is_deeply \@results, [$foo, $bar], '... and the correct results';
}

sub save : Test(10) {
    my $test  = shift;
    $test->_clear_database;
    my $one = One->new;
    $one->name('Ovid');
    $one->description('test class');

    can_ok Store, 'save';
    my $dbh = $test->test_class->_dbh;
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

sub lookup : Test(8) {
    my $test  = shift;
    $test->_clear_database;
    my $one = One->new;
    $one->name('Ovid');
    $one->description('test class');
    Store->save($one);

    my $two = One->new;
    $two->name('divO');
    $two->description('ssalc tset');
    Store->save($two);
    can_ok Store, 'lookup';
    my $thing = Store->lookup($two->my_class, guid => $two->guid);
    is_deeply $thing, $two, 'and it should return the correct object';
    foreach my $method (qw/name description guid state/) {
        is $thing->$method, $two->$method, "$method() should behave the same";
    }
    throws_ok {Store->lookup($two->my_class, 'no_such_property' => 1)}
        qr/\QNo such property "no_such_property" for TestApp::Simple::One\E/,
        'but it should croak if you search for a non-existent property';
    throws_ok {Store->lookup($two->my_class, 'name' => 1)}
        qr/\QProperty "name" is not unique\E/,
        'or if you search on a non-unique field';
}

sub search_between : Test(6) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    my $iterator = $store->search($class, name => ['b' => 'g']);

    my @iterator = _all_items($iterator);
    is @iterator, 2, 'and return the correct number of matches';
    @iterator = sort { $a->name cmp $b->name } @iterator;
    is_deeply \@iterator, [$bar, $foo], 'and the correct objects';

    $iterator = $store->search($class, name => ['f' => 's']);
    @iterator = _all_items($iterator);
    is @iterator, 1,
        'and a BETWEEN match should return the correct number of objects';
    is_deeply $iterator[0], $foo, '... and they should be the correct ones';

    $iterator = $store->search(
        $class,
        name => NOT ['f' => 's'],
        { order_by => 'name' }
    );
    @iterator = _all_items($iterator);
    is @iterator, 2, 'A NOT BETWEEN should return the correct number of items.';
    is_deeply \@iterator, [$bar, $baz], 'and the should be the correct items';
}

sub search_gt : Test(6) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    ok my $iterator = $store->search(
            $class,
            name => GT 'c',
            {order_by => 'name'}
        ),
        'We should be able to do a GT search';
    my @items = _all_items($iterator);
    is @items, 2, 'and get the proper number of items';
    is_deeply \@items, [$foo, $baz], 'not to mention the correct items';
   
    ok $iterator = $store->search(
            $class,
            name => NOT GT 'c',
            {order_by => 'name'}
        ),
        'We should be able to do a NOT GT search';
    @items = _all_items($iterator);
    is @items, 1, 'and get the proper number of items';
    is_deeply \@items, [$bar], 'not to mention the correct items';
}

sub search_lt : Test(6) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    ok my $iterator = $store->search(
            $class,
            name => LT 's',
            {order_by => 'name'}
        ),
        'We should be able to do an LT search';
    my @items = _all_items($iterator);
    is @items, 2, 'and get the proper number of items';
    is_deeply \@items, [$bar, $foo], 'not to mention the correct items';
   
    ok $iterator = $store->search(
            $class,
            name => NOT LT 's',
            {order_by => 'name'}
        ),
        'We should be able to do a NOT LT search';
    @items = _all_items($iterator);
    is @items, 1, 'and get the proper number of items';
    is_deeply \@items, [$baz], 'not to mention the correct items';
}

sub search_eq : Test(14) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    ok my $iterator = $store->search(
            $class,
            name => EQ 's',
            {order_by => 'name'}
        ),
        'We should be able to do an EQ search';
    my @items = _all_items($iterator);
    is @items, 0, 'and we should get nothing if we do a bad match';

    ok $iterator = $store->search(
        $class,
        name => EQ 'foo',
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 1, 'but EQ should also function as syntactic sugar for $key => $value';
    is_deeply $items[0], $foo, 'and return the correct results';
    ok $iterator = $store->search(
        $class,
        name => NOT EQ 'foo',
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 2, 'NOT EQ should also work as expected';
    is_deeply \@items, [$bar, $baz], 'and return the correct results';
   
    ok $iterator = $store->search(
        $class,
        name => NE 'foo',
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 2, 'NE should also work as expected';
    is_deeply \@items, [$bar, $baz], 'and return the correct results';

    $store = Store->new;
    ok $iterator = $store->search(
        $class,
        name => NOT 'foo',
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 2, '"name => NOT $value" should also work as expected';
    is_deeply \@items, [$bar, $baz], 'and return the correct results';
}

sub search_ge : Test(6) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    ok my $iterator = $store->search(
        $class,
        name => GE 'f',
        {order_by => 'name'}
    );
    my @items = _all_items($iterator);
    is @items, 2, 'and GE should return the correct number of items';
    is_deeply \@items, [$foo, $baz],
        'and should include the correct items';
   
    ok $iterator = $store->search(
        $class,
        name => NOT GE 'f',
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 1, 'NOT GE should return the correct number of items';
    is_deeply \@items, [$bar],
        'and should include the correct items';
}

sub search_le : Test(6) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    ok my $iterator = $store->search(
        $class,
        name => LE 'foo',
        {order_by => 'name'}
    );
    my @items = _all_items($iterator);
    is @items, 2, 'and LE should return the correct number of items';
    is_deeply \@items, [$bar, $foo],
        'and should include the correct items';
   
    ok $iterator = $store->search(
        $class,
        name => NOT LE 'foo',
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 1, 'NOT LE should return the correct number of items';
    is_deeply \@items, [$baz],
        'and should include the correct items';
}

sub search_like : Test(6) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    ok my $iterator = $store->search(
        $class,
        name => LIKE 'f%',
        {order_by => 'name'}
    ), 'and calling search should succeed';
    my @items = _all_items($iterator);
    is @items, 1, 'and LIKE should return the correct number of items';
    is_deeply \@items, [$foo],
        'and should include the correct items';
   
    ok $iterator = $store->search(
        $class,
        name => NOT LIKE 'f%',
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 2, 'NOT LIKE should return the correct number of items';
    is_deeply \@items, [$bar, $baz],
        'and should include the correct items';
}

sub search_match : Test(1) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $store = Store->new;
    throws_ok {$store->search( $foo->my_class, name => MATCH '(a|b)%' ) }
        qr/MATCH:  SQLite does not support regular expressions/,
        'SQLite should croak() if a MATCH search is attempted';
}

sub search_null : Test(6) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    $foo->description('this is a description');
    Store->save($foo);
    my $class = $foo->my_class;
   
    my $store = Store->new;
    ok my $iterator = $store->search(
        $class,
        description => undef,
        {order_by => 'name'}
    );
    my @items = _all_items($iterator);
    is @items, 2, '"undef" should return the correct number of items';
    is_deeply \@items, [$bar, $baz],
        'and should include the correct items';
   
    ok $iterator = $store->search(
        $class,
        description => NOT undef,
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 1, '"NOT undef" should return the correct number of items';
    is_deeply \@items, [$foo],
        'and should include the correct items';
}

sub search_in : Test(6) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Store->new;
    ok my $iterator = $store->search(
        $class,
        name => ANY(qw/foo bar/),
        {order_by => 'name'}
    );
    my @items = _all_items($iterator);
    is @items, 2, 'ANY should return the correct number of items';
    is_deeply \@items, [$bar, $foo],
        'and should include the correct items';

    ok $iterator = $store->search(
        $class,
        name => NOT ANY(qw/foo bar/),
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 1, 'NOT ANY should return the correct number of items';
    is_deeply \@items, [$baz],
        'and should include the correct items';
}

sub save_compound : Test(3) {
    my $test = shift;
    can_ok Store, 'search';
    my $foo = Two->new;
    $foo->name('foo');
    $foo->age(13);
    $foo->one->name('foo_name');
    Store->save($foo);
    my $bar = Two->new;
    $bar->name('bar');
    $bar->age(29);
    $bar->one->name('bar_name');
    Store->save($bar);
    my $baz = Two->new;
    $baz->age(33);
    $baz->name('snorfleglitz');
    $baz->one->name('snorfleglitz_rulez_d00d');
    Store->save($baz);
    my $class   = $foo->my_class;
    my $store = Store->new;
    my $iterator = Store->search($class, age => [12 => 30]);
    my @results = _all_items($iterator);
    is @results, 2, 'Searching on a range should return the correct number of results';
    @results = sort { $a->age <=> $b->age } @results;
    is_deeply \@results, [$foo, $bar], '... and the correct results';
}

sub order_by : Test(4) {
    my $test = shift;
    my $foo = Two->new;
    $foo->name('foo');
    $foo->age(29);
    $foo->one->name('foo_name');
    Store->save($foo);

    my $bar = Two->new;
    $bar->name('foo');
    $bar->age(13);
    $bar->one->name('bar_name');
    Store->save($bar);

    my $baz = Two->new;
    $baz->age(33);
    $baz->name('snorfleglitz');
    $baz->one->name('snorfleglitz_rulez_d00d');
    Store->save($baz);
    my $class = $foo->my_class;
    my $store = Store->new;
    my $iterator = $store->search($class, {order_by => 'name'});
    my @results = _all_items($iterator);
    if ($results[0]->age < $results[1]->age) {
        @results[0,1] = @results[1,0];
    }
    is_deeply \@results, [$foo, $bar, $baz],
        'order_by constraints should work properly';

# XXX don't forgot about ordering by non-existent attributes
    $iterator = $store->search($class, {order_by => ['name','age']});
    @results = _all_items($iterator);
    is_deeply \@results, [$bar, $foo, $baz],
        'even if we have more than one order_by constraint';

    $iterator = $store->search($class, {
        order_by   => [qw/name age/],
        sort_order => [ASC, DESC],
    });
    @results = _all_items($iterator);
    is_deeply \@results, [$foo, $bar, $baz],
        'and we should be able to handle multiple sort parameters';

    $iterator = $store->search($class, {order_by => 'age', sort_order => DESC});
    @results = _all_items($iterator);
    is_deeply \@results, [$baz, $foo, $bar],
        'and we can combine single items order_by and sort parameters';
}

1;
