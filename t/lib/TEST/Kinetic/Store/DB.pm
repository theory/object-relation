package TEST::Kinetic::Store::DB;

# $Id: DB.pm 1099 2005-01-12 06:17:57Z theory $

use strict;
use warnings;

use Test::More;
use Test::Exception;
use base 'TEST::Kinetic::Store';
#use base 'TEST::Class::Kinetic';
use lib 't/lib';
use Kinetic::Build::Schema;
use aliased 'Test::MockModule';
use aliased 'Kinetic::Meta';
use aliased 'Kinetic::Meta::Attribute';
use aliased 'Kinetic::Store' => 'DONT_USE', ':all';
use aliased 'Kinetic::Store::DB' => 'Store';
use aliased 'Kinetic::Util::State';

use lib 't/sample/lib'; # temporary
use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';
use aliased 'Hash::AsObject';

__PACKAGE__->runtests;

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
    my $my_class = MockModule->new('Kinetic::Meta::Class::Schema');
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
    my ($where, $bind) = $store->_make_where_clause([
        name => 'foo',
        desc => 'bar',
    ]);
    is $where, '(lower(name) = lower(?) AND lower(desc) = lower(?))',
        'and simple compound where snippets should succeed';
    is_deeply $bind, [qw/foo bar/],
        'and return the correct bind params';

    ($where, $bind) = $store->_make_where_clause([
        name => 'foo',
        [
            desc => 'bar',
            this => 'that',
        ],
    ]);
    is $where, '(lower(name) = lower(?) AND (lower(desc) = lower(?) AND this = ?))',
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
    is $where, '(lower(name) = lower(?) OR (lower(desc) = lower(?) AND this = ?))',
        'and compound where snippets with array refs should succeed';
    is_deeply $bind, [qw/foo bar that/],
        'and return the correct bind params';

    ($where, $bind) = $store->_make_where_clause([
        [
            last_name  => 'Wall',
            first_name => 'Larry',
        ],
        OR( bio => LIKE '%perl%'),
        OR(
          'contact.type'  => LIKE 'email',
          'contact.value' => LIKE '@cpan\.org$',
          'fav_number'    => GE 42
        )
    ]);
    is $where, '((last_name = ? AND first_name = ?) OR (bio LIKE ?) OR '
              .'(contact.type LIKE ? AND contact.value LIKE ? AND fav_number >= ?))',
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
          'contact.type'  => LIKE 'email',
          'contact.value' => LIKE '@cpan\.org$',
          'fav_number'    => GE 42
        )
    ]);
    is $where, '((last_name = ? AND first_name = ?) OR (bio LIKE ?) OR '
              .'(contact.type LIKE ? AND contact.value LIKE ? AND fav_number >= ?))',
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

sub where_token : Test(26) {
    my $store = Store->new;
    can_ok $store, '_make_where_token';
    $store->{search_class} = One->new->my_class;
    
    my ($token, $bind) = $store->_make_where_token('name', 'foo');
    is $token, 'lower(name) = lower(?)', 'and a basic match should return the correct where snippet';
    is_deeply $bind, ['foo'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', NOT 'foo');
    is $token, 'lower(name) != lower(?)', 
        'and a negated basic match should return the correct where snippet';
    is_deeply $bind, ['foo'], 'and a proper bind param';

    eval { $store->_make_where_token('name', {}) };
    ok $@, "We should not make a where token if it doesn't know how to make one";

    ($token, $bind) = $store->_make_where_token('name', ['bar', 'foo']);
    is $token, 'lower(name)  BETWEEN lower(?) AND lower(?)',
        'and a range search should return the correct where snippet';
    is_deeply $bind, ['bar', 'foo'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', NOT ['bar', 'foo']);
    is $token, 'lower(name) NOT BETWEEN lower(?) AND lower(?)',
        'and a negated range search should return the correct where snippet';
    is_deeply $bind, ['bar', 'foo'], 'and a proper bind param';
    
    ($token, $bind) = $store->_make_where_token('name', undef);
    is $token, 'lower(name) IS  NULL', 'and a NULL search  should return the correct where snippet';
    is_deeply $bind, [], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', NOT undef);
    is $token, 'lower(name) IS NOT NULL', 
        'and a negated NULL search should return the correct where snippet';
    is_deeply $bind, [], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', ANY(qw/foo bar baz/));
    is $token, 'lower(name)  IN (lower(?), lower(?), lower(?))', 
        'and an IN search should return the correct where snippet';
    is_deeply $bind, [qw/foo bar baz/], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', NOT ANY(qw/foo bar baz/));
    is $token, 'lower(name) NOT IN (lower(?), lower(?), lower(?))', 
        'and a negated IN search should return the correct where snippet';
    is_deeply $bind, [qw/foo bar baz/], 'and a proper bind param';
    
    ($token, $bind) = $store->_make_where_token('name', LIKE '%foo');
    is $token, 'lower(name) LIKE lower(?)',
        'and a LIKE search should return the correct where snippet';
    is_deeply $bind, ['%foo'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', NOT LIKE '%foo');
    is $token, 'lower(name) NOT LIKE lower(?)', 
        'and a negated LIKE search should return the correct where snippet';
    is_deeply $bind, ['%foo'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', MATCH '(a|b)%');
    is $token, 'lower(name) ~* lower(?)', 
        'and a MATCH search should return the correct where snippet';
    is_deeply $bind, ['(a|b)%'], 'and a proper bind param';

    ($token, $bind) = $store->_make_where_token('name', NOT MATCH '(a|b)%');
    is $token, 'lower(name) !~* lower(?)', 
        'and a negated MATCH search should return the correct where snippet';
    is_deeply $bind, ['(a|b)%'], 'and a proper bind param';
}

sub expand_attribute : Test(31) {
    can_ok Store, '_expand_attribute';

    my ($type, $value) = Store->_expand_attribute('bar');
    is $type, 'EQ', 'a simple expansion will return EQ for the type';
    is $value, 'bar', 'and will not touch the value';

    ($type, $value) = Store->_expand_attribute(undef);
    is $type, '', 'a NULL expansion will return the empty string for the type';
    is_deeply $value, undef, 'and an undef value';

    ($type, $value) = Store->_expand_attribute(NOT undef);
    is $type, 'NOT', 'a negated NULL expansion will return "NOT" for the type';
    is_deeply $value, undef, 'and an undef value';

    ($type, $value) = Store->_expand_attribute([qw/foo bar/]);
    is $type, '', 'a range expansion will return the empty string for the type';
    is_deeply $value, [qw/foo bar/], 'and will not touch the value';

    ($type, $value) = Store->_expand_attribute(NOT [qw/foo bar/]);
    is $type, 'NOT', 
        'a negated range expansion will return "NOT" for the type';
    is_deeply $value, [qw/foo bar/], 'and will not touch the value';

    ($type, $value) = Store->_expand_attribute(ANY('bar'));
    is $type, 'ANY', 'an ANY expansion will return ANY for the type';
    is_deeply $value, ['bar'], 'and the values will be an array ref';

    ($type, $value) = Store->_expand_attribute(NOT ANY('bar', 'baz'));
    is $type, 'NOT ANY', 'a NOT ANY expansion will return NOT ANY for the type';
    is_deeply $value, ['bar', 'baz'], 'and the args as an array ref';

    throws_ok {Store->_expand_attribute(OR(name => 'bar'))}
        qr/\Q(OR) cannot be a value\E/,
        'and OR should never be parsed as a value';

    throws_ok {Store->_expand_attribute(AND(name => 'bar'))}
        qr/\Q(AND) cannot be a value\E/,
        'and AND should never be parsed as a value';

    ($type, $value) = Store->_expand_attribute(GT 'bar');
    is $type, 'GT', 'an GT expansion will return NOT GT for the type';
    is_deeply $value, 'bar', 'and will not touch the value';

    ($type, $value) = Store->_expand_attribute(NOT GT 'bar');
    is $type, 'NOT GT', 'an NOT GT expansion will return NOT GT for the type';
    is_deeply $value, 'bar', 'and will not touch the value';

    ($type, $value) = Store->_expand_attribute(LIKE 'bar');
    is $type, 'LIKE', 'an LIKE expansion will return LIKE for the type';
    is_deeply $value, 'bar', 'and will not touch the value';

    ($type, $value) = Store->_expand_attribute(NOT LIKE 'bar');
    is $type, 'NOT LIKE', 'an NOT LIKE expansion will return LIKE for the type';
    is_deeply $value, 'bar', 'and will not touch the value';

    ($type, $value) = Store->_expand_attribute(MATCH 'bar\S*');
    is $type, 'MATCH', 'an MATCH expansion will return MATCH for the type';
    is_deeply $value, 'bar\S*', 'and will not touch the value';

    ($type, $value) = Store->_expand_attribute(NOT MATCH 'bar\S+');
    is $type, 'NOT MATCH', 'an NOT MATCH expansion will return MATCH for the type';
    is_deeply $value, 'bar\S+', 'and will not touch the value';

    ($type, $value) = Store->_expand_attribute(NOT 'bar');
    is $type, 'NOT', 'a NOT expansion with a scalar arg will return NOT for the type';
    is_deeply $value, 'bar', 'and the scalar arg';
}

{
    package Dummy::Class;
    use aliased 'Hash::AsObject';
    my @attributes = map AsObject->new({references => $_}) => qw/0 0 0/;
    sub attributes {
        my $self = shift;
        if (@_) {
            $self->{attributes} = shift;
        }
        return @{$self->{attributes}};
    }; 
    my $contained_called = 0;
    sub key              { 'one' }
    sub contained_called {$contained_called}
    sub contained_object {
        my $self = shift;
        my $class = ref $self;
        $contained_called++;
        return $class->new;
    }
    sub my_class {shift}
    sub new { bless {attributes => \@attributes} => shift }
}

sub save : Test(3) {
    my $test = shift;
    my $mock = MockModule->new(Store);
    my ($update, $insert);
    $mock->mock(_update => sub { $update = 1; $insert = 0 });
    $mock->mock(_insert => sub { $update = 0; $insert = 1 });
    my $object = Dummy::Class->new; 
    can_ok Store, 'save';
    Store->save($object);
    ok $insert, 'and calling it with an object with no id key should call _insert()';
    $object->{id} = 1;
    Store->save($object);
    ok $update, 'and calling it with an object with an id key should call _update()';
    #ok ! $object->contained_called, 
    #    '... and no contained objects were saved';
}

sub save_contained : Test(2) {
    my $object2 = Dummy::Class->new;
    my @attributes = map AsObject->new($_) => (
        {references => 0},
        {
            references => 1,
            name       => 'contained_object'
        },
    );
    my $mock = MockModule->new(Store);
    my ($update, $insert);
    $mock->mock(_update => sub { $update = 1; $insert = 0 });
    $mock->mock(_insert => sub { $update = 0; $insert = 1 });
    $object2->attributes(\@attributes);
    Store->save($object2);
    ok $insert, 'Saving a new object with a contained object should insert';
    ok $object2->contained_called,
        'and a contained object should be saved';
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
    my $attribute = AsObject->new({references => 0, name => 'dead_pig'});
    is Store->_get_name($attribute), 'dead_pig',
        'normal names should be returned intact';
    $attribute->{references} = 1;
    is Store->_get_name($attribute), 'dead_pig__id',
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
    {
        package Faux::Attribute;
        sub raw        { $value       }
        sub references { $references  }
        sub dead_pig   { {id => 23}   }
        sub name       { 'dead_pig'   }
    }
    my $attribute = bless {} => 'Faux::Attribute';
    my $object    = {};
    is Store->_get_raw_value($object, $attribute), 'rots',
        'and normal values should simply be returned';

    $references = 1;
    $object     = bless {} => 'Faux::Attribute';
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
