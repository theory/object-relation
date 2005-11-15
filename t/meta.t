#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 69;
#use Test::More 'no_plan';

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
    ), "Add string attribute";

    ok $km->add_attribute(
        name          => 'lname',
        type          => 'string',
        label         => 'Last Name',
    ), "Add string attribute";

    ok $km->build, "Build TestFooey class";
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
is_deeply [$class->ref_attributes], [],
  "There should be no referenced attributes";
is_deeply [$class->attributes],[$class->direct_attributes],
  "With no ref_attributes, direct_attributes should return all attributes";

ok my $attr = $class->attributes('foo'), "Get foo attribute";
isa_ok $attr, 'Kinetic::Meta::Attribute';
isa_ok $attr, 'Class::Meta::Attribute';
is $attr->name, 'foo', "Check attr name";
is $attr->type, 'string', "Check attr type";
is $attr->label, 'Foo', "Check attr label";
is $attr->indexed, 1, "Indexed should be true";

eval { $attr->_column };
ok $err = $@, "Should get error trying to call _column()";
like $err,
  qr/Can't locate object method "_column" via package "Kinetic::Meta::Attribute"/,
  '...Because the _column() method should not exist';

eval { $attr->_view_column };
ok $err = $@, "Should get error trying to call _view_column()";
like $err,
  qr/Can't locate object method "_view_column" via package "Kinetic::Meta::Attribute"/,
  '...Because the _view_column() method should not exist';

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
is_deeply [$fclass->ref_attributes], [$attr],
  "We should be able to get the one referenced attribute";
is $attr->references, MyTestThingy->my_class,
  "The thingy object should reference the thingy class";
is $attr->relationship, 'has',
  'The Fooey should have a "has" relationship to the thingy';
$attr = $fclass->attributes('fname');
is_deeply [$fclass->direct_attributes], [$attr, $fclass->attributes('lname')],
  "And direct_attributes should return the non-referenced attributes";
is $attr->relationship, undef, "The fname attribute should have no relationship";
