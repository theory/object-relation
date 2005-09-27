package TEST::Kinetic::Store::DB;

# $Id: DB.pm 1099 2005-01-12 06:17:57Z theory $

use strict;
use warnings;

use Test::More;
use Test::Exception;
use base 'TEST::Kinetic::Store';
#use base 'TEST::Class::Kinetic';
use TEST::Kinetic::Traits::Store qw/test_objects/;
use aliased 'Test::MockModule';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Meta::Attribute';
use aliased 'Kinetic::Store' => 'DONT_USE', ':all';
use aliased 'Kinetic::Store::DB' => 'Store';
use aliased 'Kinetic::Util::State';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
      ? 0
      : "Not testing Data Stores"
) if caller; # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub _num_recs {
    my ($test, $table) = @_;
    my $result = $test->{dbh}->selectrow_arrayref("SELECT count(*) FROM $table");
    return $result->[0];
}

my $debugging = 0;
sub setup : Test(setup) {
    my $test = shift;
    my $store = Kinetic::Store->new;
    $test->{dbh} = $store->_dbh;
    unless ($debugging) { # give us an easy debugging hook
        $test->{dbh}->begin_work;
        $test->{dbi_mock} = MockModule->new('DBI::db', no_auto => 1);
        $test->{dbi_mock}->mock(begin_work => 1);
        $test->{dbi_mock}->mock(commit => 1);
        $test->{db_mock} = MockModule->new('Kinetic::Store::DB');
        $test->{db_mock}->mock(_dbh => $test->{dbh});
    }
    my $foo = One->new;
    $foo->name('foo');
    $store->save($foo);
    my $bar = One->new;
    $bar->name('bar');
    $store->save($bar);
    my $baz = One->new;
    $baz->name('snorfleglitz');
    $store->save($baz);
    $test->test_objects([$foo, $bar, $baz]);
}

sub teardown : Test(teardown) {
    my $test = shift;
    if ($debugging) {
        $test->{dbh}->commit;
    }
    else {
        delete($test->{dbi_mock})->unmock_all;
        $test->{dbh}->rollback unless $test->{dbh}->{AutoCommit};
        delete($test->{db_mock})->unmock_all;
    }
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

sub test_id : Test(5) {
    # Test the private ID attribute added by Kinetic::Store::DB.
    my $self = shift;
    ok my $class = One->my_class, "We should get the class object";
    ok my $attr = $class->attributes('id'),
      "We should be able to directly access the id attribute object";
    isa_ok($attr, 'Kinetic::Meta::Attribute');
    ok !grep({ $_->name eq 'id' } $class->attributes),
      "A call to attributes() should not include private attribute id";
    {
        package Kinetic::Store;
        Test::More::ok grep({ $_->name eq 'id' } $class->attributes),
          "But it should include it when we mock the Kinetic::Store package";
    }
}

sub test_dbh : Test(2) {
    my $test = shift;
    my $class = $test->test_class;
    if ($class eq 'Kinetic::Store::DB') {
        throws_ok { $class->_connect_args }
          'Kinetic::Util::Exception::Fatal::Unimplemented',
          "_connect_args should throw an exception";
        $test->{db_mock}->unmock('_dbh');
        throws_ok { $class->_dbh }
          'Kinetic::Util::Exception::Fatal::Unimplemented',
          "_dbh should throw an exception";
        $test->{db_mock}->mock(_dbh => $test->{dbh});
    } else {
        ok @{[$class->new->_connect_args]},
          "$class\::_connect_args should return values";
        # Only run the next test if we're testing a live data store.
        (my $store = $class) =~ s/.*:://;
        return "Not testing $store" unless $test->supported(lc $store);
        my $dbh = $class->new->_dbh;
        isa_ok $dbh, 'DBI::db';
        $dbh->disconnect;
    }
}

sub where_clause : Test(11) {
    my $store = Store->new;
    $store->{search_class} = One->new->my_class;
    my $my_class = MockModule->new('Kinetic::Meta::Class');
    my $current_column;
    $my_class->mock(attributes => sub {
        $current_column = $_[1];
        bless {} => Attribute
    });
    my $attr = MockModule->new(Attribute);
    my %attributes = (
        name => 'string',
        desc => 'string',
        age  => 'int',
        this => 'weird_type',
        bog  => 'asdf',
    );
    $attr->mock(type => sub {
        my ($self) = @_;
        $current_column = 'bog' unless exists $attributes{$current_column};
        return $attributes{$current_column};
    });
    can_ok $store, '_make_where_clause';
    $store->{search_data}{columns} = [qw/name desc/]; # so it doesn't think it's an object search
    $store->{search_data}{lookup}  = {name => undef, desc => undef}; # so it doesn't think it's an object search
    my ($where, $bind) = $store->_make_where_clause([
        name => 'foo',
        desc => 'bar',
    ]);
    is $where, '(LOWER(name) = LOWER(?) AND LOWER(desc) = LOWER(?))',
        'and simple compound where snippets should succeed';
    is_deeply $bind, [qw/foo bar/],
        'and return the correct bind params';

    $store->{search_data}{columns} = [qw/name desc this/]; # so it doesn't think it's an object search
    $store->{search_data}{lookup}  = {name => undef, desc => undef, this => undef}; # so it doesn't think it's an object search
    ($where, $bind) = $store->_make_where_clause([
        name => 'foo',
        [
            desc => 'bar',
            this => 'that',
        ],
    ]);
    is $where, '(LOWER(name) = LOWER(?) AND (LOWER(desc) = LOWER(?) AND this = ?))',
        'and compound where snippets with array refs should succeed';
    is_deeply $bind, [qw/foo bar that/],
        'and return the correct bind params';

    ($where, $bind) = $store->_make_where_clause([
        name => 'foo',
        OR(
            desc => 'bar',
            this => 'that',
        ),
    ]);
    is $where, '(LOWER(name) = LOWER(?) OR (LOWER(desc) = LOWER(?) AND this = ?))',
        'and compound where snippets with array refs should succeed';
    is_deeply $bind, [qw/foo bar that/],
        'and return the correct bind params';

    $store->{search_data}{columns} = [qw/
        last_name
        first_name 
        bio 
        one__type 
        one__value 
        fav_number
    /]; # so it doesn't think it's an object search
    $store->{search_data}{lookup} = {};
    @{$store->{search_data}{lookup}}{@{$store->{search_data}{columns}}} = undef;
    ($where, $bind) = $store->_make_where_clause([
        [
            last_name  => 'Wall',
            first_name => 'Larry',
        ],
        OR( bio => LIKE '%perl%'),
        OR(
          'one.type'  => LIKE 'email',
          'one.value' => LIKE '@cpan\.org$',
          'fav_number'    => GE 42
        )
    ]);
    is $where, '((last_name = ? AND first_name = ?) OR (bio  LIKE ?) OR '
              .'(one__type  LIKE ? AND one__value  LIKE ? AND fav_number >= ?))',
        'Even very complex conditions should be manageable';
    is_deeply $bind, [qw/Wall Larry %perl% email @cpan\.org$ 42/],
        'and be able to generate the correct bindings';

    ($where, $bind) = $store->_make_where_clause([
        AND(
            last_name  => 'Wall',
            first_name => 'Larry',
        ),
        OR( bio => LIKE '%perl%'),
        OR(
          'one.type'  => LIKE 'email',
          'one.value' => LIKE '@cpan\.org$',
          'fav_number'    => GE 42
        )
    ]);
    is $where, '((last_name = ? AND first_name = ?) OR (bio  LIKE ?) OR '
              .'(one__type  LIKE ? AND one__value  LIKE ? AND fav_number >= ?))',
        'Even very complex conditions should be manageable';
    is_deeply $bind, [qw/Wall Larry %perl% email @cpan\.org$ 42/],
        'and be able to generate the correct bindings';
}

sub set_search_data : Test(9) {
    my $method = '_set_search_data';
    can_ok Store, $method;
    my $one_class = One->new->my_class;
    my $store     = Store->new;
    $store->search_class($one_class);
    $store->$method;
    ok my $results = $store->_search_data,
        "Calling $method for simple types should succeed";
    my @keys      = sort keys %$results;
    is_deeply \@keys, [qw/build_order columns lookup  metadata/],
        'and it should return the types of data that we are looking for';
    is_deeply [sort @{$results->{columns}}],
        [qw/bool description id name state uuid/],
        'which correctly identify the sql column names';
    is_deeply $results->{metadata},
        {
            'TestApp::Simple::One' => {
                columns => {
                    bool        => 'bool',
                    description => 'description',
                    uuid        => 'uuid',
                    id          => 'id',
                    name        => 'name',
                    state       => 'state',
                }
            }
        },
        'and the metadata needed to build the objects';

    my $two_class = Two->new->my_class;
    $store->search_class($two_class);
    ok $results = $store->$method->_search_data,
        "Calling $method for complex types should succeed";
    @keys      = sort keys %$results;
    is_deeply \@keys, [qw/build_order columns lookup  metadata/],
        'and it should return the types of data that we are looking for';
    is_deeply [sort @{$results->{columns}}],
    [qw/ age date description id name one__bool one__description one__id
         one__name one__state one__uuid state uuid /],
        'which correctly identify the sql column names';
    my $metadata = {
        'TestApp::Simple::One' => {
            columns => {
                one__bool        => 'bool',
                one__description => 'description',
                one__uuid        => 'uuid',
                one__id          => 'id',
                one__name        => 'name',
                one__state       => 'state',
            }
        },
        'TestApp::Simple::Two' => {
            contains => {
                one__id => One->new->my_class
            },
            columns => {
                age         => 'age',
                date        => 'date',
                description => 'description',
                uuid        => 'uuid',
                id          => 'id',
                name        => 'name',
                one__id     => 'one__id',
                state       => 'state',
            }
        }
    };
    is_deeply $results->{metadata}, $metadata,
        'and the necessary information to build the multiple objects';
}

sub search : Test(1) {
    my $method = 'search';
    can_ok Store, $method;
    diag "Hey, where's the rest of this test?";
}

sub build_objects : Test(16) {
    my $method = '_build_object_from_hashref';
    can_ok Store, $method;
    my %sql_data =(
        id               => 2,
        uuid             => 'two asdfasdfasdfasdf',
        name             => 'two name',
        description      => 'two fake description',
        state            => 1,
        one__id          => 17,
        age              => 23,
        one__uuid        => 'one ASDFASDFASDFASDF',
        one__name        => 'one name',
        one__description => 'one fake description',
        one__state       => 1,
        one__bool        => 0
    );
    my $store = Store->new;
    $store->{search_data} = {
      metadata => {
        'TestApp::Simple::One' => {
          columns => {
            one__bool        => 'bool',
            one__description => 'description',
            one__uuid        => 'uuid',
            one__id          => 'id',
            one__name        => 'name',
            one__state       => 'state',
          }
        },
        'TestApp::Simple::Two' => {
          contains => {
            one__id => One->new->my_class,
          },
          columns => {
            age         => 'age',
            description => 'description',
            uuid        => 'uuid',
            id          => 'id',
            name        => 'name',
            one__id     => 'one__id',
            state       => 'state',
          }
        }
      },
      build_order => [
        'TestApp::Simple::One',
        'TestApp::Simple::Two',
      ],
    };
    my $two_class = Two->new->my_class;
    $store->search_class($two_class);
    my $object = $store->$method(\%sql_data);
    isa_ok $object, $two_class->package, 'and the object it returns';
    foreach my $attr (qw/uuid name description age/) {
        is $object->$attr, $sql_data{$attr},
            'and basic attributes should be correct';
    }
    isa_ok $object->state, 'Kinetic::Util::State',
        'and Kinetic::Util::State objects should be handled correctly';

    ok my $one = $object->one,
        "and we should be able to fetch the contained object";
    isa_ok $one, One->new->my_class->package,
        "and the contained object";
    is $one->{id}, 17, 'and it should have the correct id';
    is $one->uuid, 'one ASDFASDFASDFASDF', 'and basic attributes should be correct';
    is $one->name, 'one name', 'and basic attributes should be correct';
    is $one->description, 'one fake description', 'and basic attributes should be correct';
    is $one->bool, 0, 'and basic attributes should be correct';
    is $one->state+0, 1, 'and basic attributes should be correct';
    isa_ok $one->state, 'Kinetic::Util::State',
        'and Kinetic::Util::State objects should be handled correctly';
}

sub save : Test(12) {
    my $test = shift;
    my $store = Kinetic::Store->new;
    my $dbh   = $store->_dbh;
    my $mock = MockModule->new(Store);
    my ($update, $insert, $begin, $commit, $rollback);
    $mock->mock(_update => sub { $update = 1; $insert = 0 });
    $mock->mock(_insert => sub { $update = 0; $insert = 1 });
    $mock->mock(_dbh => $dbh );
    my $dbi = MockModule->new('DBI::db', no_auto => 1);
    $dbi->mock(begin_work => sub { $begin++ });
    $dbi->mock(commit => sub { $commit++ });
    $dbi->mock(rollback => sub { $rollback++ });
    my $object = One->new;
    can_ok Store, 'save';
    Store->save($object);
    is $begin, 1, 'it should have started work';
    is $commit, 1, 'it should have commited the work';
    is $rollback, undef, 'it should not have rolled back the work';
    ok $insert, 'and calling it with an object with no id key should call _insert()';
    $object->{id} = 1;
    Store->save($object);
    ok $update, 'and calling it with an object with an id key should call _update()';
    is $begin, 2, 'it should have started work';
    is $commit, 2, 'it should have commited the work';
    is $rollback, undef, 'it should not have rolled back the work';
    # Now trigger an exception.
    $mock->mock(_save => sub { die 'Yow!' });
    eval { Store->save($object) };
    is $begin, 3, 'it should have started work';
    is $commit, 2, 'it should have not commited the work';
    is $rollback, 1, 'it should have rolled back the work';
    $dbh->disconnect;
}

sub save_contained : Test(1) {
    my $object2 = Two->new;
    my $one     = One->new;
    $object2->one($one);
    my $mock = MockModule->new(Store);
    my ($update, $insert);
    $mock->mock(_update => sub { $update = 1; $insert = 0 });
    $mock->mock(_insert => sub { $update = 0; $insert = 1 });
    my $store = Kinetic::Store->new;
    my $dbh   = $store->_dbh;
    $mock->mock(_dbh => $dbh );
    $store->save($object2);
    ok $insert, 'Saving a new object with a contained object should insert';
    $dbh->disconnect;
}

sub insert : Test(7) {
    my $test = shift;
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

    my $one = One->new;
    $mock_store->mock(_set_id => sub { $one->{id} = 2002 } );
    $one->name('Ovid');
    $one->description('test class');

    can_ok Store, '_insert';
    my $expected    = q{INSERT INTO one (uuid, state, name, description, bool) VALUES (?, ?, ?, ?, ?)};
    my $bind_params = [
        '1', # state: Active
        'Ovid',
        'test class',
        '1'  # bool
    ];
    ok ! $one->{id}, 'And a new object should not have an id';
    my @attributes = $one->my_class->attributes;
    my $store = Store->new;
    @{$store}{qw/search_class view columns values/} = (
        One->new->my_class,
        'one',
        [map { $_->_column } @attributes],
        [map { $_->raw($one) } @attributes],
    );
    ok $store->_insert($one),
        'and calling it should succeed';
    is $SQL, $expected,
        'and it should generate the correct sql';
    my $uuid = shift @$BIND;
    is_deeply $BIND, $bind_params,
        'and the correct bind params';
    ok exists $one->{id}, 'and an id should be created';
    is $one->{id}, 2002, 'and it should have the last insert id the database returned';
}

sub update : Test(7) {
    my $test = shift;
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

    my $one = One->new;
    $one->name('Ovid');
    $one->description('test class');
    can_ok Store, '_update';
    $one->{id} = 42;
    # XXX The uuid should not change, should it?  I should
    # exclude it from this?
    my $expected = "UPDATE one SET uuid = ?, state = ?, name = ?, description = ?, "
                  ."bool = ? WHERE id = ?";
    my $bind_params = [
        '1', # state: Active
        'Ovid',
        'test class',
        '1'  # bool
    ];
    my @attributes = $one->my_class->attributes;
    my $store = Store->new;
    @{$store}{qw/search_class view columns values/} = (
        One->new->my_class,
        'one',
        [map { $_->_column } @attributes],
        [map { $_->raw($one) } @attributes],
    );
    ok $store->_update($one),
        'and calling it should succeed';
    is $SQL, $expected,
        'and it should generate the correct sql';
    my $uuid = shift @$BIND;
    my $id   = pop @$BIND;
    is $one->uuid, $uuid, 'and the uuid should be correct';
    is $one->{id}, $id, 'and the final bind param is the id';
    is_deeply $BIND, $bind_params,
        'and the correct bind params';
    is $one->{id}, 42, 'and the private id should not be changed';
}

sub constraints : Test(4) {
    can_ok Store, '_constraints';
    is Store->_constraints({order_by => 'name'}), ' ORDER BY name',
        'and it should build a valid order by clause';
    is Store->_constraints({order_by => [qw/foo bar/]}),
        ' ORDER BY foo, bar',
        'even if we have multiple order by columns';
    is Store->_constraints({order_by => 'name', sort_order => ASC}),
        ' ORDER BY name ASC',
        'and ORDER BY can be ascending or descending';
}

1;
