package TEST::Kinetic::Store::DB;

# $Id: DB.pm 1099 2005-01-12 06:17:57Z theory $

use strict;
use warnings;

use Test::More;
use Test::Exception;
use base 'TEST::Kinetic::Store';
use lib 't/lib';
use aliased 'Test::MockModule';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Meta::Attribute';
use aliased 'Kinetic::Store' => 'DONT_USE', ':all';
use aliased 'Kinetic::Store::DB' => 'Store';
use aliased 'Kinetic::Util::State';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';

__PACKAGE__->runtests unless caller;

sub test_dbh : Test(2) {
    my $self = shift;
    my $class = $self->test_class;
    if ($class eq 'Kinetic::Store::DB') {
        throws_ok { $class->_connect_args }
          qr/Kinetic::Store::DB::_connect_args must be overridden in a subclass/,
          "_connect_args should throw an exception";
        throws_ok { $class->_dbh }
          qr/Kinetic::Store::DB::_connect_args must be overridden in a subclass/,
          "_dbh should throw an exception";
    } else {
        ok @{[$class->new->_connect_args]},
          "$class\::_connect_args should return values";
        # Only run the next test if we're testing a live data store.
        (my $store = $class) =~ s/.*:://;
        return "Not testing $store" unless $self->supported(lc $store);
        isa_ok $class->new->_dbh, 'DBI::db';
    }
}

sub where_token : Test(26) {
    my $store = Store->new;
    can_ok $store, '_make_where_token';
    $store->{search_class} = One->new->my_class;

    $store->{search_data}{fields} = [qw/name desc/]; # so it doesn't think it's an object search
    my ($token, $bind) = $store->_make_where_token('name', 'foo');
    is $token, 'LOWER(name) = LOWER(?)', 'and a basic match should return the correct where snippet';
    is_deeply $bind, ['foo'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', NOT 'foo');
    is $token, 'LOWER(name) != LOWER(?)',
        'and a negated basic match should return the correct where snippet';
    is_deeply $bind, ['foo'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', undef);
    is $token, 'LOWER(name) IS  NULL', 'and a NULL search should return the correct where snippet';
    is_deeply $bind, [], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', NOT undef);
    is $token, 'LOWER(name) IS NOT NULL',
        'and a negated NULL search should return the correct where snippet';
    is_deeply $bind, [], 'and a proper bind param';

    eval {($token, $bind) = $store->_make_where_token('name', {})};
    ok $@, "We should not make a where token if it doesn't know how to make one";

    ($token, $bind) = $store->_make_where_token('name', ['bar', 'foo']);
    is $token, 'LOWER(name)  BETWEEN LOWER(?) AND LOWER(?)',
        'and a range search should return the correct where snippet';
    is_deeply $bind, ['bar', 'foo'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', NOT ['bar', 'foo']);
    is $token, 'LOWER(name) NOT BETWEEN LOWER(?) AND LOWER(?)',
        'and a negated range search should return the correct where snippet';
    is_deeply $bind, ['bar', 'foo'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', LIKE '%foo');
    is $token, 'LOWER(name)  LIKE LOWER(?)',
        'and a LIKE search should return the correct where snippet';
    is_deeply $bind, ['%foo'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', NOT LIKE '%foo');
    is $token, 'LOWER(name) NOT LIKE LOWER(?)',
        'and a negated LIKE search should return the correct where snippet';
    is_deeply $bind, ['%foo'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', MATCH '(a|b)%');
    is $token, 'LOWER(name) ~* LOWER(?)',
        'and a MATCH search should return the correct where snippet';
    is_deeply $bind, ['(a|b)%'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', NOT MATCH '(a|b)%');
    is $token, 'LOWER(name) !~* LOWER(?)',
        'and a negated MATCH search should return the correct where snippet';
    is_deeply $bind, ['(a|b)%'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', ANY(qw/foo bar baz/));
    is $token, 'LOWER(name)  IN (LOWER(?), LOWER(?), LOWER(?))',
        'and an IN search should return the correct where snippet';
    is_deeply $bind, [qw/foo bar baz/], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', NOT ANY(qw/foo bar baz/));
    is $token, 'LOWER(name) NOT IN (LOWER(?), LOWER(?), LOWER(?))',
        'and a negated IN search should return the correct where snippet';
    is_deeply $bind, [qw/foo bar baz/], 'and a proper bind param';
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
    is_deeply \@keys, [qw/fields metadata/],
        'and it should return the types of data that we are looking for';
    is_deeply [sort @{$results->{fields}}],
        [qw/bool description guid id name state/],
        'which correctly identify the sql field names';
    is_deeply $results->{metadata},
        {
            'TestApp::Simple::One' => {
                fields => {
                    bool        => 'bool',
                    description => 'description',
                    guid        => 'guid',
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
    is_deeply \@keys, [qw/fields metadata/],
        'and it should return the types of data that we are looking for';
    is_deeply [sort @{$results->{fields}}],
    [qw/ age description guid id name one__bool one__description one__guid
         one__id one__name one__state state /],
        'which correctly identify the sql field names';
    my $metadata = {
        'TestApp::Simple::One' => {
            fields => {
                one__bool        => 'bool',
                one__description => 'description',
                one__guid        => 'guid',
                one__id          => 'id',
                one__name        => 'name',
                one__state       => 'state',
            }
        },
        'TestApp::Simple::Two' => {
            contains => {
                one__id => One->new->my_class
            },
            fields => {
                age         => 'age',
                description => 'description',
                guid        => 'guid',
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

}

sub build_objects : Test(16) {
    my $method = '_build_object_from_hashref';
    can_ok Store, $method;
    my %sql_data =(
        id               => 2,
        guid             => 'two asdfasdfasdfasdf',
        name             => 'two name',
        description      => 'two fake description',
        state            => 1,
        one__id          => 17,
        age              => 23,
        one__guid        => 'one ASDFASDFASDFASDF',
        one__name        => 'one name',
        one__description => 'one fake description',
        one__state       => 1,
        one__bool        => 0
    );
    my $store = Store->new;
    $store->{search_data} = {
      metadata => {
        'TestApp::Simple::One' => {
          fields => {
            one__bool        => 'bool',
            one__description => 'description',
            one__guid        => 'guid',
            one__id          => 'id',
            one__name        => 'name',
            one__state       => 'state',
          }
        },
        'TestApp::Simple::Two' => {
          contains => {
            one__id => One->new->my_class,
          },
          fields => {
            age         => 'age',
            description => 'description',
            guid        => 'guid',
            id          => 'id',
            name        => 'name',
            one__id     => 'one__id',
            state       => 'state',
          }
        }
      }
    };
    my $two_class = Two->new->my_class;
    $store->search_class($two_class);
    my $object = $store->$method(\%sql_data);
    isa_ok $object, $two_class->package, 'and the object it returns';
    foreach my $attr (qw/guid name description age/) {
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
    is $one->guid, 'one ASDFASDFASDFASDF', 'and basic attributes should be correct';
    is $one->name, 'one name', 'and basic attributes should be correct';
    is $one->description, 'one fake description', 'and basic attributes should be correct';
    is $one->bool, 0, 'and basic attributes should be correct';
    is $one->state+0, 1, 'and basic attributes should be correct';
    isa_ok $one->state, 'Kinetic::Util::State',
        'and Kinetic::Util::State objects should be handled correctly';
}

sub where_clause : Test(11) {
    my $store = Store->new;
    $store->{search_class} = One->new->my_class;
    my $my_class = MockModule->new('Kinetic::Meta::Class');
    my $current_field;
    $my_class->mock(attributes => sub {
        $current_field = $_[1];
        bless {} => Attribute
    });
    my $attr = MockModule->new(Attribute);
    my %fields = (
        name => 'string',
        desc => 'string',
        age  => 'int',
        this => 'weird_type',
        bog  => 'asdf',
    );
    $attr->mock(type => sub {
        my ($self) = @_;
        $current_field = 'bog' unless exists $fields{$current_field};
        return $fields{$current_field};
    });
    can_ok $store, '_make_where_clause';
    $store->{search_data}{fields} = [qw/name desc/]; # so it doesn't think it's an object search
    my ($where, $bind) = $store->_make_where_clause([
        name => 'foo',
        desc => 'bar',
    ]);
    is $where, '(LOWER(name) = LOWER(?) AND LOWER(desc) = LOWER(?))',
        'and simple compound where snippets should succeed';
    is_deeply $bind, [qw/foo bar/],
        'and return the correct bind params';

    $store->{search_data}{fields} = [qw/name desc this/]; # so it doesn't think it's an object search
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

    $store->{search_data}{fields} = [qw/
        last_name
        first_name 
        bio 
        one__type 
        one__value 
        fav_number
    /]; # so it doesn't think it's an object search
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

sub bad_where_tokens : Test(3) {
    my $store = Store->new;
    $store->{search_class} = One->new->my_class;

    throws_ok {$store->_make_where_token('name', NOT LIKE EQ 'foo')}
        qr/\QSearch operators can never be more than two deep: (NOT LIKE EQ foo)\E/,
        'Having three search operators in a row should be a fatal error';

    throws_ok {$store->_make_where_token('name', EQ NOT 'foo')}
        qr/\QNOT must always be first when used as a search operator: (EQ NOT foo)\E/,
        'and having NOT as the second operator should also be fatal';

    throws_ok {$store->_make_where_token('name', EQ LIKE 'foo')}
        qr/\QTwo search operators not allowed unless NOT is the first operator: (EQ LIKE foo)\E/,
        'and two search operators are fatal unless the first operator is NOT';
}

sub expand_search_param : Test(45) {
    can_ok Store, '_expand_search_param';

    my ($negated, $type, $value) = Store->_expand_search_param('bar');
    is $negated, '', 'negated is the empty string if the search is not negated';
    is $type, 'EQ', 'a simple expansion will return EQ for the type';
    is $value, 'bar', 'and will not touch the value';

    ($negated, $type, $value) = Store->_expand_search_param(undef);
    is $negated, '', 'negated is the empty string if the search is not negated';
    is $type, '', 'a NULL expansion will return the empty string for the type';
    is_deeply $value, undef, 'and an undef value';

    ($negated, $type, $value) = Store->_expand_search_param(NOT undef);
    is $negated, 'NOT', 'negated is "NOT" if the search is negated';
    is $type, '', 'a negated NULL expansion will return the empty string for the type';
    is_deeply $value, undef, 'and an undef value';

    ($negated, $type, $value) = Store->_expand_search_param([qw/foo bar/]);
    is $negated, '', 'negated is the empty string if the search is not negated';
    is $type, '', 'a range expansion will return the empty string for the type';
    is_deeply $value, [qw/foo bar/], 'and will not touch the value';

    ($negated, $type, $value) = Store->_expand_search_param(NOT [qw/foo bar/]);
    is $negated, 'NOT', 'negated is "NOT" if the search is negated';
    is $type, '',
        'a negated range expansion will return them empty string for the type';
    is_deeply $value, [qw/foo bar/], 'and will not touch the value';

    ($negated, $type, $value) = Store->_expand_search_param(ANY('bar'));
    is $negated, '', 'negated is the empty string if the search is not negated';
    is $type, 'ANY', 'an ANY expansion will return ANY for the type';
    is_deeply $value, ['bar'], 'and the values will be an array ref';

    ($negated, $type, $value) = Store->_expand_search_param(NOT ANY('bar', 'baz'));
    is $negated, 'NOT', 'negated is "NOT" if the search is negated';
    is $type, 'ANY', 'a NOT ANY expansion will return ANY for the type';
    is_deeply $value, ['bar', 'baz'], 'and the args as an array ref';

    throws_ok {Store->_expand_search_param(OR(name => 'bar'))}
        qr/\Q(OR) cannot be a value\E/,
        'and OR should never be parsed as a value';

    throws_ok {Store->_expand_search_param(AND(name => 'bar'))}
        qr/\Q(AND) cannot be a value\E/,
        'and AND should never be parsed as a value';

    ($negated, $type, $value) = Store->_expand_search_param(GT 'bar');
    is $negated, '', 'negated is the empty string if the search is not negated';
    is $type, 'GT', 'an GT expansion will return GT for the type';
    is_deeply $value, 'bar', 'and will not touch the value';

    ($negated, $type, $value) = Store->_expand_search_param(NOT GT 'bar');
    is $negated, 'NOT', 'negated is "NOT" if the search is negated';
    is $type, 'GT', 'an NOT GT expansion will return GT for the type';
    is_deeply $value, 'bar', 'and will not touch the value';

    ($negated, $type, $value) = Store->_expand_search_param(LIKE 'bar');
    is $negated, '', 'negated is the empty string if the search is not negated';
    is $type, 'LIKE', 'an LIKE expansion will return LIKE for the type';
    is_deeply $value, 'bar', 'and will not touch the value';

    ($negated, $type, $value) = Store->_expand_search_param(NOT LIKE 'bar');
    is $negated, 'NOT', 'negated is "NOT" if the search is negated';
    is $type, 'LIKE', 'an NOT LIKE expansion will return LIKE for the type';
    is_deeply $value, 'bar', 'and will not touch the value';

    ($negated, $type, $value) = Store->_expand_search_param(MATCH 'bar\S*');
    is $negated, '', 'negated is the empty string if the search is not negated';
    is $type, 'MATCH', 'an MATCH expansion will return MATCH for the type';
    is_deeply $value, 'bar\S*', 'and will not touch the value';

    ($negated, $type, $value) = Store->_expand_search_param(NOT MATCH 'bar\S+');
    is $negated, 'NOT', 'negated is "NOT" if the search is negated';
    is $type, 'MATCH', 'an NOT MATCH expansion will return MATCH for the type';
    is_deeply $value, 'bar\S+', 'and will not touch the value';

    ($negated, $type, $value) = Store->_expand_search_param(NOT 'bar');
    is $negated, 'NOT', 'negated is "NOT" if the search is negated';
    is $type, '', 'a expansion with a scalar arg will return them empty string for the type';
    is_deeply $value, 'bar', 'and the scalar arg';
}

# Use DBI's example driver for non-database testing.
my $dbh = DBI->connect(
    'dbi:ExampleP:dummy', '', '', {
        PrintError => 0,
        RaiseError => 1,
    }
);

sub save : Test(12) {
    my $test = shift;
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
}

sub save_contained : Test(1) {
    my $object2 = Two->new;
    my $one     = One->new;
    $object2->one($one);
    my $mock = MockModule->new(Store);
    my ($update, $insert);
    $mock->mock(_update => sub { $update = 1; $insert = 0 });
    $mock->mock(_insert => sub { $update = 0; $insert = 1 });
    $mock->mock(_dbh => $dbh );
    Store->save($object2);
    ok $insert, 'Saving a new object with a contained object should insert';
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
    my $expected    = q{INSERT INTO one (guid, name, description, state, bool) VALUES (?, ?, ?, ?, ?)};
    my $bind_params = [
        'Ovid',
        'test class',
        '1', # state: Active
        '1'  # bool
    ];
    ok ! exists $one->{id}, 'And a new object should not have an id';
    my @attributes = $one->my_class->attributes;
    my $store = Store->new;
    @{$store}{qw/search_class view names values/} = (
        One->new->my_class,
        'one',
        [map { Store->_get_name($_) } @attributes],
        [map { Store->_get_raw_value($one, $_) } @attributes],
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
    # XXX The guid should not change, should it?  I should
    # exclude it from this?
    my $expected = "UPDATE one SET guid = ?, name = ?, description = ?, "
                  ."state = ?, bool = ? WHERE id = ?";
    my $bind_params = [
        'Ovid',
        'test class',
        '1', # state: Active
        '1'  # bool
    ];
    my @attributes = $one->my_class->attributes;
    my $store = Store->new;
    @{$store}{qw/search_class view names values/} = (
        One->new->my_class,
        'one',
        [map { Store->_get_name($_) } @attributes],
        [map { Store->_get_raw_value($one, $_) } @attributes],
    );
    ok $store->_update($one),
        'and calling it should succeed';
    is $SQL, $expected,
        'and it should generate the correct sql';
    my $uuid = shift @$BIND;
    my $id   = pop @$BIND;
    is $one->guid, $uuid, 'and the guid should be correct';
    is $one->{id}, $id, 'and the final bind param is the id';
    is_deeply $BIND, $bind_params,
        'and the correct bind params';
    is $one->{id}, 42, 'and the private id should not be changed';
}

sub get_name : Test(3) {
    can_ok Store, '_get_name';
    my $object = Two->new;
    my $attribute = $object->my_class->attributes('name');
    is Store->_get_name($attribute), 'name',
        'normal names should be returned intact';
    my $one = One->new;
    $object->one($one);
    $attribute = $object->my_class->attributes('one');
    is Store->_get_name($attribute), 'one__id',
        'but references should have "__id" appended to them';
}

sub _get_raw_value {
    my ($class, $object, $attr) = @_;
    return $attr->raw($object) unless $attr->references;
    my $name = $attr->name;
    my $contained_object = $object->$name;
    return $contained_object->{id};  # this needs to be fixed
}

# XXX This is temporary until the behavior of Attribute->raw() is finalized.
sub get_value : Test(3) {
    can_ok Store, '_get_raw_value';

    # suppress irrelevant "variable will not stay shared" warnings;
    no warnings;
    my $value      = 'rots';
    my $references = 0;
    my $object     = Two->new;
    my $one        = One->new;
    $one->{id}     = 23;
    $object->name('Ovid');
    $object->one($one);
    my $attribute  = $object->my_class->attributes('name');

    is Store->_get_raw_value($object, $attribute), 'Ovid',
        'and normal values should simply be returned';

    $attribute = $object->my_class->attributes('one');
    is Store->_get_raw_value($object, $attribute), 23,
        'and if it references another object, it should return the object id';
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
