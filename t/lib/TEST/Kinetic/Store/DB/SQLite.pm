package TEST::Kinetic::Store::DB::SQLite;

# $Id: SQLite.pm 1099 2005-01-12 06:17:57Z theory $

use strict;
use warnings;
use DBI;

# we load Schema first because this class tells the others
# to use their appropriate Schema counterparts.  This is not
# intuitive and will possibly have to be changed at some point.
use base 'TEST::Kinetic::Store::DB';
use Kinetic::Build::Schema::DB::SQLite; # this seems a bit weird
use Test::More;
use Test::Exception;

use aliased 'Test::MockModule';
use aliased 'Sub::Override';

use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Store::DB::SQLite' => 'Store';
use aliased 'Kinetic::Util::Collection';
use aliased 'Kinetic::Util::State';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

__PACKAGE__->runtests;


sub startup : Test(startup) {
    my $test = shift;
    $test->{dbh} = $test->_dbh;
    no warnings 'redefine';
    *Kinetic::Store::DB::_dbh = sub {$test->{dbh}};
}

sub setup : Test(setup) {  
    my $test = shift;
    $test->{dbh}->begin_work if $test->{dbh};
}

sub teardown : Test(teardown) {
    my $test = shift;
    $test->{dbh}->rollback if $test->{dbh};
}

sub save : Test(10) {
    my $test  = shift;
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

sub lookup : Test(8) {
    my $test  = shift;
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
        qr/\QNo such property (no_such_property) for TestApp::Simple::One\E/,
        'but it should croak if you search for a non-existent property';
    throws_ok {Store->lookup($two->my_class, 'name' => 1)}
        qr/\QProperty (name) is not unique\E/,
        'or if you search on a non-unique field';
}

sub search : Test(9) {
    my $test = shift;
    can_ok Store, 'search';

    my $foo = One->new;   my $bar = One->new;   my $baz = One->new;
    $foo->name('foo');    $bar->name('bar');    $baz->name('snorfleglitz');
    Store->save($foo);    Store->save($bar);    Store->save($baz);

    my $class = $foo->my_class;
    ok my $collection = Store->search($class),
        'A search with only a class should succeed';
    my @results = _all_items($collection);
    is @results, 3, 'returning all instances in the class';

    ok $collection = Store->search($class, name => 'foo'), 
        'and an exact match should succeed';
    isa_ok $collection, Collection, 'and the object it returns';
    is_deeply $collection->next, $foo, 
        'and the first item should match the correct object';
    ok ! $collection->next, 'and there should be the correct number of objects';
    $collection = Store->search($class, name => 'foo', description => 'asdf');
    ok ! $collection->next,
        'but searching for non-existent collection will return no results';
    $foo->description('asdf');
    Store->save($foo);
    $collection = Store->search($class, name => 'foo', description => 'asdf');
    is_deeply $collection->next, $foo, 
        '... and it should be the correct results';
}

sub search_like : Test(5) {
    my $test = shift;
    can_ok Store, 'search';
    my $foo = One->new;
    $foo->name('foo');
    Store->save($foo);
    my $bar = One->new;
    $bar->name('bar');
    Store->save($bar);
    my $baz = One->new;
    $baz->name('snorfleglitz');
    Store->save($baz);
    my $class = $foo->my_class;
    my $collection = Store->search($class, name => '%f%');
    my @collection = _all_items($collection);
    is @collection, 2, 'and return the correct number of matches';
    @collection = sort { $a->name cmp $b->name } @collection;
    is_deeply \@collection, [$foo, $baz], 'and the correct objects';

    $foo->description('some desc');
    Store->save($foo);  
    $collection = Store->search($class, name => '%f%', description => '%desc');
    is_deeply $collection->next, $foo, 
        'and a compound like search should return the correct results';
    ok ! $collection->next, 'and should not return more than the correct results';
}

sub search_between : Test(5) {
    my $test = shift;
    can_ok Store, 'search';
    my $foo = One->new;
    $foo->name('foo');
    Store->save($foo);
    my $bar = One->new;
    $bar->name('bar');
    Store->save($bar);
    my $baz = One->new;
    $baz->name('snorfleglitz');
    Store->save($baz);
    my $class = $foo->my_class;
    my $collection = Store->search($class, name => ['b' => 'g']);

    my @collection = _all_items($collection);
    is @collection, 2, 'and return the correct number of matches';
    @collection = sort { $a->name cmp $b->name } @collection;
    is_deeply \@collection, [$bar, $foo], 'and the correct objects';

    $collection = Store->search($class, name => ['f' => 's']);
    @collection = _all_items($collection);
    is @collection, 1, 
        'and a BETWEEN match should return the correct number of objects';
    is_deeply $collection[0], $foo, '... and they should be the correct ones';
}

sub _all_items {
    my $collection = shift;
    my @collection;
    while (my $object = $collection->next) {
        push @collection => $object;
    }
    return @collection;
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
    my $collection = Store->search($class, age => [12 => 30]);
    my @results = _all_items($collection);
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
    my $collection = Store->search($class, {order_by => 'name'});
    my @results = _all_items($collection);
    if ($results[0]->age < $results[1]->age) {
        @results[0,1] = @results[1,0];
    }
    is_deeply \@results, [$foo, $bar, $baz],
        'order_by constraints should work properly';

# don't forgot about ordering by non-existent attributes
    $collection = Store->search($class, {order_by => ['name','age']});
    @results = _all_items($collection);
    is_deeply \@results, [$bar, $foo, $baz],
        'even if we have more than one order_by constraint';
    
    $collection = Store->search($class, {
        order_by   => [qw/name age/],
        sort_order => [qw/asc desc/],
    });
    @results = _all_items($collection);
    is_deeply \@results, [$foo, $bar, $baz],
        'and we should be able to handle multiple sort parameters';

    $collection = Store->search($class, {order_by => 'age', sort_order => 'desc'});
    @results = _all_items($collection);
    is_deeply \@results, [$baz, $foo, $bar],
        'and we can combine single items order_by and sort parameters';
}

sub _num_recs {
    my ($self, $table) = @_;
    my $result = Store->_dbh->selectrow_arrayref("SELECT count(*) FROM $table");
    return $result->[0];
}

1;

__END__
BEGIN {
    my $schema_class = 'Kinetic::Build::Schema::DB::SQLite';
    my $schema = $schema_class->new;
    $schema->load_classes(File::Spec->catfile(getcwd, qw/t lib/));
    foreach my $class ($schema->classes) {
        printf "Package: %20s    Key: %10s\n" => $class->package, $class->key;
        foreach my $attribute ($class->attributes) {
            printf "    Attribute: %14s    Type: %10s\n" => $attribute->name, $attribute->type;
        }
    }
    exit;
}

Package:      TestApp::Simple    Key:     simple
    Attribute:           guid    Type:       guid
    Attribute:           name    Type:     string
    Attribute:    description    Type:     string
    Attribute:          state    Type:      state
Package: TestApp::Simple::One    Key:        one
    Attribute:           guid    Type:       guid
    Attribute:           name    Type:     string
    Attribute:    description    Type:     string
    Attribute:          state    Type:      state
    Attribute:           bool    Type:    boolean
Package: TestApp::Simple::Two    Key:        two
    Attribute:           guid    Type:       guid
    Attribute:           name    Type:     string
    Attribute:    description    Type:     string
    Attribute:          state    Type:      state
    Attribute:            one    Type:        one
    Attribute:            age    Type:      whole
Package:    TestApp::Composed    Key:   composed
    Attribute:           guid    Type:       guid
    Attribute:           name    Type:     string
    Attribute:    description    Type:     string
    Attribute:          state    Type:      state
    Attribute:            one    Type:        one
Package:    TestApp::CompComp    Key:  comp_comp
    Attribute:           guid    Type:       guid
    Attribute:           name    Type:     string
    Attribute:    description    Type:     string
    Attribute:          state    Type:      state
    Attribute:       composed    Type:   composed

