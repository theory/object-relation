#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 42;

package MyTestThingy;

BEGIN {
    Test::More->import;
    use_ok('Kinetic::Meta', ':with_dbstore_api') or die;
    use_ok('Kinetic::Util::Language') or die;
    use_ok('Kinetic::Util::Language::en_us') or die;
    use_ok('Kinetic::Meta::Class') or die;
    use_ok('Kinetic::Meta::Attribute') or die;
    use_ok('Kinetic::Meta::AccessorBuilder') or die;
    use_ok('Kinetic::Meta::Widget') or die;
}

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
        name => 'id',
        type => 'whole',
    ), "Add id attribute";

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
    ), "Add foo attribute";

    ok $km->build, "Build TestThingy class";
}

package MyTestFooey;

BEGIN {
    Test::More->import;
}

BEGIN {
    ok my $km = Kinetic::Meta->new(
        key         => 'fooey',
        name        => 'Fooey',
        plural_name => 'Fooies',
    ), "Create TestFooey class";

    ok $km->add_attribute(
        name          => 'thingy',
        type          => 'thingy',
        label         => 'Thingy',
        indexed       => 1,
    ), "Add thingy attribute";

    ok $km->build, "Build TestThingy class";
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
use aliased 'Test::MockModule';

ok my $class = MyTestThingy->my_class, "Get meta class object";
isa_ok $class, 'Kinetic::Meta::Class';
isa_ok $class, 'Class::Meta::Class';

is $class->key, 'thingy', 'Check key';
is $class->package, 'MyTestThingy', 'Check package';
is $class->name, 'Thingy', 'Check name';
is $class->plural_name, 'Thingies', 'Check plural name';

ok my $attr = $class->attributes('foo'), "Get foo attribute";
isa_ok $attr, 'Kinetic::Meta::Attribute';
isa_ok $attr, 'Class::Meta::Attribute';
is $attr->name, 'foo', "Check attr name";
is $attr->type, 'string', "Check attr type";
is $attr->label, 'Foo', "Check attr label";
is $attr->indexed, 1, "Indexed should be true";

is $attr->_column, $attr->name,
  'The _column() method should return the column name';
is $attr->_view_column, $attr->name,
  'The _view_column() method should return the view column name';

# Make sure they work when the attribute references another attribute.
my $mock = MockModule->new('Kinetic::Meta::Attribute');
$mock->mock(references => 1 );
is $attr->_column, $attr->name . '_id',
  'The _column() method should return the reference column name';
is $attr->_view_column, $attr->name . '__id',
  'The _view_column() method should return the reference view column name';
$mock->unmock_all;

ok my $wm = $attr->widget_meta, "Get widget meta object";
isa_ok $wm, 'Kinetic::Meta::Widget';
isa_ok $wm, 'Widget::Meta';
is $wm->tip, 'Kinetic', "Check tip";

ok my $fclass = MyTestFooey->my_class, "Get Fooey class object";
ok $attr = $fclass->attributes('thingy'), "Get thingy attribute";
is $attr->raw({ thingy => bless { id => 10 }, $class->package }), 10,
  "We should get an ID from raw()";
