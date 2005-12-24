#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 158;
#use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.

package MyTestBase;
use base 'Kinetic';

BEGIN {
    Test::More->import;
    use_ok('Kinetic::Meta') or die;
    use_ok('Kinetic::Util::Language') or die;
    use_ok('Kinetic::Util::Language::en_us') or die;
    use_ok('Kinetic::Meta::Class') or die;
    use_ok('Kinetic::Meta::Attribute') or die;
    use_ok('Kinetic::Meta::AccessorBuilder') or die;
    use_ok('Kinetic::Meta::Widget') or die;
}

BEGIN {
    ok( Kinetic::Meta->new( key => 'base')->build, 'Build base' );
}

package MyTestThingy;
use base 'Kinetic';
BEGIN { Test::More->import }
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

    ok $km->add_constructor(
        name   => 'new',
        create => 1,
    ), 'Add constructor';

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

##############################################################################

package MyTestHas;
use base 'Kinetic';
BEGIN { Test::More->import }
BEGIN {
    ok my $km = Kinetic::Meta->new(
        key         => 'has',
        name        => 'Has',
        plural_name => 'Hases',
    ), "Create TestHas class";

    ok $km->add_constructor(
        name   => 'new',
        create => 1,
    ), 'Add constructor';

    ok $km->add_attribute(
        name          => 'thingy',
        type          => 'thingy',
#        relationship  => 'has', # default
    ), "Add has attribute";

    ok $km->build, "Build MyTestHas class";
}

##############################################################################

package MyTestTypeOf;
use base 'MyTestBase';
BEGIN { Test::More->import }
BEGIN {
    ok my $km = Kinetic::Meta->new(
        key         => 'typeof',
        name        => 'Typeof',
        plural_name => 'Typeofs',
        type_of     => 'thingy',
    ), "Create TestTypeof class";

    ok $km->add_constructor(
        name   => 'new',
        create => 1,
    ), 'Add constructor';

    ok $km->build, "Build TestTypeof class";
}

##############################################################################

package MyTestPartof;
use base 'Kinetic';
BEGIN { Test::More->import }
BEGIN {
    ok my $km = Kinetic::Meta->new(
        key         => 'partof',
        name        => 'Partof',
        plural_name => 'Partofs',
    ), "Create TestPartof class";

    ok $km->add_constructor(
        name   => 'new',
        create => 1,
    ), 'Add constructor';

    ok $km->add_attribute(
        name          => 'thingy',
        type          => 'thingy',
        relationship  => 'part_of',
    ), "Add part_of attribute";

    ok $km->build, "Build MyTestPartof class";
}

##############################################################################

package MyTestReferences;
use base 'Kinetic';
BEGIN { Test::More->import }
BEGIN {
    ok my $km = Kinetic::Meta->new(
        key         => 'references',
        name        => 'References',
        plural_name => 'References',
    ), "Create TestReferences class";

    ok $km->add_constructor(
        name   => 'new',
        create => 1,
    ), 'Add constructor';

    ok $km->add_attribute(
        name          => 'thingy',
        type          => 'thingy',
        relationship  => 'references',
    ), "Add references attribute";

    ok $km->build, "Build MyTestReferences class";
}

##############################################################################

package MyTestExtends;
use base 'MyTestBase';
BEGIN { Test::More->import }
BEGIN {
    ok my $km = Kinetic::Meta->new(
        key         => 'extends',
        name        => 'Extends',
        plural_name => 'Extends',
        extends     => 'thingy',
    ), "Create TestExtends class";

    ok $km->add_constructor(
        name   => 'new',
        create => 1,
    ), 'Add constructor';

    ok $km->build, "Build TestExtends class";
}

##############################################################################

package MyTestChildof;
use base 'Kinetic';
BEGIN { Test::More->import }
BEGIN {
    ok my $km = Kinetic::Meta->new(
        key         => 'childof',
        name        => 'Childof',
        plural_name => 'Childofs',
    ), "Create TestChildof class";

    ok $km->add_constructor(
        name   => 'new',
        create => 1,
    ), 'Add constructor';

    ok $km->add_attribute(
        name          => 'thingy',
        type          => 'thingy',
        relationship  => 'child_of',
    ), "Add child_of attribute";

    ok $km->build, "Build TestChildof class";
}

##############################################################################

package MyTestMediates;
use base 'MyTestBase';
BEGIN { Test::More->import }
BEGIN {
    ok my $km = Kinetic::Meta->new(
        key         => 'mediates',
        name        => 'Mediates',
        plural_name => 'Mediates',
        mediates    => 'thingy',
    ), "Create TestMediates class";

    ok $km->add_constructor(
        name   => 'new',
        create => 1,
    ), 'Add constructor';

    ok $km->build, "Build TestMediates class";
}

##############################################################################

package MyTestFail;
use base 'Kinetic';
BEGIN { Test::More->import }

ok my $km = Kinetic::Meta->new( key => 'fail'), "Create a failing KM object";
eval{ $km->add_attribute(
    name          => 'fail',
    type          => 'fail',
    relationship  => 'foo',
) };

ok my $err = $@, "An unknown relationship should throw an error";
like $err, qr/I don't know what a "foo" relationship is/, #'
  "And it should be the correct error";

##############################################################################

# Add new strings to the lexicon.
Kinetic::Util::Language::en_us->add_to_lexicon(
  'Thingy'   => 'Thingy',
  'Thingies' => 'Thingies',
  'Foo'      => 'Foo',
  'Has'      => 'Has',
  'Hases'    => 'Hases',
  'Typeof'   => 'Typeof',
  'Typeofs'  => 'Typeofs',
  'Partof'   => 'Partof',
  'Partofs'  => 'Partofs',
  'References' => 'References',
  'Extends'  => 'Extends',
  'Childof'  => 'Childof',
  'Childofs' => 'Childofs',
  'Mediates' => 'Mediates',
);

ok( Kinetic::Util::Context->language(Kinetic::Util::Language->get_handle('en_us')),
    "Set language context" );

##############################################################################
package main;

# Check out the has attribute.
ok my $class = MyTestHas->my_class, "Get Has class object";
ok my $attr = $class->attributes('thingy'), "Get thingy attribute";
is $attr->name, 'thingy', "We should have the thingy attr";
isa_ok $attr, 'Kinetic::Meta::Attribute';
isa_ok $attr, 'Class::Meta::Attribute';
is $attr->references, MyTestThingy->my_class,
  "The thingy object should reference the thingy class";
is $attr->relationship, 'has', 'It should have a "has" relationship';

ok my $obj = MyTestHas->new, "Create new Has";
ok my $thing = MyTestThingy->new(foo => 'bar'), "Create new Thingy";
is $thing->foo, 'bar', 'Foo should be set to "bar"';

ok $obj->thingy($thing), 'Set thingy to thing';
is $obj->thingy, $thing, 'We should be able to fetch it';
eval { $obj->foo };
ok $err = $@, 'Should get error call a delegate method';
like $err, qr/Can't locate object method "foo" via package "MyTestHas"/, #'
  "Because there is no delegate method";

##############################################################################
# Check out the type_of attribute.
ok $class = MyTestTypeOf->my_class, "Get Typeof class object";
ok $attr = $class->attributes('thingy'), "Get thingy attribute";
is $attr->name, 'thingy', "We should have the thingy attr";
isa_ok $attr, 'Kinetic::Meta::Attribute';
isa_ok $attr, 'Class::Meta::Attribute';
is $attr->references, MyTestThingy->my_class,
  "The thingy object should reference the thingy class";
is $attr->relationship, 'type_of', 'It should have a "type_of" relationship';

ok $obj = MyTestTypeOf->new, "Create new Typeof";
is $obj->foo, undef,
  'Should just return undef when the thingy attribute is not set';
ok $thing = MyTestThingy->new(foo => 'bar'), "Create new Thingy";
is $thing->foo, 'bar', 'Foo should be set to "bar"';

ok $obj->thingy($thing), 'Set thingy to thing';
is $obj->foo, 'bar', 'Typeof foo should return "bar"';
ok $thing->foo('bat'), 'Change thing foo to "bat"';
is $thing->foo, 'bat', 'Foo should now be set to "bat"';
is $obj->foo, 'bat', 'Typeof foo should also return "bat"';
eval { $obj->foo('ick') };
ok $err = $@, 'Should get error trying to set via thingy delegate';
like $err, qr/Cannot assign to read-only attribute .foo./,
  "We should get an error when we try to assign to foo via its delegate";

##############################################################################
# Check out the part_of attribute.
ok $class = MyTestPartof->my_class, "Get Partof class object";
ok $attr = $class->attributes('thingy'), "Get thingy attribute";
is $attr->name, 'thingy', "We should have the thingy attr";
isa_ok $attr, 'Kinetic::Meta::Attribute';
isa_ok $attr, 'Class::Meta::Attribute';
is $attr->references, MyTestThingy->my_class,
  "The thingy object should reference the thingy class";
is $attr->relationship, 'part_of', 'It should have a "part_of" relationship';

ok $obj = MyTestPartof->new, "Create new Partof";
ok $thing = MyTestThingy->new(foo => 'bar'), "Create new Thingy";
is $thing->foo, 'bar', 'Foo should be set to "bar"';

ok $obj->thingy($thing), 'Set thingy to thing';
is $obj->thingy, $thing, 'We should be able to fetch it';
eval { $obj->foo };
ok $err = $@, 'Should get error call a delegate method';
like $err, qr/Can't locate object method "foo" via package "MyTestPartof"/, #'
  "Because there is no delegate method";

##############################################################################
# Check out the references attribute.
ok $class = MyTestReferences->my_class, "Get References class object";
ok $attr = $class->attributes('thingy'), "Get thingy attribute";
is $attr->name, 'thingy', "We should have the thingy attr";
isa_ok $attr, 'Kinetic::Meta::Attribute';
isa_ok $attr, 'Class::Meta::Attribute';
is $attr->references, MyTestThingy->my_class,
  "The thingy object should reference the thingy class";
is $attr->relationship, 'references',
  'It should have a "part_of" relationship';

ok $obj = MyTestReferences->new, "Create new References";
ok $thing = MyTestThingy->new(foo => 'bar'), "Create new Thingy";
is $thing->foo, 'bar', 'Foo should be set to "bar"';

ok $obj->thingy($thing), 'Set thingy to thing';
is $obj->thingy, $thing, 'We should be able to fetch it';
eval { $obj->foo };
ok $err = $@, 'Should get error call a delegate method';
like $err, qr/Can't locate object method "foo" via package "MyTestReferences"/, #'
  "Because there is no delegate method";

##############################################################################
# Check out the extends attribute.
ok $class = MyTestExtends->my_class, "Get Extends class object";
ok $attr = $class->attributes('thingy'), "Get thingy attribute";
is $attr->name, 'thingy', "We should have the thingy attr";
isa_ok $attr, 'Kinetic::Meta::Attribute';
isa_ok $attr, 'Class::Meta::Attribute';
is $attr->references, MyTestThingy->my_class,
  "The thingy object should reference the thingy class";
is $attr->relationship, 'extends', 'It should have a "extends" relationship';
ok $attr->once, 'Extends relationships should be setable only once';

ok $obj = MyTestExtends->new, "Create new Extends";
is $obj->foo, undef,
  'Should just return undef when the thingy attribute is not set';
ok $thing = MyTestThingy->new(foo => 'bar'), "Create new Thingy";
is $thing->foo, 'bar', 'Foo should be set to "bar"';

ok $obj->thingy($thing), 'Set thingy to thing';
is $obj->foo, 'bar', 'Extends foo should return "bar"';
ok $thing->foo('bat'), 'Change thing foo to "bat"';
is $thing->foo, 'bat', 'Foo should now be set to "bat"';
is $obj->foo, 'bat', 'Extends foo should also return "bat"';
ok $obj->foo('ick'), "We should be able to set via the delegate";
is $thing->foo, 'ick', 'Foo should now be set to "ick"';
is $obj->foo, 'ick', 'Extends foo should also return "ick"';

##############################################################################
# Check out the child_of attribute.
ok $class = MyTestChildof->my_class, "Get Childof class object";
ok $attr = $class->attributes('thingy'), "Get thingy attribute";
is $attr->name, 'thingy', "We should have the thingy attr";
isa_ok $attr, 'Kinetic::Meta::Attribute';
isa_ok $attr, 'Class::Meta::Attribute';
is $attr->references, MyTestThingy->my_class,
  "The thingy object should reference the thingy class";
is $attr->relationship, 'child_of', 'It should have a "child_of" relationship';

ok $obj = MyTestChildof->new, "Create new Childof";
ok $thing = MyTestThingy->new(foo => 'bar'), "Create new Thingy";
is $thing->foo, 'bar', 'Foo should be set to "bar"';

ok $obj->thingy($thing), 'Set thingy to thing';
is $obj->thingy, $thing, 'We should be able to fetch it';
eval { $obj->foo };
ok $err = $@, 'Should get error call a delegate method';
like $err, qr/Can't locate object method "foo" via package "MyTestChildof"/, #'
  "Because there is no delegate method";

##############################################################################
# Check out the mediates attribute.
ok $class = MyTestMediates->my_class, "Get Mediates class object";
ok $attr = $class->attributes('thingy'), "Get thingy attribute";
is $attr->name, 'thingy', "We should have the thingy attr";
isa_ok $attr, 'Kinetic::Meta::Attribute';
isa_ok $attr, 'Class::Meta::Attribute';
is $attr->references, MyTestThingy->my_class,
  "The thingy object should reference the thingy class";
is $attr->relationship, 'mediates', 'It should have a "mediates" relationship';
ok $attr->once, 'Mediagtes relationships should be setable only once';

ok $obj = MyTestMediates->new, "Create new Mediates";
is $obj->foo, undef,
  'Should just return undef when the thingy attribute is not set';
ok $thing = MyTestThingy->new(foo => 'bar'), "Create new Thingy";
is $thing->foo, 'bar', 'Foo should be set to "bar"';

ok $obj->thingy($thing), 'Set thingy to thing';
is $obj->foo, 'bar', 'Mediates foo should return "bar"';
ok $thing->foo('bat'), 'Change thing foo to "bat"';
is $thing->foo, 'bat', 'Foo should now be set to "bat"';
is $obj->foo, 'bat', 'Mediates foo should also return "bat"';
ok $obj->foo('ick'), "We should be able to set via the delegate";
is $thing->foo, 'ick', 'Foo should now be set to "ick"';
is $obj->foo, 'ick', 'Mediates foo should also return "ick"';

# XXX Need to deal with has_many, part_of_many, and references_many.
# Come back to it when collections are figured out.
