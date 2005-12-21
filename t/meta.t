#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 214;
#use Test::More 'no_plan';
use lib '/Users/david/dev/Kineticode/trunk/Class-Meta/lib';

package MyTestThingy;

BEGIN {
    Test::More->import;
    use_ok('Kinetic::Meta')                  or die;
    use_ok('Kinetic::Util::Language')        or die;
    use_ok('Kinetic::Util::Language::en_us') or die;
    use_ok('Kinetic::Meta::Class')           or die;
    use_ok('Kinetic::Meta::Attribute')       or die;
    use_ok('Kinetic::Meta::AccessorBuilder') or die;
    use_ok('Kinetic::Meta::Widget')          or die;
}

BEGIN {
    # Make sure the Store methods don't load until we load a db Store.
    ok !defined(&Kinetic::Meta::Attribute::_column),
        'Attribute::_column() should not exist';
    ok !defined(&Kinetic::Meta::Attribute::_view_column),
        'Attribute::_view_column() should not exist';

    # Implicitly loads database store.
    use_ok('Kinetic');

    ok defined(&Kinetic::Meta::Attribute::_column),
        'Now Attribute::_column() should exist';
    ok defined(&Kinetic::Meta::Attribute::_view_column),
        'Now Attribute::_view_column() should exist';
}

use base 'Kinetic';

BEGIN {
    is( Kinetic::Meta->class_class, 'Kinetic::Meta::Class',
        "The class class should be 'Kinetic::Meta::Class'");
    is( Kinetic::Meta->attribute_class, 'Kinetic::Meta::Attribute',
        "The attribute class should be 'Kinetic::Meta::Attribute'");

    ok my $km = Kinetic::Meta->new(
        key         => 'thingy',
        name        => 'Thingy',
        plural_name => 'Thingies',
    ), "Create TestThingy class";

    ok $km->add_attribute(
        name          => 'foo',
        type          => 'string',
        label         => 'Foo',
        indexed       => 1,
        on_delete     => 'CASCADE',
        store_default => 'ick',
        widget_meta   => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => 'Kinetic',
        )
    ), "Add attribute";

    ok $km->add_method(
        name => 'hello',
    ), 'Add method';

    sub hello { return 'hello' }

    ok $km->build, "Build TestThingy class";
}

package MyTestFooey;

BEGIN { Test::More->import; }

BEGIN {
    ok my $km = Kinetic::Meta->new(
        key         => 'fooey',
        name        => 'Fooey',
        plural_name => 'Fooies',
        sort_by     => ['lname', 'fname'],
    ), "Create TestFooey class";

    ok $km->add_attribute(
        name          => 'thingy',
        type          => 'thingy',
        label         => 'Thingy',
        indexed       => 1,
    ), "Add thingy attribute";

    ok $km->add_attribute(
        name          => 'fname',
        type          => 'string',
        label         => 'First Name',
    ), "Add fname attribute";

    ok $km->add_attribute(
        name          => 'lname',
        type          => 'string',
        label         => 'Last Name',
        persistent    => 0,
    ), "Add lname attribute";

    ok $km->build, "Build TestFooey class";
}

package MyTestExtends;
use base 'Kinetic';
BEGIN { Test::More->import; }

BEGIN {
    ok my $km = Kinetic::Meta->new(
        key         => 'extend',
        name        => 'Extend',
        plural_name => 'Extends',
        extends     => 'thingy',
    ), "Create TestExtends class";

    ok $km->add_constructor(
        name   => 'new',
        create => 1,
    ), 'Add constructor';

    ok $km->add_attribute(
        name          => 'rank',
        type          => 'string',
        label         => 'Rank',
    ), "Add rank attribute";

    ok $km->build, "Build TestExtends class";
}

package MyTestMediates;
use base 'Kinetic';
BEGIN { Test::More->import; }

BEGIN {
    ok my $km = Kinetic::Meta->new(
        key         => 'mediate',
        name        => 'Mediate',
        plural_name => 'Mediates',
        mediates     => 'thingy',
    ), "Create TestMediates class";

    ok $km->add_constructor(
        name   => 'new',
        create => 1,
    ), 'Add constructor';

    ok $km->add_attribute(
        name          => 'booyah',
        type          => 'string',
        label         => 'Booyah',
    ), "Add booyah attribute";

    ok $km->build, "Build TestMediates class";
}

package MyTest::Meta::ExtMed;
use base 'Kinetic';
BEGIN { Test::More->import; }
BEGIN {
    eval {
        Kinetic::Meta->new(
            key      => 'ow',
            extends  => 'thingy',
            mediates => 'extend',
        );
    };
    ok my $err = $@, 'Catch extends and mediates exception';
    is $err->error,
        'MyTest::Meta::ExtMed can either extend or mediate another class, '
        . 'but not both',
        'It should have the correct message';
}

package MyTest::Meta::Excptions;

BEGIN {
    Test::More->import;
}

BEGIN {
    ok my $km = Kinetic::Meta->new(

        key         => 'owie',
        name        => 'Owie',
        plural_name => 'Owies',
        sort_by     => 'not_here',
    ), "Create Owie class";
    eval { $km->build };
    ok my $err = $@, 'Catch exception';
    isa_ok $err, 'Kinetic::Util::Exception';
    isa_ok $err, 'Kinetic::Util::Exception::Fatal';
    is $err->message, "No direct attribute \x{201c}not_here\x{201d} to sort by",
        'Check the error message';

}
# Add new strings to the lexicon.
Kinetic::Util::Language::en_us->add_to_lexicon(
  'Thingy'   => 'Thingy',
  'Thingies' => 'Thingies',
  'Foo'      => 'Foo',
  'Fooey'    => 'Fooey',
  'Fooies'    => 'Fooies',
);

ok( Kinetic::Util::Context->language(Kinetic::Util::Language->get_handle('en_us')),
    "Set language context" );

package main;

ok my $class = MyTestThingy->my_class, "Get meta class object";
isa_ok $class, 'Kinetic::Meta::Class';
isa_ok $class, 'Class::Meta::Class';
ok $class = Kinetic::Meta->for_key('thingy'),
    'Get meta class object via for_key()';
isa_ok $class, 'Kinetic::Meta::Class';
isa_ok $class, 'Class::Meta::Class';

eval { Kinetic::Meta->for_key('_no_such_thing') };

ok my $err = $@, 'Caught for_key() exception';
isa_ok $err, 'Kinetic::Util::Exception';
isa_ok $err, 'Kinetic::Util::Exception::Fatal';
isa_ok $err, 'Kinetic::Util::Exception::Fatal::InvalidClass';
is $err->error,
    "I could not find the class for key \x{201c}_no_such_thing\x{201d}",
    'We should have received the proper error message';

is $class->key, 'thingy', 'Check key';
is $class->package, 'MyTestThingy', 'Check package';
is $class->name, 'Thingy', 'Check name';
is $class->plural_name, 'Thingies', 'Check plural name';
is $class->sort_by, $class->attributes('foo'),
    'Check default sort_by attribute';

can_ok $class, 'ref_attributes';
can_ok $class, 'direct_attributes';
can_ok $class, 'persistent_attributes';

is_deeply [$class->ref_attributes], [],
    'There should be no referenced attributes';
is_deeply [$class->direct_attributes], [$class->attributes('id'), $class->attributes],
    'With no ref_attributes, direct_attributes should return all attributes';

is_deeply [$class->persistent_attributes], [$class->attributes('id'), $class->attributes],
    'By default, persistent_attributes should return all attributes';

ok my $attr = $class->attributes('foo'), "Get foo attribute";
isa_ok $attr, 'Kinetic::Meta::Attribute';
isa_ok $attr, 'Class::Meta::Attribute';
is $attr->name, 'foo', "Check attr name";
is $attr->type, 'string', "Check attr type";
is $attr->label, 'Foo', "Check attr label";
is $attr->indexed, 1, "Indexed should be true";

ok my $wm = $attr->widget_meta, "Get widget meta object";
isa_ok $wm, 'Kinetic::Meta::Widget';
isa_ok $wm, 'Widget::Meta';
is $wm->tip, 'Kinetic', "Check tip";

ok my $fclass = MyTestFooey->my_class, "Get Fooey class object";
is $fclass->sort_by, $fclass->attributes('lname'), 'Check specified sort_by';
is_deeply [$fclass->sort_by], [ $fclass->attributes('lname', 'fname') ],
    'Check sort_by in an array context';
ok $attr = $fclass->attributes('thingy'), "Get thingy attribute";
isa_ok $attr, 'Kinetic::Meta::Attribute';
isa_ok $attr, 'Class::Meta::Attribute';
is $attr->widget_meta->type, 'text',
    'It should default to a "text" widget type';

is_deeply [$fclass->ref_attributes], [$attr],
    'We should be able to get the one referenced attribute';
is_deeply [$fclass->direct_attributes],
          [ grep { $_->name ne 'thingy' } $fclass->attributes ],
    'Direct attributes should have all but the referenced attribute';
is_deeply [$fclass->persistent_attributes],
          [ grep { $_->name ne 'lname' } $fclass->attributes ],
    'Persistent attributes should have all but the non-persistent attribute';

is_deeply [$class->persistent_attributes], [$class->attributes('id'), $class->attributes],
    'By default, persistent_attributes should return all attributes';

is $attr->references, MyTestThingy->my_class,
  "The thingy object should reference the thingy class";
is $attr->relationship, 'has',
  'The Fooey should have a "has" relationship to the thingy';
$attr = $fclass->attributes('fname');
is_deeply [$fclass->direct_attributes], [$attr, $fclass->attributes('lname')],
  "And direct_attributes should return the non-referenced attributes";
is $attr->relationship, undef, "The fname attribute should have no relationship";

##############################################################################
# Text extends class.
ok $class = MyTestExtends->my_class, 'Get TestExtends class object';
is $class->extends, MyTestThingy->my_class, 'It should extend Thingy';
is_deeply [map { $_->name } $class->attributes ],
          [qw(uuid state thingy_uuid thingy_state foo rank)],
    'It should include the attributes from thingy';

# Test its accessors.
ok my $ex = MyTestExtends->new, 'Create new Extends object';
isa_ok $ex => 'MyTestExtends';
isa_ok $ex => 'Kinetic';
ok !$ex->isa('MyTestThingy'), 'The object isn\'ta MyTestThingy';

# Make sure that delegates_to is set properly.
ok my $thingy_class = Kinetic::Meta->for_key('thingy'),
    'Get the thingy class object';
ok $attr = $class->attributes('uuid'), 'Get the uuid attribute object';
is $attr->delegates_to, undef, 'uuid should not delegate';
is $attr->acts_as, undef, 'uuid should not act as another attribute';
ok $attr = $class->attributes('foo'), 'Get the foo attribute object';
is $attr->delegates_to, $thingy_class, 'foo should delegate to thingy';
is $attr->acts_as, $thingy_class->attributes('foo'),
    'foo should act as the thingy foo';

ok $ex->foo('fooey'), 'Should be able to set delegated attribute';
is $ex->foo, $ex->thingy->foo, 'The value should have been passed through';

is $ex->uuid, undef, 'The UUID should be undefined';
is $ex->thingy_uuid, undef, 'And the thingy UUID should be undef';
ok $ex->_save_prep, 'Prepare it for storage';
ok $ex->uuid, 'The UUID should now be defined';
ok $ex->thingy_uuid, 'And so should the thingy UUID';
ok $ex->uuid ne $ex->thingy_uuid, 'And they should have different UUIDs';

# We should get the trusted extended object attribute.
is_deeply [map { $_->name } $class->persistent_attributes],
          [qw(id uuid state thingy thingy_uuid thingy_state foo rank)],
    'We should get public and trusted attributes';

# Make sure that methods are delegated.
ok my $meth = $class->methods('hello'), 'Get extend hello method object';
ok my $meth2 = $thingy_class->methods('hello'),
    'Get thingy hello method object';
is $meth->acts_as, $meth2, 'Extend hello should act as thingy hello';
is $meth->delegates_to, $thingy_class,
    'Extend hello should delegate to thingy';

ok $meth = $class->methods('save'), 'Get extend save method object';
ok $meth2 = $thingy_class->methods('save'),
    'Get thingy save method object';
ok !$meth->acts_as, 'Extend save should not act as anything';
ok !$meth->delegates_to, 'Extend save should not delegate to anything';
ok $meth = $class->methods('thingy_save'), 'Get extend thingy_save object';
is $meth->acts_as, $meth2, 'Extend thingy_sve should act as thingy save';
is $meth->delegates_to, $thingy_class,
    'Extend thingy_save should delegate to thingy';

can_ok $ex, 'hello';
can_ok $ex, 'save';
can_ok $ex, 'thingy_save';
is $ex->hello, 'hello', 'The hello() method should dispatch to thingy';

# Make sure that nothing has been modified.
ok $ex = MyTestExtends->new, 'Create another Extend object';
is_deeply [$ex->_get_modified], [], 'No attributes should have been modified';
ok !$ex->_is_modified('uuid'), 'UUID should not be modified';
ok !$ex->_is_modified('foo'), 'And neither should foo';
ok !$ex->_is_modified('rank'), 'Nor rank';
is_deeply [$ex->_get_modified], [], 'Thingy has no mods, either';

ok $ex->rank(undef), 'Set the rank to undef (unchanged)';
ok !$ex->_is_modified('rank'), 'Rank should still be unchanged';
is_deeply [$ex->_get_modified], [], 'There should still be no list of modified';

ok $ex->rank('amateur'), 'Set the rank to something different';
ok $ex->_is_modified('rank'), 'It should know that rank has been modified';
is_deeply [$ex->_get_modified], ['rank'],
    'And rank should be the only item in the list of modified';

ok $ex->foo('Yow'), 'Set the foo attribute';
ok $ex->_is_modified('foo'), 'It should know that foo has been modified';
is_deeply [$ex->_get_modified], [qw(rank foo)],
    'It should list both rank and foo as modified';
ok $ex->thingy->_is_modified('foo'), 'Thingy should know foo is modified';
is_deeply [$ex->thingy->_get_modified], ['foo'],
    'Thingy should list foo as modified';

ok $ex->_clear_modified, 'Clear modified';
ok ! @{$ex->_get_modified}, 'Now no attributes should be listed as modified';
ok !$ex->_is_modified('foo'), 'It should think that foo is unmodified';
ok !$ex->_is_modified('rank'), 'Same for rank';

ok $ex->thingy->_is_modified('foo'),
    'But thingy should still think foo is modified';
is_deeply [$ex->thingy->_get_modified], ['foo'],
    'Thingy should still list foo as modified';
ok $ex->thingy->_clear_modified, 'Clear thingy modified';

ok !$ex->thingy->_is_modified('foo'),
    'Now thingy should not think foo is modified';
is_deeply [$ex->thingy->_get_modified], [],
    'Thingy should list none as modified';

##############################################################################
# Text mediates class.
ok $class = MyTestMediates->my_class, 'Get TestMediates class object';
is $class->mediates, MyTestThingy->my_class, 'It should mediate Thingy';
is_deeply [map { $_->name } $class->attributes ],
          [qw(uuid state thingy_uuid thingy_state foo booyah)],
    'It should include the attributes from thingy';

# Test its accessors.
ok my $med = MyTestMediates->new, 'Create new Mediates object';
isa_ok $med => 'MyTestMediates';
isa_ok $med => 'Kinetic';
ok !$med->isa('MyTestThingy'), 'The object isn\'ta MyTestThingy';

# Make sure that delegates_to is set properly.
ok $attr = $class->attributes('uuid'), 'Get the uuid attribute object';
is $attr->delegates_to, undef, 'uuid should not delegate';
is $attr->acts_as, undef, 'uuid should not act as another attribute';
ok $attr = $class->attributes('foo'), 'Get the foo attribute object';
is $attr->delegates_to, $thingy_class, 'foo should delegate to thingy';
is $attr->acts_as, $thingy_class->attributes('foo'),
    'foo should act as the thingy foo';

ok $med->foo('fooey'), 'Should be able to set delegated attribute';
is $med->foo, $med->thingy->foo, 'The value should have been passed through';

is $med->uuid, undef, 'The UUID should be undefined';
is $med->thingy_uuid, undef, 'And the thingy UUID should be undef';
ok $med->_save_prep, 'Prepare it for storage';
ok $med->uuid, 'The UUID should now be defined';
ok $med->thingy_uuid, 'And so should the thingy UUID';
ok $med->uuid ne $med->thingy_uuid, 'And they should have different UUIDs';

# We should get the trusted mediateed object attribute.
is_deeply [map { $_->name } $class->persistent_attributes],
          [qw(id uuid state thingy thingy_uuid thingy_state foo booyah)],
    'We should get public and trusted attributes';

# Make sure that methods are delegated.
ok $meth = $class->methods('hello'), 'Get mediate hello method object';
ok $meth2 = $thingy_class->methods('hello'),
    'Get thingy hello method object';
is $meth->acts_as, $meth2, 'Mediate hello should act as thingy hello';
is $meth->delegates_to, $thingy_class,
    'Mediate hello should delegate to thingy';

ok $meth = $class->methods('save'), 'Get mediate save method object';
ok $meth2 = $thingy_class->methods('save'),
    'Get thingy save method object';
ok !$meth->acts_as, 'Mediate save should not act as anything';
ok !$meth->delegates_to, 'Mediate save should not delegate to anything';
ok $meth = $class->methods('thingy_save'), 'Get mediate thingy_save object';
is $meth->acts_as, $meth2, 'Mediate thingy_sve should act as thingy save';
is $meth->delegates_to, $thingy_class,
    'Mediate thingy_save should delegate to thingy';

can_ok $med, 'hello';
can_ok $med, 'save';
can_ok $med, 'thingy_save';
is $med->hello, 'hello', 'The hello() method should dispatch to thingy';

# Make sure that nothing has been modified.
ok $med = MyTestMediates->new, 'Create another Mediate object';
is_deeply [$med->_get_modified], [], 'No attributes should have been modified';
ok !$med->_is_modified('uuid'), 'UUID should not be modified';
ok !$med->_is_modified('foo'), 'And neither should foo';
ok !$med->_is_modified('booyah'), 'Nor booyah';
is_deeply [$med->_get_modified], [], 'Thingy has no mods, either';

ok $med->booyah(undef), 'Set the booyah to undef (unchanged)';
ok !$med->_is_modified('booyah'), 'Booyah should still be unchanged';
is_deeply [$med->_get_modified], [], 'There should still be no list of modified';

ok $med->booyah('amateur'), 'Set the booyah to something different';
ok $med->_is_modified('booyah'), 'It should know that booyah has been modified';
is_deeply [$med->_get_modified], ['booyah'],
    'And booyah should be the only item in the list of modified';

ok $med->foo('Yow'), 'Set the foo attribute';
ok $med->_is_modified('foo'), 'It should know that foo has been modified';
is_deeply [$med->_get_modified], [qw(booyah foo)],
    'It should list both booyah and foo as modified';
ok $med->thingy->_is_modified('foo'), 'Thingy should know foo is modified';
is_deeply [$med->thingy->_get_modified], ['foo'],
    'Thingy should list foo as modified';

ok $med->_clear_modified, 'Clear modified';
ok ! @{$med->_get_modified}, 'Now no attributes should be listed as modified';
ok !$med->_is_modified('foo'), 'It should think that foo is unmodified';
ok !$med->_is_modified('booyah'), 'Same for booyah';

ok $med->thingy->_is_modified('foo'),
    'But thingy should still think foo is modified';
is_deeply [$med->thingy->_get_modified], ['foo'],
    'Thingy should still list foo as modified';
ok $med->thingy->_clear_modified, 'Clear thingy modified';

ok !$med->thingy->_is_modified('foo'),
    'Now thingy should not think foo is modified';
is_deeply [$med->thingy->_get_modified], [],
    'Thingy should list none as modified';
