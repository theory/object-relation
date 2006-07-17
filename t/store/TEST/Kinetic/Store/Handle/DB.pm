package TEST::Kinetic::Store::Handle::DB;

# $Id$

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Encode qw(is_utf8);
use base 'TEST::Kinetic::Store::Handle';

use aliased 'Test::MockModule';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Meta::Attribute';
use aliased 'Kinetic::Store::Handle' => 'DONT_USE', ':all';
use aliased 'Kinetic::Store::Handle::DB' => 'Store';
use aliased 'Kinetic::DataType::State';

use aliased 'TestApp::Simple';
use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';
use aliased 'TestApp::Extend';
use aliased 'TestApp::Relation';
use aliased 'TestApp::Composed';
use aliased 'TestApp::TypesTest';
use aliased 'TestApp::Yello';

__PACKAGE__->SKIP_CLASS(
    $ENV{KS_CLASS}
    ? 0
    : "Not testing Data Stores"
) if caller;    # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub _num_recs {
    my ( $test, $table ) = @_;
    my $result = $test->dbh->selectrow_arrayref("SELECT count(*) FROM $table");
    return $result->[0];
}

my $debugging = 0;

sub setup : Test(setup) {
    my $test = shift;
    $test->mock_dbh;
    $test->create_test_objects;
}

sub teardown : Test(teardown) {
    my $test = shift;
    $test->unmock_dbh;
}

sub shutdown : Test(shutdown) {
    my $test = shift;
    $test->dbh->disconnect;
}

sub test_id : Test(5) {

    # Test the private ID attribute added by Kinetic::Store::Handle::DB.
    my $self = shift;
    ok my $class = One->my_class, "We should get the class object";
    ok my $attr = $class->attributes('id'),
      "We should be able to directly access the id attribute object";
    isa_ok( $attr, 'Kinetic::Meta::Attribute' );
    ok !grep( { $_->name eq 'id' } $class->attributes ),
      "A call to attributes() should not include private attribute id";
    {
        package Kinetic::Store::Handle;
        Test::More::ok grep( { $_->name eq 'id' } $class->attributes ),
          "But it should include it when we mock the Kinetic::Store::Handle package";
    }
}

sub test_dbh : Test(2) {
    my $test  = shift;
    my $class = $test->test_class;
    if ( $class eq 'Kinetic::Store::Handle::DB' ) {
        throws_ok { $class->_connect_attrs }
          'Kinetic::Util::Exception::Fatal::Unimplemented',
          "_connect_attrs should throw an exception";
        $test->{db_mock}->unmock('_dbh');
        throws_ok { $class->_dbh }
          'Kinetic::Util::Exception::Fatal::Unimplemented',
          "_dbh should throw an exception";
        $test->{db_mock}->mock( _dbh => $test->dbh );
    }
    else {
        ok @{ [ $class->new->_connect_attrs ] },
          "$class\::_connect_attrs should return values";

        # Only run the next test if we're testing a live data store.
        ( my $store = $class ) =~ s/Kinetic::Store:://;
        return "Not testing $store"
            unless $ENV{KS_CLASS} && $ENV{KS_CLASS} =~ /$store$/;
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
    $my_class->mock(
        attributes => sub {
            $current_column = $_[1];
            bless {} => Attribute;
        }
    );
    my $attr       = MockModule->new(Attribute);
    my %attributes = (
        name => 'string',
        desc => 'string',
        age  => 'int',
        this => 'weird_type',
        bog  => 'asdf',
    );
    $attr->mock(
        type => sub {
            my ($self) = @_;
            $current_column = 'bog' unless exists $attributes{$current_column};
            return $attributes{$current_column};
        }
    );
    can_ok $store, '_make_where_clause';
    $store->{search_data}{lookup} = {
        "one.name" => undef,
        "one.desc" => undef
    };                    # so it doesn't think it's an object search

    # needed internally
    $store->{search_type} = 'CODE';
    my ( $where, $bind ) = $store->_make_where_clause(
        $store->_parse_search_request(
            [
                name => 'foo',
                desc => 'bar',
            ]
        )
    );
    is $where,
      '(LOWER(one.name) = LOWER(?) AND LOWER(one.desc) = LOWER(?)) AND one.state > ?',
      'and simple compound where snippets should succeed';
    is_deeply $bind, [qw/foo bar -1/], 'and return the correct bind params';
    $store->{search_data}{lookup} = {
        "one.name" => undef,
        "one.desc" => undef,
        "one.this" => undef
    };                         # so it doesn't think it's an object search
    ( $where, $bind ) = $store->_make_where_clause(
        $store->_parse_search_request(
            [
                name => 'foo',
                [
                    desc => 'bar',
                    this => 'that',
                ],
            ]
        )
    );
    is $where,
      '(LOWER(one.name) = LOWER(?) AND (LOWER(one.desc) = LOWER(?) AND one.this = ?)) AND one.state > ?',
      'and compound where snippets with array refs should succeed';
    is_deeply $bind, [qw/foo bar that -1/], 'and return the correct bind params';

    ( $where, $bind ) = $store->_make_where_clause(
        $store->_parse_search_request(
            [
                name => 'foo',
                OR(
                    desc => 'bar',
                    this => 'that',
                ),
            ]
        )
    );
    is $where,
      '(LOWER(one.name) = LOWER(?) OR (LOWER(one.desc) = LOWER(?) AND one.this = ?)) AND one.state > ?',
      'and compound where snippets with array refs should succeed';
    is_deeply $bind, [qw/foo bar that -1/],
      'and return the correct bind params';

    $store->{search_data}{columns} = [
        qw/
          two.last_name
          two.first_name
          two.bio
          two.one__type
          two.one__value
          two.fav_number
          /
    ];    # so it doesn't think it's an object search
    $store->{search_data}{lookup} = {};
    $store->{search_class} = Two->my_class;
    @{ $store->{search_data}{lookup} }{ @{ $store->{search_data}{columns} } } =
      undef;
    ( $where, $bind ) = $store->_make_where_clause(
        $store->_parse_search_request(
            [
                [
                    last_name  => 'Wall',
                    first_name => 'Larry',
                ],
                OR( bio => LIKE '%perl%' ),
                OR(
                    'one.type'   => LIKE 'email',
                    'one.value'  => LIKE '@cpan\.org$',
                    'fav_number' => GE 42
                )
            ]
        )
    );
    is $where,
      '((two.last_name = ? AND two.first_name = ?) OR (two.bio  LIKE ?) OR '
      . '(two.one__type  LIKE ? AND two.one__value  LIKE ? AND two.fav_number >= ?)) AND two.state > ?',
      'Even very complex conditions should be manageable';
    is_deeply $bind, [qw/Wall Larry %perl% email @cpan\.org$ 42 -1/],
      'and be able to generate the correct bindings';

    ( $where, $bind ) = $store->_make_where_clause(
        $store->_parse_search_request(
            [
                AND(
                    last_name  => 'Wall',
                    first_name => 'Larry',
                ),
                OR( bio => LIKE '%perl%' ),
                OR(
                    'one.type'   => LIKE 'email',
                    'one.value'  => LIKE '@cpan\.org$',
                    'fav_number' => GE 42
                )
            ]
        )
    );
    is $where,
      '((two.last_name = ? AND two.first_name = ?) OR (two.bio  LIKE ?) OR '
      . '(two.one__type  LIKE ? AND two.one__value  LIKE ? AND two.fav_number >= ?)) AND two.state > ?',
      'Even very complex conditions should be manageable';
    is_deeply $bind, [qw/Wall Larry %perl% email @cpan\.org$ 42 -1/],
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
    my @keys = sort keys %$results;
    is_deeply \@keys, [qw/build_order columns lookup  metadata/],
      'and it should return the types of data that we are looking for';
    is_deeply [ sort @{ $results->{columns} } ],
      [qw/one.bool one.description one.id one.name one.state one.uuid/],
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
    @keys = sort keys %$results;
    is_deeply \@keys, [qw/build_order columns lookup  metadata/],
      'and it should return the types of data that we are looking for';
    is_deeply [ sort @{ $results->{columns} } ], [
        map { "two.$_" }
          qw/ age date description id name one__bool one__description one__id
          one__name one__state one__uuid state uuid /
      ],
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
            contains => { one__id => One->new->my_class },
            columns  => {
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

sub build_objects : Test(16) {
    my $method = '_build_object_from_hashref';
    can_ok Store, $method;
    my %sql_data = (
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
                contains => { one__id => One->new->my_class, },
                columns  => {
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
        build_order => [ 'TestApp::Simple::One', 'TestApp::Simple::Two', ],
    };
    my $two_class = Two->new->my_class;
    $store->search_class($two_class);
    my $object = $store->$method( \%sql_data );
    isa_ok $object, $two_class->package, 'and the object it returns';

    foreach my $attr (qw/uuid name description age/) {
        is $object->$attr, $sql_data{$attr},
          'and basic attributes should be correct';
    }
    isa_ok $object->state, 'Kinetic::DataType::State',
      'and Kinetic::DataType::State objects should be handled correctly';

    ok my $one = $object->one,
      "and we should be able to fetch the contained object";
    isa_ok $one, One->new->my_class->package, "and the contained object";
    is $one->{id}, 17, 'and it should have the correct id';
    is $one->uuid, 'one ASDFASDFASDFASDF',
      'and basic attributes should be correct';
    is $one->name, 'one name', 'and basic attributes should be correct';
    is $one->description, 'one fake description',
      'and basic attributes should be correct';
    is $one->bool, 0, 'and basic attributes should be correct';
    is $one->state + 0, 1, 'and basic attributes should be correct';
    isa_ok $one->state, 'Kinetic::DataType::State',
      'and Kinetic::DataType::State objects should be handled correctly';
}

sub save : Test(12) {
    my $test  = shift;
    my $store = Kinetic::Store::Handle->new;
    my $dbh   = $store->_dbh;
    my $mock  = MockModule->new(Store);
    my ( $update, $insert, $begin, $commit, $rollback );
    $mock->mock( _update => sub { $update = 1; $insert = 0 } );
    $mock->mock( _insert => sub { $update = 0; $insert = 1 } );
    $mock->mock( _dbh => $dbh );
    my $dbi = MockModule->new( 'DBI::db', no_auto => 1 );
    $dbi->mock( begin_work => sub { $begin++ } );
    $dbi->mock( commit     => sub { $commit++ } );
    $dbi->mock( rollback   => sub { $rollback++ } );
    my $object = One->new;
    can_ok Store, 'save';
    Store->save($object);
    is $begin,  1, 'it should have started work';
    is $commit, 1, 'it should have committed the work';
    is $rollback, undef, 'it should not have rolled back the work';
    ok $insert,
      'and calling it with an object with no id key should call _insert()';
    $object->{id} = 1;
    Store->save($object);
    ok $update,
      'and calling it with an object with an id key should call _update()';
    is $begin,  2, 'it should have started work';
    is $commit, 2, 'it should have committed the work';
    is $rollback, undef, 'it should not have rolled back the work';

    # Now trigger an exception.
    $mock->mock( _save => sub { die 'Yow!' } );
    eval { Store->save($object) };
    is $begin,    3, 'it should have started work';
    is $commit,   2, 'it should have not committed the work';
    is $rollback, 1, 'it should have rolled back the work';
    $dbh->disconnect;
}

sub save_contained : Test(1) {
    my $object2 = Two->new;
    my $one     = One->new;
    $object2->one($one);
    my $mock = MockModule->new(Store);
    my ( $update, $insert );
    $mock->mock( _update => sub { $update = 1; $insert = 0 } );
    $mock->mock( _insert => sub { $update = 0; $insert = 1 } );
    my $store = Kinetic::Store::Handle->new;
    my $dbh   = $store->_dbh;
    $mock->mock( _dbh => $dbh );
    $store->save($object2);
    ok $insert, 'Saving a new object with a contained object should insert';
    $dbh->disconnect;
}

sub insert : Test(7) {
    my $test       = shift;
    my ($sth, $BIND);

    my $mock_sth = MockModule->new('DBI::st', no_auto => 1);
    $mock_sth->mock(
        execute => sub {
            $sth = shift;
            $BIND = \@_;
            return 1;
        },
    );

    my $one = One->new;
    my $mock_store = MockModule->new(Store);
    $mock_store->mock( _set_id => sub { $one->{id} = 2002 } );
    $one->name('Ovid');
    $one->description('test class');

    can_ok Store, '_insert';
    my $expected = q{INSERT INTO one (uuid, state, name, description, bool) }
                 . q{VALUES (?, ?, ?, ?, ?)};
    my $bind_params = [
        '1',    # state: Active
        'Ovid',
        'test class',
        '1'     # bool
    ];
    ok !$one->{id}, 'And a new object should not have an id';
    my @attributes = $one->my_class->attributes;
    my $store      = Store->new;
    @{$store}{qw/search_class view columns values/} = (
        One->new->my_class, 'one',
        [ map { $_->_column } @attributes ],
        [ map { $_->raw($one) } @attributes ],
    );
    ok $store->_insert($one), 'and calling it should succeed';
    is $sth->{Statement}, $expected, 'and it should generate the correct sql';
    my $params = $sth->{ParamValues};
    my $uuid = shift @$BIND;
    is_deeply $BIND, $bind_params, 'and the correct bind params';
    ok exists $one->{id}, 'and an id should be created';
    is $one->{id}, 2002,
      'and it should have the last insert id the database returned';
}

sub update : Test(7) {
    my $test = shift;
    my ($sth, $BIND);
    my $mock_sth = MockModule->new('DBI::st', no_auto => 1);
    $mock_sth->mock(
        execute => sub {
            $sth = shift;
            $BIND = \@_;
            return 1;
        },
    );

    my $one = One->new;
    $one->name('Ovid');
    $one->description('test class');
    can_ok Store, '_update';
    $one->{id} = 42;

    # exclude it from this?
    my $expected = 'UPDATE one SET description = ?, name = ? WHERE id = ?';
    my $bind_params = [ 'test class' ];
    my @attributes = $one->my_class->attributes;
    my $store      = Store->new;
    @{$store}{qw/search_class view columns values/} = (
        One->new->my_class, 'one',
        [ map { $_->_column } @attributes ],
        [ map { $_->raw($one) } @attributes ],
    );
    ok $store->_update($one), 'and calling it should succeed';
    is $sth->{Statement}, $expected, 'and it should generate the correct sql';
    my $desc = shift @$BIND;
    my $name = shift @$BIND;
    my $id   = pop @$BIND;
    is $one->description, $desc, 'and the description should be correct';
    is $one->name, $name, 'and the name should be correct';
    is $one->{id}, $id, 'and the final bind param is the id';
    is $one->{id}, 42, 'and the private id should not be changed';
}

sub query_match : Test(6) {
    my $test = shift;
    return 'Skip query_match for abstract class' unless $test->_should_run;
    my ($foo, $bar, $baz) = $test->test_objects;
    my $store = Kinetic::Store::Handle->new;
    my $iterator = $store->query( $foo->my_class,
        name => MATCH '^(f|ba)',
        { order_by => 'name' }
    );
    my @items = $test->_all_items($iterator);
    is @items, 2, 'Searches should accept regular expressions';
    is_deeply \@items, [$bar, $foo], 'and should include the correct items';

    $iterator = $store->query( $foo->my_class,
        name => NOT MATCH '^(f|ba)',
        { order_by => 'name' }
    );
    @items = $test->_all_items($iterator);
    is @items, 1, 'and regexes should return the correct number of items';
    is_deeply \@items, [$baz], 'and should include the correct items';

    $iterator = $store->query($foo->my_class, name => MATCH 'z$');
    @items = $test->_all_items($iterator);
    is @items, 1, 'and regexes should return the correct number of items';
    is_deeply \@items, [$baz], 'and should include the correct items';
}

sub constraints : Test(5) {
    can_ok Store, '_constraints';
    my $store = Store->new;
    $store->{search_class} = One->my_class;
    is $store->_constraints( { order_by => 'name' } ), ' ORDER BY one.name',
      'and it should build a valid order by clause';
    is $store->_constraints( { order_by => [qw/name bool/] } ),
      ' ORDER BY one.name, one.bool', 'even if we have multiple order by columns';
    is $store->_constraints( { order_by => 'name', sort_order => ASC } ),
      ' ORDER BY one.name ASC', 'and ORDER BY can be ascending or descending';
    is $store->_constraints( { order_by => 'two.name' } ),
      ' ORDER BY two.name', 'but it ignores attributes not in the search class';
}

sub test_extend : Test(45) {
    my $self = shift;
    return 'Skip test_extend for abstract class' unless $self->_should_run;

    # Create a One object for the Two objects to reference.
    ok my $one = One->new(name => 'One'), 'Create a One object';
    ok $one->save, 'Save the one object';

    # Create a new Extend object without a pre-existing Two object.
    ok my $extend = Extend->new( name => 'Extend', one => $one),
        'Create Extend with no existing Two';
    isa_ok $extend, Extend;

    # Let's check out the SQL that gets sent off.
    my ($sql, $vals);
    my $execute = sub {
        my $sth = shift;
        ($sql = $sth->{Statement}) =~ s/\d+/ /g;
        $sql =~ s/\d+$//;
        $sql =~ s/^\d+//;
        $vals = \@_;
    };

    my $mock_sth = MockModule->new('DBI::st', no_auto => 1);
    $mock_sth->mock(execute => $execute );

    my $mocker = Test::MockModule->new('Kinetic::Store::Handle::DB');
    $mocker->mock(_set_ids => 1);

    ok $extend->save, 'Call the save method';
    is $sql, 'INSERT INTO extend (uuid, state, two__id, two__uuid, '
           . 'two__state, two__name, two__description, two__one__id, '
           . 'two__age, two__date) '
           . 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        'It should insert the Extend and Two data into the view';

    is_deeply $vals, [
        $extend->uuid,
        $extend->state->value,
        undef, # two__id
        $extend->two_uuid,
        $extend->two_state->value,
        $extend->name,
        $extend->description,
        $extend->one->id,
        $extend->age,
        $extend->date,
    ], 'It should set the proper values';

    # Now do the save for real.
    $mocker->unmock_all;
    $mock_sth->unmock_all;
    ok $extend->save, 'Save the extend object';

    isa_ok my $two = $extend->two, Two;
    is $extend->one->uuid, $one->uuid,
        'It should reference the one object';
    is $extend->two->one->uuid, $one->uuid,
        'The Two object should reference the One object';

    # Look it up to be sure that it's the same.
    ok $extend = Extend->lookup( uuid => $extend->uuid ),
        'Look up the Extend object';
    is $two->uuid, $two->uuid, 'It should still refrence the Two object';
    is $extend->one->uuid, $one->uuid,
        'It should still reference the one object';
    is $extend->two->one->uuid, $one->uuid,
        'The Two object should still reference the One object';

    # Look up the Two object.
    ok $two = Two->lookup( uuid => $two->uuid ), 'Look up the Two object';
    is $two->uuid, $extend->two->uuid, 'The UUID should be the same';

    # Make a change to the Two object.
    ok $two->name('New Name'), 'Change Two\'s name';
    ok $two->save, 'Save Two with new name';
    TODO: {
        local $TODO = 'Need to implement object caching';
        is $extend->two->name, $two->name,
            'The new name should be in the Extend object';
    }

    # Look up the Two object again.
    ok $two = Two->lookup( uuid => $two->uuid ),
        'Look up the Two object again';
    is $two->name, 'New Name',
        'The Looked-up Two should have the new name';
    TODO: {
        local $TODO = 'Need to implement object caching';
        is $two->name, $extend->two->name,
            'The new name should be in the Extend object';
    }

    ok $extend = Extend->lookup( uuid => $extend->uuid ),
        'Look up the Extend object again';
    is $two->name, $extend->two->name,
        'The new name should be in the looked-up Extend object';

    # Now change the Extend object.
    ok $extend->deactivate, 'Deactivate the Extend object';
    ok $extend->name('LOLO'), 'Rename the Extend object';

    # Check out the UPDATE statement.
    $mock_sth->mock(execute => $execute);
    ok $extend->save, 'Save the extend object';
    is $sql, 'UPDATE extend SET two__name = ?, state = ? WHERE id = ?',
        'It should update Extend and Two view the extend view';
    is_deeply $vals, [
        $extend->name,
        $extend->state->value,
        $extend->id,
    ], 'It should set the proper values';;

    $mock_sth->unmock_all;
    ok $extend->save, 'Save the extend object';

    # Create a second extend object referencing the same Two object.
    ok my $ex2 = Extend->new( two => $extend->two),
        'Create new Extend referencing same two';
    isa_ok $ex2, Extend;
    ok $ex2->save, 'Save the new Extend object';

    is $ex2->one->uuid, $one->uuid,
        'It should reference the one object';
    is $ex2->two->one->uuid, $one->uuid,
        'The Two object should reference the One object';

    # Look it up to be sure that it's the same.
    ok $ex2 = Extend->lookup( uuid => $ex2->uuid ),
        'Look up the Extend object';
    is $ex2->one->uuid, $one->uuid,
        'It should still reference the one object';
    is $ex2->two->one->uuid, $one->uuid,
        'The Two object should still reference the One object';

    # We should now have two Extend objects pointing at the same Two.
    ok my $extends = Extend->query, 'Get all Extend objects';
    isa_ok $extends, 'Kinetic::Util::Iterator', 'it should be a';
    ok my @extends = $extends->all, 'Get extends objects from the iterator';
    is scalar @extends, 2, 'There should be two Extends objects';
    is_deeply [ map { $_->two_uuid } @extends ], [ ($two->uuid) x 2 ],
        'They should have  the same Two object UUID';

    TODO: {
        local $TODO = 'Need to implement object caching';
        is_deeply [ map { '' . $_->two } @extends ], ["$two", "$two"],
            'And in fact they should point to the very same Two object';
    }
}

sub test_has_many : Test(13) {
    my $self = shift;
    return 'Skip test_has_many for abstract class' unless $self->_should_run;
    ok my $yello = Yello->new( age => 32 ), 'Create a Yello object';
    ok $yello->save, 'Save the Yello object';

    ok my $coll = $yello->ones,
        'The collection slot should have a default value';
    isa_ok $coll, 'Kinetic::Util::Collection::One',
        '... and the object it contains';
    my @all = $coll->all;
    ok !@all, '... and it should be an empty collection';

    my @ones = map { One->new( name => $_ ) } qw/uno dos tres/;
    $yello->ones( $coll->from_list( { list => \@ones } ) );
    ok $yello->save,
        'We should be able to save the object with a new collection';
    foreach my $one (@ones) {
        ok defined $one->uuid,
            '... and the collection objects should now have uuids';
    } # 9 tests
    ok my $yello_2 = Yello->lookup( uuid => $yello->uuid ),
        'We should be able to lookup has_many objects';
    $yello_2->state; # inflate
    ok my $coll_2 = $yello_2->ones,
        '... and the should have collections';
    isa_ok $coll_2, 'Kinetic::Util::Collection::One',
        '... and the collection';
    my $all_2 = $coll_2->all;
    $_->state foreach @$all_2;
    is_deeply $all_2, \@ones, '... and it should have the correct objects';
}

sub test_mediate : Test(43) {
    my $self = shift;
    return 'Skip test_mediate for abstract class' unless $self->_should_run;

    # Create a One object for the Relation objects to reference.
    ok my $one = One->new(name => 'One'), 'Create a One object';
    ok $one->save, 'Save the one object';

    # Create a new Relation object without a pre-existing Simple object.
    ok my $relation = Relation->new( name => 'Relation', one => $one),
        'Create Relation with no existing Simple';
    isa_ok $relation, Relation;

    # Let's check out the SQL that gets sent off.
    my ($sql, $vals);
    my $execute = sub {
        my $sth = shift;
        ($sql = $sth->{Statement}) =~ s/\d+/ /g;
        $sql =~ s/\d+$//;
        $sql =~ s/^\d+//;
        $vals = \@_;
    };

    my $mock_sth = MockModule->new('DBI::st', no_auto => 1);
    $mock_sth->mock(execute => $execute );

    my $mocker = Test::MockModule->new('Kinetic::Store::Handle::DB');
    $mocker->mock(_set_ids => 1);

    ok $relation->save, 'Call the save method';
    is $sql, 'INSERT INTO relation (uuid, state, simple__id, simple__uuid, '
           . 'simple__state, simple__name, simple__description, one__id) '
           . 'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        'It should insert the Exend and Simple data into the view';

    is_deeply $vals, [
        $relation->uuid,
        $relation->state->value,
        undef, # simple__id
        $relation->simple_uuid,
        $relation->simple_state->value,
        $relation->name,
        $relation->description,
        $relation->one->id,
    ], 'It should set the proper values';

    # Now do the save for real.
    $mocker->unmock_all;
    $mock_sth->unmock_all;
    ok $relation->save, 'Save the relation object';

    isa_ok my $simple = $relation->simple, Simple;
    is $relation->one->uuid, $one->uuid,
        'It should reference the one object';

    # Look it up to be sure that it's the same.
    ok $relation = Relation->lookup( uuid => $relation->uuid ),
        'Look up the Relation object';
    is $simple->uuid, $simple->uuid, 'It should still refrence the Simple object';
    is $relation->one->uuid, $one->uuid,
        'It should still reference the one object';

    # Look up the Simple object.
    ok $simple = Simple->lookup( uuid => $simple->uuid ),
        'Look up the Simple object';
    is $simple->uuid, $relation->simple->uuid, 'The UUID should be the same';

    # Make a change to the Simple object.
    ok $simple->name('New Name'), 'Change Simple\'s name';
    ok $simple->save, 'Save Simple with new name';
    TODO: {
        local $TODO = 'Need to implement object caching';
        is $relation->simple->name, $simple->name,
            'The new name should be in the Relation object';
    }

    # Look up the Simple object again.
    ok $simple = Simple->lookup( uuid => $simple->uuid ),
        'Look up the Simple object again';
    is $simple->name, 'New Name',
        'The Looked-up Simple should have the new name';
    TODO: {
        local $TODO = 'Need to implement object caching';
        is $simple->name, $relation->simple->name,
            'The new name should be in the Relation object';
    }

    ok $relation = Relation->lookup( uuid => $relation->uuid ),
        'Look up the Relation object again';
    is $simple->name, $relation->simple->name,
        'The new name should be in the looked-up Relation object';

    # Now change the Relation object.
    ok $relation->deactivate, 'Deactivate the Relation object';
    ok $relation->name('LOLO'), 'Rename the Relation object';

    # Check out the UPDATE statement.
    $mock_sth->mock(execute => $execute );
    ok $relation->save, 'Save the relation object';
    is $sql, 'UPDATE relation SET simple__name = ?, state = ? WHERE id = ?',
        'It should update Relation and Simple view the relation view';
    is_deeply $vals, [
        $relation->name,
        $relation->state->value,
        $relation->id,
    ], 'It should set the proper values';;

    $mock_sth->unmock_all;
    ok $relation->save, 'Save the relation object';

    # Make sure that failing to set one results in an exception.
    eval { Relation->new( simple => $relation->simple)->save };
    ok my $err = $@, 'Caught required exception';
    like $err->error, qr/Attribute .one. must be defined/,
        'And it should be the correct exception';

    # Create a second relation object referencing the same Simple object.
    ok my $rel2 = Relation->new( simple => $relation->simple, one => $one),
        'Create new Relation referencing same simple';
    isa_ok $rel2, Relation;
    ok $rel2->save, 'Save the new Relation object';

    is $rel2->one->uuid, $one->uuid,
        'It should reference the one object';

    # Look it up to be sure that it's the same.
    ok $rel2 = Relation->lookup( uuid => $rel2->uuid ),
        'Look up the Relation object';
    is $rel2->one->uuid, $one->uuid,
        'It should still reference the one object';

    # We should now have simple Relation objects pointing at the same Simple.
    ok my $relations = Relation->query, 'Get all Relation objects';
    isa_ok $relations, 'Kinetic::Util::Iterator', 'it should be a';
    ok my @relations = $relations->all, 'Get relations objects from the iterator';
    is scalar @relations, 2, 'There should be simple Relations objects';
    is_deeply [ map { $_->simple_uuid } @relations ], [ ($simple->uuid) x 2 ],
        'They should have  the same Simple object UUID';

    TODO: {
        local $TODO = 'Need to implement object caching';
        is_deeply [ map { '' . $_->simple } @relations ], ["$simple", "$simple"],
            'And in fact they should point to the very same Simple object';
    }
}

sub unique_attr_regex {
    my ($self, $col, $key) = @_;
    return qr/column $col is not unique/;
}

sub test_unique : Test(54) {
    my $self = shift;
    return 'Skip test_unique for abstract class' unless $self->_should_run;

    # Test distinct attribute.
    ok my $simple = Simple->new(name => 'Foo'), 'Create simple object';
    ok $simple->save, '... And save it';
    ok my $simple2 = Simple->new(name => 'Bar'), 'Create another simple';
    $simple2->{uuid} = $simple->uuid; # XXX Don't try this at home.
    throws_ok { $simple2->save } 'Exception::Class::DBI::STH',
         '... Saving it with the same UUID should fail';
    like $@, $self->unique_attr_regex('uuid', 'simple'),
         '... And it should fail with the proper message';

    # Test unique attribute--relative to state.
    ok my $one = One->new(name => 'One')->save, 'Create and save one object';
    ok my $comp = Composed->new(one => $one, color => 'red'),
        'Create composed object';
    ok $comp->save, '... And save it';
    ok my $comp2 = Composed->new(one => $one, color => 'red'),
        'Create another composed object with the same color';
    throws_ok { $comp2->save } 'Exception::Class::DBI::STH',
        '... Saving (INSERT) it should fail';
    like $@, $self->unique_attr_regex('color', 'composed'),
        '... And it should fail with the proper message';

    # Make sure that an update fails.
    ok $comp2->color('blue'), '... So change its color';
    ok $comp2->save, '... Now it should save';
    ok $comp2->color('red'), '... Switch back to the dupe color';
    throws_ok { $comp2->save } 'Exception::Class::DBI::STH',
         '... Saving it (UPDATE) should fail';
    like $@, $self->unique_attr_regex('color', 'composed'),
         '... And it should fail with the proper message';

    # Now try to insert with the other objects deleted (but not purged).
    ok $comp->delete, 'Delete the original Composed object';
    ok $comp->save, '... And save it';
    ok my $comp3 = Composed->new(one => $one, color => 'red'),
        '... Create a third Composed object with color => red';
    ok $comp3->save,
        '... Saving should work, because the other Composed object is deleted';
    ok $comp = Composed->lookup( uuid => $comp->uuid ),
        '... We should still be able to look up the original Composed object';
    is $comp->color, 'red', '... And its color should still be red';
    is $comp->state, Kinetic::DataType::State->DELETED, '... And it should be deleted';

    # Now purge the new Composed so that we can test UPDATE.
    ok $comp3->purge, 'Purge the third Composed object';
    ok $comp3->save, 'Save the purged object';
    ok $comp2->color('red'), 'Set the second composed object to red';
    ok $comp2->save, '... Saving it (UPDATE) should succeed';

    # Undeleting the original red state should fail to save.
    ok $comp->activate, 'Activate the original Composed object';
    throws_ok { $comp->save } 'Exception::Class::DBI::STH',
         '... Saving it (UPDATE) should fail';
    like $@, $self->unique_attr_regex('color', 'composed'),
         '... And it should fail with the proper message';

    # Test unique attribute with state in a parent class.
    ok my $two = Two->new(name => 'Two', one => $one, age => 37),
        'Create two object';
    ok $two->save, '... And save it';
    ok my $two2 = Two->new(name => 'Two2', one => $one, age => 37),
        'Create another two object with the same age';
    throws_ok { $two2->save } 'Exception::Class::DBI::STH',
         '... Saving it (INSERT) should fail';
    like $@, $self->unique_attr_regex('age', 'two'),
         '... And it should fail with the proper message';
    ok $two2->age(36), '... So change its age';
    ok $two2->save, '... Now it should save';
    ok $two2->age(37), '... Switch back to the dupe age';
    throws_ok { $two2->save } 'Exception::Class::DBI::STH',
            '... Saving it (UPDATE) should fail';
    like $@, $self->unique_attr_regex('age', 'two'),
         '... And it should fail with the proper message';

    # Now try to insert with the other objects deleted (but not purged).
    ok $two->delete, 'Delete the original Two object';
    ok $two->save, '... And save it';
    ok my $two3 = Two->new(name => 'Two3', one => $one, age => 37),
        '... Create a third Two object with age => 37';
    ok $two3->save,
        '... Saving should work, because the other Two object is deleted';
    ok $two = Two->lookup( uuid => $two->uuid ),
        '... We should still be able to look up the original Two object';
    is $two->age, 37, '... And its age should still be 37';
    is $two->state, Kinetic::DataType::State->DELETED, '... And it should be deleted';

    # Now purge the new Two so that we can test UPDATE.
    ok $two3->purge, 'Purge the third Two object';
    ok $two3->save, 'Save the purged object';
    ok $two2->age(37), 'Set the second two object to 37';
    ok $two2->save, '... Saving it (UPDATE) should succeed';

    # Undeleting the original red state should fail to save.
    ok $two->activate, 'Activate the original Two object';
    throws_ok { $two->save } 'Exception::Class::DBI::STH',
         '... Saving it (UPDATE) should fail';
    like $@, $self->unique_attr_regex('age', 'two'),
        '... And it should fail with the proper message';
}

sub test_once : Test(2) {
    my $self = shift;
    return 'Skip test_once for abstract class' unless $self->_should_run;

    # Test once attribute "uuid".
    # UPDATEs don't send UUID to the server, because they're once. Views don't
    # pass them on, either, for the same reason. So we have to test it
    # manually against the table. And we have to use the admin password so
    # because users don't have permission to update PostgreSQL tables, just
    # views.
    my $dbh = $self->dbh;
    if (ref($self) =~ /Pg$/) {
        $dbh = DBI->connect(
            $ENV{KS_DSN},
            $ENV{KS_SUPER_USER} || 'postgres',
            $ENV{KS_SUPER_PASS} || '',
            {
                RaiseError     => 0,
                PrintError     => 0,
                pg_enable_utf8 => 1,
                HandleError    => Kinetic::Util::Exception::DBI->handler,
                AutoCommit     => 0,
            }
        );
        $dbh->begin_work;
    }
    my $uuid = Kinetic::Util::Functions::create_uuid();
    $dbh->do(
        q{INSERT INTO simple (uuid, name) VALUES (?, ?)},
        undef,
        $uuid,
        'foo',
    );

    throws_ok {
        $dbh->do(
            q{UPDATE _simple SET uuid = ? WHERE uuid = ?},
            undef,
            Kinetic::Util::Functions::create_uuid(),
            $uuid,
        )
    } 'Exception::Class::DBI::DBH', '... And updating UUID should fail';
    like $@,
        qr/value of _?simple.uuid cannot be changed/,
        '... And it should fail with the proper message';

    if (ref($self) =~ /Pg$/) {
        $dbh->rollback;
        $dbh->disconnect;
    }
}

sub test_insert_state : Test(2) {
    my $self = shift;
    return 'Skip test_insert_state for abstract class'
        unless $self->_should_run;
    my $dbh = $self->dbh;

    # Try to insert a bogus state.
    throws_ok {
        $dbh->do(
            q{INSERT INTO simple (name, state) VALUES (?, ?)},
            undef,
            'Foo',
            12,
        )
    } 'Exception::Class::DBI::DBH', 'Inserting an invalid state should fail';
    like $@, qr/value for domain state violates check constraint "ck_state"/,
        '... And with the proper message';

}

# This has to be a separate test because the dbh gets horked on error.
sub test_update_state : Test(4) {
    my $self = shift;
    return 'Skip test_update_state for abstract class'
        unless $self->_should_run;
    my $dbh = $self->dbh;

    # Try to update to a bogus state.
    ok my $simple = Simple->new(name => 'Foo'), 'Create simple object';
    ok $simple->save, '... And save it';
    throws_ok {
        $dbh->do(
            q{UPDATE simple SET state = ? WHERE uuid = ?},
            undef,
            12,
            $simple->uuid,
        )
    } 'Exception::Class::DBI::DBH',
        'Updating to an invalid state should fail';
    like $@, qr/value for domain state violates check constraint "ck_state"/,
        '... And with the proper message';
}

sub delete_fk_regex {
    my ($self, $col, $key, $table) = @_;
    return qr/delete on table "$table" violates foreign key constraint "fk_$key\_$col/;
}

sub insert_fk_regex {
    my ($self, $col, $key, $table) = @_;
    return qr/insert on table "$table" violates foreign key constraint "fk_$key\_$col/;
}

sub update_fk_regex {
    my ($self, $col, $key, $table) = @_;
    return qr/update on table "$table" violates foreign key constraint "fk_$key\_$col/;
}

sub test_fk_restrict : Test(7) {
    my $self = shift;
    return 'Skip test_fk_restrict for abstract class'
        unless $self->_should_run;

    # First, make sure that RESTRICT works properly.
    ok my $one = One->new(name => 'One'), 'Create One object';
    ok $one->save, '... And save it';
    ok my $comp = Composed->new(one => $one),
        'Create Composed object referencing the One object';
    ok $comp->save, '... And save it';
    ok $one->purge, '... Now purge the One object';
    throws_ok { $one->save } 'Kinetic::Util::Exception::DBI',
        '... And saving it should throw an exception';
    like $@, $self->delete_fk_regex('one_id', 'composed', 'simple_one'),
        '... And it should have the proper error';
}

sub test_fk_cascade : Test(10) {
    my $self = shift;
    return 'Skip test_fk_cascade for abstract class'
        unless $self->_should_run;

    # Create an Extend object.
    ok my $one = One->new(name => 'One'), 'Create One object';
    ok $one->save, '... And save it';
    ok my $two = Two->new(name => 'Two', one => $one), 'Create Two object';
    ok $two->save, '... And save it';
    ok my $extend = Extend->new(name => 'Extend', two => $two),
        'Create Extend object';
    ok $extend->save, '... And save it';
    ok $extend = Extend->lookup(uuid => $extend->uuid),
        '... We should be able to look it up';

    ok $two->purge, 'Now purge the Two object';
    ok $two->save, '... And save it';
    ok !Extend->lookup(uuid => $extend->uuid),
        '... Now there should be no Exend object to look up';
}

sub test_fk_insert : Test(5) {
    my $self = shift;
    return 'Skip test_fk_insert for abstract class'
        unless $self->_should_run;

    ok my $one = One->new(name => 'One'), 'Create One object';
    ok $one->{id} = -1, '... And fake an ID';
    ok my $two = Two->new(name => 'Two', one => $one), 'Create Two object';
    throws_ok { $two->save } 'Kinetic::Util::Exception::DBI',
        '... And it should throw an error for an invalid foreign key';
    like $@, $self->insert_fk_regex('one_id', 'two', 'simple_two'),
        '... Which should have the proper error message';
}

sub test_fk_update : Test(9) {
    my $self = shift;
    return 'Skip test_fk_update for abstract class'
        unless $self->_should_run;

    ok my $one = One->new(name => 'One'), 'Create One object';
    ok $one->save, '... And save it';
    ok my $two = Two->new(name => 'Two', one => $one), 'Create Two object';
    ok $two->save, '... And save it';

    ok $one = One->new(name => 'Another'), 'Create another One object';
    ok $one->{id} = -1, '... Fake its IDs';
    ok $two->one($one), '... And associate it it with the Two object';
    throws_ok { $two->save } 'Kinetic::Util::Exception::DBI',
        '... And it should throw an error for an invalid foreign key';
    like $@, $self->update_fk_regex('one_id', 'two', 'simple_two'),
        '... Which should have the proper error message';
}

sub test_types : Test(138) {
    my $self = shift;
    return 'Skip test_fk_update for abstract class'
        unless $self->_should_run;
    ok my $types_test = TypesTest->new, 'Create new types_test object';

    # Set up the integer attribute.
    is $types_test->integer, undef, 'The integer should be undef';
    ok $types_test->integer(-12),    'Set the integer';
    is $types_test->integer, -12,    'It should be properly set';

    # Set up the whole attribute.
    is $types_test->whole, undef, 'The whole should be undef';
    ok $types_test->whole(0),     'Set the whole';
    is $types_test->whole, 0,     'It should be properly set';

    # Set up the posint attribute.
    is $types_test->posint, undef, 'The posint should be undef';
    ok $types_test->posint(12),    'Set the posint';
    is $types_test->posint, 12,    'It should be properly set';

    # Set up the version attribute.
    is $types_test->version, undef,          'The version should be undef';
    ok my $version = version->new('1.12.3'), 'Create a version object';
    ok $types_test->version($version),       'Set the version';
    isa_ok $types_test->version, 'version',  'It';
    is $types_test->version, $version,       'It should be properly set';

    # Set up the duration attribute.
    is $types_test->duration, undef, 'The duration should be undef';
    ok my $du = Kinetic::DataType::Duration->new(
        years  => 2,
        months => 3,
        hours  => 4,
    ), 'Create a duration object';
    ok $types_test->duration($du), 'Set the duration';
    isa_ok $types_test->duration,  'Kinetic::DataType::Duration', 'It';
    is $types_test->duration, $du, 'It should be properly set';

    # Set up the operator attribute.
    is $types_test->operator, undef, 'The operator should be undef';
    ok $types_test->operator('eq'),  'Set the operator';
    is $types_test->operator, 'eq',  'It should be properly set';

    # Set up the media_type attribute.
    my $mt = Kinetic::DataType::MediaType->new('text/plain');
    is $types_test->media_type, undef, 'The media_type should be undef';
    ok $types_test->media_type($mt),  'Set the media_type';
    is $types_test->media_type, $mt,  'It should be properly set';

    # Set up the attribute attribute.
    ok my $attr = Kinetic::Meta->attr_for_key('simple.name'),
        'Get an attribute object';
    is $types_test->attribute, undef, 'The attribute should be undef';
    ok $types_test->attribute($attr), 'Set the attribute';
    is $types_test->attribute, $attr, 'It should be properly set';
    isa_ok $types_test->attribute,    'Kinetic::Meta::Attribute',  'It';

    # Set up the gtin attribute.
    is $types_test->gtin, undef,     'The gtin should be undef';
    my $gtin = '4007630000116';
    ok $types_test->gtin($gtin),      'Set the gtin';
    is $types_test->gtin, $gtin,      'It should be properly set';

    # Create a nice 32K binary string.
    my $binary;
    $binary .= chr $_ for 0..255;
    $binary .= ($binary) x 128;

    # Set up the binary attribute.
    is $types_test->bin, undef,   'The binary should be undef';
    ok $types_test->bin($binary), 'Set the binary';
    is $types_test->bin, $binary, 'It should be properly set';

    # Save the object.
    ok $types_test->save, 'Save the types_test object';
    ok $types_test = TypesTest->lookup( uuid => $types_test->uuid ),
        'Look up the types_test object';

    # Check the looked-up values.
    is $types_test->integer,     -12,  'Integer should be correct';
    is $types_test->whole,         0,  'Whole should be correct';
    is $types_test->posint,       12,  'Posint should be correct';
    isa_ok $types_test->version,       'version', 'version';
    is $types_test->version, $version, 'It should be properly set';
    isa_ok $types_test->duration,      'Kinetic::DataType::Duration', 'duration';
    is $types_test->duration, $du,     'It should be properly set';
    is $types_test->operator, 'eq',    'Operator should be properly set';
    is $types_test->media_type, $mt,   'Media type should be properly set';
    is $types_test->attribute, $attr,  'Attribute should be properly set';
    is $types_test->gtin, $gtin,       'GTIN should be properly set';
    SKIP: {
        skip 'https://rt.cpan.org/Ticket/Display.html?id=19471', 2
            if $ENV{KS_CLASS} =~ /DB::SQLite$/ && DBD::SQLite->VERSION <= 1.12;
        is $types_test->bin, $binary,      'Binary should be properly set';
        ok !is_utf8($types_test->bin),     'Binary variable should not be utf8';
    }

    # Change the version object.
    ok $version = version->new('3.40'),     'Create new version object';
    ok $types_test->version($version),      'Set the version';
    isa_ok $types_test->version, 'version', 'It';
    is $types_test->version, $version,      'It should be properly set';

    # Change the duration object.
    ok $du = Kinetic::DataType::Duration->new( hours  => 4 ),
        'Create a duration object';
    ok $types_test->duration($du), 'Set the duration';
    isa_ok $types_test->duration,  'Kinetic::DataType::Duration', 'It';
    is $types_test->duration, $du, 'It should be properly set';

    # Change the operator.
    ok $types_test->operator('ne'),  'Set the operator to a new value';
    is $types_test->operator, 'ne',  'It should be properly set';

    # Change the media_type.
    $mt = Kinetic::DataType::MediaType->new('text/html');
    ok $types_test->media_type($mt),  'Set the media_type to a new value';
    is $types_test->media_type, $mt,  'It should be properly set';

    # Change the attribute.
    $attr = Kinetic::Meta->attr_for_key('simple.description');
    ok $types_test->attribute($attr),  'Set the attribute to a new value';
    is $types_test->attribute, $attr,  'It should be properly set';

    # Change the gtin.
    ok $types_test->gtin($gtin = '0036000291452'), 'Set the gtin to a new value';
    is $types_test->gtin, $gtin, 'It should be properly set';

    # Change the binary.
    $binary = reverse $binary;
    ok $types_test->bin($binary), 'Set the binary to a new value';
    is $types_test->bin, $binary, 'It should be properly set';

    # Save it again.
    ok $types_test->save, 'Save TypesTest object again';
    ok $types_test = TypesTest->lookup( uuid => $types_test->uuid ),
        'Look up the types_test object again';

    # Check the looked-up values.
    isa_ok $types_test->version, 'version', 'version';
    is $types_test->version,    $version, 'It should be properly set';
    isa_ok $types_test->duration,         'Kinetic::DataType::Duration', 'duration';
    is $types_test->duration,   $du,      'It should be properly set';
    is $types_test->operator,   'ne',     'Operator should be properly set';
    is $types_test->media_type, $mt,      'Media type should be properly set';
    is $types_test->attribute,  $attr,    'Attribute should be properly set';
    cmp_ok $types_test->gtin, '==', $gtin, 'GTIN should be properly set';
    SKIP: {
        skip 'https://rt.cpan.org/Ticket/Display.html?id=19471', 2
            if $ENV{KS_CLASS} =~ /DB::SQLite$/ && DBD::SQLite->VERSION <= 1.12;
        is $types_test->bin,        $binary,  'Binary should be properly set';
        ok !is_utf8($types_test->bin),        'Binary should not be utf8';
    }

    # Mock store_raw to return the wrong value when appropriate.
    my $orig_straw = Kinetic::Meta::Attribute->can('store_raw');
    my $attr_mock  = MockModule->new('Kinetic::Meta::Attribute');
    my $checking   = '';
    my $ret        = 'foo';
    my $store_mock = sub {
        return $ret if $_[0]->name eq $checking;
        return $orig_straw->(@_)
    };

    # Make sure that invalid integers are not allowed.
    $checking = 'integer';
    $attr_mock->mock(store_raw => $store_mock);
    ok $types_test->integer(-400), 'Change the integer';

    SKIP: {
        skip 'Need to enable SQLite strict affinity', 2
            if $ENV{KS_CLASS} =~ /DB::SQLite$/;
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus integer should fail';
        like $@,
            qr/invalid input syntax for integer: "foo"/,
            '... And it should fail with the proper message';
    }

    # The errors abort the txn, so need a new object to test updates against.
    $attr_mock->unmock_all;
    ok $types_test = TypesTest->new(
        version    => $version,
        duration   => $du,
        operator   => 'eq',
        media_type => $mt,
        integer    => 20,
    ), 'Create another types test object';
    ok $types_test->save, 'Save it';

    # Make sure that invalid whole numbers are not allowed.
    $checking = 'whole';
    $ret      = -12;
    $attr_mock->mock(store_raw => $store_mock);
    ok $types_test->whole(400), 'Change the whole';

    SKIP: {
        # XXX http://archives.postgresql.org/pgsql-patches/2006-01/msg00139.php
        skip 'Domain constraints ignored in PREPAREd statements', 2
            if $ENV{KS_CLASS} =~ /DB::Pg$/
            && $self->dbh->{pg_server_version} <= 80102;
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus whole should fail';
        like $@,
            qr/value for domain "?whole"? violates check constraint "ck_whole"/,
            '... And it should fail with the proper message';
    }

    # The errors abort the txn, so need a new object to test updates against.
    $attr_mock->unmock_all;
    ok $types_test = TypesTest->new(
        version    => $version,
        duration   => $du,
        operator   => 'eq',
        media_type => $mt,
        integer    => 20,
    ), 'Create another types test object';
    ok $types_test->save, 'Save it';

    # Make sure that invalid posints are not allowed.
    $checking = 'posint';
    $ret      = 0;
    $attr_mock->mock(store_raw => $store_mock);
    ok $types_test->posint(400), 'Change the posint';

    SKIP: {
        # XXX http://archives.postgresql.org/pgsql-patches/2006-01/msg00139.php
        skip 'Domain constraints ignored in PREPAREd statements', 2
            if $ENV{KS_CLASS} =~ /DB::Pg$/
            && $self->dbh->{pg_server_version} <= 80102;
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus posint should fail';
        like $@,
            qr/value for domain "?posint"? violates check constraint "ck_posint"/,
            '... And it should fail with the proper message';
    }

    # The errors abort the txn, so need a new object to test updates against.
    $attr_mock->unmock_all;
    ok $types_test = TypesTest->new(
        version    => $version,
        duration   => $du,
        operator   => 'eq',
        media_type => $mt,
        integer    => 20,
    ), 'Create another types test object';
    ok $types_test->save, 'Save it';

    # Make sure that invalid operators are not allowed.
    $checking = 'operator';
    $ret      = 'foo';
    $attr_mock->mock(store_raw => $store_mock);
    ok $types_test->operator('lt'), 'Change the operator';

    SKIP: {
        # XXX http://archives.postgresql.org/pgsql-patches/2006-01/msg00139.php
        skip 'Domain constraints ignored in PREPAREd statements', 2
            if $ENV{KS_CLASS} =~ /DB::Pg$/
            && $self->dbh->{pg_server_version} <= 80102;
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus operator should fail';
        like $@,
            qr/value for domain "?operator"? violates check constraint "ck_operator"/,
            '... And it should fail with the proper message';
    }

    # The errors abort the txn, so need a new object to test updates against.
    $attr_mock->unmock_all;
    ok $types_test = TypesTest->new(
        version    => $version,
        duration   => $du,
        operator   => 'eq',
        media_type => $mt,
        integer    => 20,
    ), 'Create another types test object';
    ok $types_test->save, 'Save it';

    # Make sure that invalid media_types are not allowed.
    $mt = Kinetic::DataType::MediaType->new('text/xml');
    ok $types_test->media_type($mt), 'Change the media_type';
    $checking = 'media_type';
    $attr_mock->mock(store_raw => $store_mock);

    SKIP: {
        # XXX http://archives.postgresql.org/pgsql-patches/2006-01/msg00139.php
        skip 'Domain constraints ignored in PREPAREd statements', 2
            if $ENV{KS_CLASS} =~ /DB::Pg$/
            && $self->dbh->{pg_server_version} <= 80102;
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus media_type should fail';
        like $@,
            qr/value for domain media_type violates check constraint "ck_media_type"/,
            '... And it should fail with the proper message';
    }

    # The errors abort the txn, so need a new object to test updates against.
    $attr_mock->unmock_all;
    ok $types_test = TypesTest->new(
        version    => $version,
        duration   => $du,
        operator   => 'eq',
        media_type => $mt,
        integer    => 20,
    ), 'Create another types test object';
    ok $types_test->save, 'Save it';

    # Make sure that invalid attributes are not allowed.
    $attr = Kinetic::Meta->attr_for_key('simple.name');
    ok $types_test->attribute($attr), 'Change the attribute';
    $checking = 'attribute';
    $attr_mock->mock(store_raw => $store_mock);

    SKIP: {
        # XXX http://archives.postgresql.org/pgsql-patches/2006-01/msg00139.php
        skip 'Domain constraints ignored in PREPAREd statements', 2
            if $ENV{KS_CLASS} =~ /DB::Pg$/
            && $self->dbh->{pg_server_version} <= 80102;
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus attribute should fail';
        like $@,
            qr/value for domain attribute violates check constraint "ck_attribute"/,
            '... And it should fail with the proper message';
    }

    # The errors abort the txn, so need a new object to test updates against.
    $attr_mock->unmock_all;
    ok $types_test = TypesTest->new(
        version    => $version,
        duration   => $du,
        operator   => 'eq',
        media_type => $mt,
        integer    => 20,
    ), 'Create another types test object';
    ok $types_test->save, 'Save it';

    # Make sure that invalid version are not allowed.
    ok $types_test->version(version->new('12.5')), 'Change the version';
    $checking = 'version';
    $ret      = 'v1.2a';
    $attr_mock->mock(store_raw => $store_mock);

    SKIP: {
        # XXX http://archives.postgresql.org/pgsql-patches/2006-01/msg00139.php
        skip 'Domain constraints ignored in PREPAREd statements', 2
            if $ENV{KS_CLASS} =~ /DB::Pg$/
            && $self->dbh->{pg_server_version} <= 80102;
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus version should fail';
        like $@,
            qr/value for domain "?version"? violates check constraint "ck_version"/,
            '... And it should fail with the proper message';
    }

    # The errors abort the txn, so need a new object to test updates against.
    $attr_mock->unmock_all;
    ok $types_test = TypesTest->new(
        version    => $version,
        duration   => $du,
        operator   => 'eq',
        media_type => $mt,
        integer    => 20,
    ), 'Create another types test object';
    ok $types_test->save, 'Save it';

    # Make sure that invalid gtin are not allowed.
    ok $types_test->gtin('036000291452'), 'Change the gtin to a UPC';
    $checking = 'gtin';
    $ret      = '036000291453';
    $attr_mock->mock(store_raw => $store_mock);

    SKIP: {
        # XXX http://archives.postgresql.org/pgsql-patches/2006-01/msg00139.php
        skip 'Domain constraints ignored in PREPAREd statements', 2
            if $ENV{KS_CLASS} =~ /DB::Pg$/
            && $self->dbh->{pg_server_version} <= 80102;
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus gtin should fail';
        like $@,
            qr/value for domain "?gtin"? violates check constraint "ck_gtin"/,
            '... And it should fail with the proper message';
    }

    # Make sure that invalid values are excluded on INSERTs, too.
    ok $types_test = TypesTest->new(
        version    => $version,
        duration   => $du,
        operator   => 'eq',
        media_type => $mt,
        integer    => 20,
    ), 'Create another types test object';

    $checking = 'integer';
    $ret      = 'foo';
    $attr_mock->mock(store_raw => $store_mock);

    SKIP: {
        skip 'Need to enable SQLite strict affinity', 2
            if $ENV{KS_CLASS} =~ /DB::SQLite$/;
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus integer should fail';
        like $@,
            qr/invalid input syntax for integer: "foo"/,
            '... And it should fail with the proper message';
    }

    SKIP: {
        # XXX http://archives.postgresql.org/pgsql-patches/2006-01/msg00139.php
        skip 'Domain constraints ignored in PREPAREd statements', 4
            if $ENV{KS_CLASS} =~ /DB::Pg$/
            && $self->dbh->{pg_server_version} <= 80102;

        $checking = 'whole';
        $ret      = -1;
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus whole should fail';
        like $@,
            qr/value for domain "?whole"? violates check constraint "ck_whole"/,
            '... And it should fail with the proper message';

        $checking = 'posint';
        $ret      = 0;
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus posint should fail';
        like $@,
            qr/value for domain "?posint"? violates check constraint "ck_posint"/,
            '... And it should fail with the proper message';

        $checking = 'operator';
        $ret      = 'foo';
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus operator should fail';
        like $@,
            qr/value for domain "?operator"? violates check constraint "ck_operator"/,
            '... And it should fail with the proper message';

        $checking = 'media_type';
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus media_type should fail';
        like $@,
            qr/value for domain media_type violates check constraint "ck_media_type"/,
            '... And it should fail with the proper message';

        $checking = 'attribute';
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus attribute should fail';
        like $@,
            qr/value for domain attribute violates check constraint "ck_attribute"/,
            '... And it should fail with the proper message';

        $checking = 'version';
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus version should fail';
        like $@,
            qr/value for domain version violates check constraint "ck_version"/,
            '... And it should fail with the proper message';

        $checking = 'gtin';
        $ret = 123456;
        throws_ok { $types_test->save } 'Exception::Class::DBI::STH',
            '... Saving it with a bogus gtin should fail';
        like $@,
            qr/value for domain gtin violates check constraint "ck_gtin"/,
            '... And it should fail with the proper message';
    }
}

1;
