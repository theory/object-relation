#!/usr/bin/perl -w

use strict;
use Test::More tests => 21;

package MyTestThingy;

BEGIN {
    Test::More->import;
    use_ok('Kinetic::Meta');
    use_ok('Kinetic::Meta::Class');
    use_ok('Kinetic::Meta::Attribute');
}

BEGIN {
    ok my $km = Kinetic::Meta->new(
        key         => 'thingy',
        name        => 'Thingy',
        plural_name => 'Thingies',
    ), "Create TestThingy class";

    ok $km->add_attribute(
        name        => 'foo',
        type        => 'string',
        label       => 'Foo',
        widget_meta => Widget::Meta->new(
            type => 'text',
            tip  => 'Foogoo',
        )
    ), "Add attribute";

    ok $km->build, "Build TestThingy class";
}

package main;

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

ok my $wm = $attr->widget_meta, "Get widget meta object";
isa_ok $wm, 'Widget::Meta';


