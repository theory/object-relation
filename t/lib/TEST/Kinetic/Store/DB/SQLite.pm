package TEST::Kinetic::Store::DB::SQLite;

# $Id: SQLite.pm 1099 2005-01-12 06:17:57Z theory $

use strict;
use warnings;
use DBI;

# we load Schema first because this class tells the others
# to use their appropriate Schema counterparts.  This is not
# intuitive and will possibly have to be changed at some point.
use base 'TEST::Kinetic::Store::DB';
#use base 'TEST::Class::Kinetic';
use Kinetic::Build::Schema::DB::SQLite; # this seems a bit weird
use Test::More;
use Test::Exception;
use File::Spec::Functions;
use Cwd;

use aliased 'Test::MockModule';
use aliased 'Sub::Override';

use Kinetic::Store qw/:all/;
use aliased 'Kinetic::Build';
use aliased 'Kinetic::Build::Store::DB::SQLite' => 'SQLiteBuild';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Store::DB::SQLite' => 'Store';
use aliased 'Kinetic::Util::Iterator';
use aliased 'Kinetic::Util::State';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

__PACKAGE__->runtests;

my ($DBH, $DBFILE);

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

sub startup : Test(startup) {
    my $self = shift;

    $self->chdirs('t', 'sample');
    local @INC = (catdir(updir, updir, 'lib'), @INC);

    my $builder;
    my $build = MockModule->new(Build);
    $build->mock(resume => sub { $builder });
    $build->mock(_app_info_params => sub {});
    $builder = Build->new(
        dist_name       => 'Testing::Kinetic',
        dist_version    => '1.0',
        quiet           => 1,
        accept_defaults => 1,
        source_dir      => 'lib',
    );

    # Construct the SQLite Builder.
    my $db_file = 'sqlite_test.db';
    my $sqlite = MockModule->new(SQLiteBuild);
    $sqlite->mock(db_file => $db_file);
    $sqlite->mock(_path => $db_file);

    my $kbs = SQLiteBuild->new;
    $kbs->add_actions('build_db');
    $kbs->build;
    die "$db_file doesn't exist!" unless -e $db_file;
    my $dsn = "dbi:SQLite:dbname=$db_file";
    my $dbh = DBI->connect($dsn, '', '', {RaiseError => 1});
    $self->{dbh} = $dbh;
    no warnings 'redefine';
    *Kinetic::Store::DB::_dbh = sub {$DBH};
}

sub shutdown : Test(shutdown) {
    my $self = shift;
    $self->{dbh}->disconnect;
    delete $self->{dbh};
    unlink catfile 't', 'sample', 'sqlite_test.db';
}

1;
__END__
sub setup : Test(setup) {  
    my $test = shift;
    $test->{dbh}->begin_work;
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
    $test->{dbh}->rollback;
}

sub _clear_database {
    # call this if you have a test which needs an empty
    # database
    my $test = shift;
    $test->{dbh}->rollback;
    $test->{dbh}->begin_work;
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
        qr/\QNo such property (no_such_property) for TestApp::Simple::One\E/,
        'but it should croak if you search for a non-existent property';
    throws_ok {Store->lookup($two->my_class, 'name' => 1)}
        qr/\QProperty (name) is not unique\E/,
        'or if you search on a non-unique field';
}

sub search : Test(9) {
    my $test = shift;
    can_ok Store, 'search';
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    ok my $iterator = Store->search($class),
        'A search with only a class should succeed';
    my @results = _all_items($iterator);
    is @results, 3, 'returning all instances in the class';

    ok $iterator = Store->search($class, name => 'foo'), 
        'and an exact match should succeed';
    isa_ok $iterator, Iterator, 'and the object it returns';
    is_deeply $iterator->next, $foo, 
        'and the first item should match the correct object';
    ok ! $iterator->next, 'and there should be the correct number of objects';
    $iterator = Store->search($class, name => 'foo', description => 'asdf');
    ok ! $iterator->next,
        'but searching for non-existent iterator will return no results';
    $foo->description('asdf');
    Store->save($foo);
    $iterator = Store->search($class, name => 'foo', description => 'asdf');
    is_deeply $iterator->next, $foo, 
        '... and it should be the correct results';
}

sub search_between : Test(6) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $iterator = Store->search($class, name => ['b' => 'g']);

    my @iterator = _all_items($iterator);
    is @iterator, 2, 'and return the correct number of matches';
    @iterator = sort { $a->name cmp $b->name } @iterator;
    is_deeply \@iterator, [$bar, $foo], 'and the correct objects';

    $iterator = Store->search($class, name => ['f' => 's']);
    @iterator = _all_items($iterator);
    is @iterator, 1, 
        'and a BETWEEN match should return the correct number of objects';
    is_deeply $iterator[0], $foo, '... and they should be the correct ones';

    $iterator = Store->search(
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
    ok my $iterator = Store->search(
            $class, 
            name => GT 'c', 
            {order_by => 'name'}
        ),
        'We should be able to do a GT search';
    my @items = _all_items($iterator);
    is @items, 2, 'and get the proper number of items';
    is_deeply \@items, [$foo, $baz], 'not to mention the correct items';
    
    ok $iterator = Store->search(
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
    ok my $iterator = Store->search(
            $class, 
            name => LT 's', 
            {order_by => 'name'}
        ),
        'We should be able to do an LT search';
    my @items = _all_items($iterator);
    is @items, 2, 'and get the proper number of items';
    is_deeply \@items, [$bar, $foo], 'not to mention the correct items';
    
    ok $iterator = Store->search(
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
#local $ENV{DEBUG} = 1;
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    ok my $iterator = Store->search(
            $class, 
            name => EQ 's', 
            {order_by => 'name'}
        ),
        'We should be able to do an EQ search';
    my @items = _all_items($iterator);
    is @items, 0, 'and we should get nothing if we do a bad match';

    ok $iterator = Store->search(
        $class, 
        name => EQ 'foo', 
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 1, 'but EQ should also function as syntactic sugar for $key => $value';
    is_deeply $items[0], $foo, 'and return the correct results';
    ok $iterator = Store->search(
        $class, 
        name => NOT EQ 'foo', 
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 2, 'NOT EQ should also work as expected';
    is_deeply \@items, [$bar, $baz], 'and return the correct results';
    
    ok $iterator = Store->search(
        $class, 
        name => NE 'foo', 
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 2, 'NE should also work as expected';
    is_deeply \@items, [$bar, $baz], 'and return the correct results';

local $ENV{DEBUG} = 1;; 
    ok $iterator = Store->search(
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
    ok my $iterator = Store->search(
        $class, 
        name => GE 'f', 
        {order_by => 'name'}
    );
    my @items = _all_items($iterator);
    is @items, 2, 'and GE should return the correct number of items';
    is_deeply \@items, [$foo, $baz], 
        'and should include the correct items';
    
    ok $iterator = Store->search(
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
    ok my $iterator = Store->search(
        $class, 
        name => LE 'foo', 
        {order_by => 'name'}
    );
    my @items = _all_items($iterator);
    is @items, 2, 'and LE should return the correct number of items';
    is_deeply \@items, [$bar, $foo], 
        'and should include the correct items';
    
    ok $iterator = Store->search(
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
    ok my $iterator = Store->search(
        $class, 
        name => LIKE 'f%', 
        {order_by => 'name'}
    );
    my @items = _all_items($iterator);
    is @items, 1, 'and LIKE should return the correct number of items';
    is_deeply \@items, [$foo], 
        'and should include the correct items';
    
    ok $iterator = Store->search(
        $class, 
        name => NOT LIKE 'f%', 
        {order_by => 'name'}
    );
    @items = _all_items($iterator);
    is @items, 2, 'NOT LIKE should return the correct number of items';
    is_deeply \@items, [$bar, $baz], 
        'and should include the correct items';
}

sub search_null : Test(6) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    $foo->description('this is a description');
    Store->save($foo);
    my $class = $foo->my_class;
    
    ok my $iterator = Store->search(
        $class, 
        description => undef, 
        {order_by => 'name'}
    );
    my @items = _all_items($iterator);
    is @items, 2, '"undef" should return the correct number of items';
    is_deeply \@items, [$bar, $baz], 
        'and should include the correct items';
    
    ok $iterator = Store->search(
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
    ok my $iterator = Store->search(
        $class, 
        name => ANY(qw/foo bar/), 
        {order_by => 'name'}
    );
    my @items = _all_items($iterator);
    is @items, 2, 'ANY should return the correct number of items';
    is_deeply \@items, [$bar, $foo], 
        'and should include the correct items';

    ok $iterator = Store->search(
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
    my $iterator = Store->search($class, {order_by => 'name'});
    my @results = _all_items($iterator);
    if ($results[0]->age < $results[1]->age) {
        @results[0,1] = @results[1,0];
    }
    is_deeply \@results, [$foo, $bar, $baz],
        'order_by constraints should work properly';

# don't forgot about ordering by non-existent attributes
    $iterator = Store->search($class, {order_by => ['name','age']});
    @results = _all_items($iterator);
    is_deeply \@results, [$bar, $foo, $baz],
        'even if we have more than one order_by constraint';
    
    $iterator = Store->search($class, {
        order_by   => [qw/name age/],
        sort_order => [qw/asc desc/],
    });
    @results = _all_items($iterator);
    is_deeply \@results, [$foo, $bar, $baz],
        'and we should be able to handle multiple sort parameters';

    $iterator = Store->search($class, {order_by => 'age', sort_order => 'desc'});
    @results = _all_items($iterator);
    is_deeply \@results, [$baz, $foo, $bar],
        'and we can combine single items order_by and sort parameters';
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

