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
use aliased 'Kinetic::Store' => 'DONT_USE', ':all';
use aliased 'Kinetic::Store::DB' => 'Store';
use aliased 'Kinetic::Util::State';

use lib 't/sample/lib'; # temporary
use aliased 'TestApp::Simple::One';
use aliased 'Hash::AsObject';

__PACKAGE__->runtests;

sub where_clause : Test(no_plan) {
    my $store = Store->new;
    can_ok $store, '_make_where_clause';
    my ($where, $bind) = $store->_make_where_clause([
        name => 'foo',
        desc => 'bar',
    ]);
    is $where, '(name = ? AND desc = ?)',
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
    is $where, '(name = ? AND (desc = ? AND this = ?))',
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
    is $where, '(name = ? OR (desc = ? AND this = ?))',
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

sub where_token : Test(26) {
    can_ok Store, '_make_where_token';
    
    my ($token, $bind) = Store->_make_where_token('name', 'foo');
    is $token, 'name = ?', 'and a basic match should return the correct where snippet';
    is_deeply $bind, ['foo'], 'and a proper bind param';

    ($token, $bind) = Store->_make_where_token('name', NOT 'foo');
    is $token, 'name != ?', 
        'and a negated basic match should return the correct where snippet';
    is_deeply $bind, ['foo'], 'and a proper bind param';

    eval { Store->_make_where_token('name', {}) };
    ok $@, "We should not make a where token if it doesn't know how to make one";

    ($token, $bind) = Store->_make_where_token('name', ['bar', 'foo']);
    is $token, 'name  BETWEEN ? AND ?',
        'and a range search should return the correct where snippet';
    is_deeply $bind, ['bar', 'foo'], 'and a proper bind param';

    ($token, $bind) = Store->_make_where_token('name', NOT ['bar', 'foo']);
    is $token, 'name NOT BETWEEN ? AND ?',
        'and a negated range search should return the correct where snippet';
    is_deeply $bind, ['bar', 'foo'], 'and a proper bind param';
    
    ($token, $bind) = Store->_make_where_token('name', undef);
    is $token, 'name IS  NULL', 'and a NULL search  should return the correct where snippet';
    is_deeply $bind, [], 'and a proper bind param';

    ($token, $bind) = Store->_make_where_token('name', NOT undef);
    is $token, 'name IS NOT NULL', 
        'and a negated NULL search should return the correct where snippet';
    is_deeply $bind, [], 'and a proper bind param';

    ($token, $bind) = Store->_make_where_token('name', ANY(qw/foo bar baz/));
    is $token, 'name  IN (?, ?, ?)', 
        'and an IN search should return the correct where snippet';
    is_deeply $bind, [qw/foo bar baz/], 'and a proper bind param';

    ($token, $bind) = Store->_make_where_token('name', NOT ANY(qw/foo bar baz/));
    is $token, 'name NOT IN (?, ?, ?)', 
        'and a negated IN search should return the correct where snippet';
    is_deeply $bind, [qw/foo bar baz/], 'and a proper bind param';
    
    ($token, $bind) = Store->_make_where_token('name', LIKE '%foo');
    is $token, 'name LIKE ?', 'and a LIKE search should return the correct where snippet';
    is_deeply $bind, ['%foo'], 'and a proper bind param';

    ($token, $bind) = Store->_make_where_token('name', NOT LIKE '%foo');
    is $token, 'name NOT LIKE ?', 'and a negated LIKE search should return the correct where snippet';
    is_deeply $bind, ['%foo'], 'and a proper bind param';

    ($token, $bind) = Store->_make_where_token('name', MATCH '(a|b)%');
    is $token, 'name ~* ?', 'and a MATCH search should return the correct where snippet';
    is_deeply $bind, ['(a|b)%'], 'and a proper bind param';

    ($token, $bind) = Store->_make_where_token('name', NOT MATCH '(a|b)%');
    is $token, 'name !~* ?', 'and a negated MATCH search should return the correct where snippet';
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
    my %data = (
        view   => 'one',
        names  => [map { Store->_get_name($_) } @attributes],
        values => [map { Store->_get_raw_value($one, $_) } @attributes],
    );
    ok Store->_insert($one, \%data),
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
    my %data = (
        view   => 'one',
        names  => [map { Store->_get_name($_) } @attributes],
        values => [map { Store->_get_raw_value($one, $_) } @attributes],
    );
    ok Store->_update($one, \%data),
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

sub build_object_from_hashref : Test(2) {
    my $store = Store->new;
    can_ok $store, '_build_object_from_hashref';
    my $ref = {
        guid        => '4162F712-1DD2-11B2-B17E-C09EFE1DC403',
        name        => 'whozit',
        description => 'some desc',
        state       => 1, # Active
        bool        => 0,
    };
    $store->{search_class} = One->new->my_class;
    my $object = $store->_build_object_from_hashref($ref);
    isa_ok $object, One, 'and it should be able to build an object of the correct type';
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

sub get_kinetic_value : Test(5) {
    can_ok Store, '_get_kinetic_value';
    is Store->_get_kinetic_value('name', 3), 3,
        'ordinary values should simply be returned';
    ok my $state = Store->_get_kinetic_value('state', 1),
        'and getting a "state" value should succeed';
    isa_ok $state, State, 'and the value returned';
    is int $state, 1, 'and its integer value should be the value passed in';
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

sub search : Test(1) {
    can_ok Store, 'search';

}

1;
