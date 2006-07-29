#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 56;
#use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.
use MIME::Base64 ();

BEGIN {
    use_ok 'Object::Relation::Base' or die;
    use_ok 'Object::Relation::Language' or die;
    use_ok 'Object::Relation::Language::en_us' or die;
    use_ok 'Object::Relation::DataType::State' or die;
};

package MyApp::TestThingy;
use base 'Object::Relation::Base';
BEGIN {
    use Test::More;
    ok my $km = Object::Relation::Meta->new(
        key         => 'thingy',
        name        => 'Thingy',
        plural_name => 'Thingies',
    ), "Create TestThingy class";
    ok $km->build, "Build TestThingy class";
}

package main;
use Object::Relation::DataType::State qw(:all);
use Object::Relation::Functions qw(:uuid);

# Add new strings to the lexicon.
Object::Relation::Language::en->add_to_lexicon(
  'Thingy',
  'Thingy',
  'Thingies',
  'Thingies',
);

# Check Meta objects.
ok my $class = MyApp::TestThingy->my_class, "Get meta class";
isa_ok $class, 'Object::Relation::Meta::Class';
isa_ok $class, 'Class::Meta::Class';
is $class->key, 'thingy', "Check class key";
is $class->name, 'Thingy', "Check class name";
is $class->plural_name, 'Thingies', "Check class plural name";

ok my $obj_rel = MyApp::TestThingy->new, "Create new TestThingy";
isa_ok $obj_rel, 'MyApp::TestThingy';
isa_ok $obj_rel, 'Object::Relation::Base';

# Check UUID.
ok my $uuid = $obj_rel->uuid, "Get UUID";
ok !$obj_rel->is_persistent, 'It should not be persistent';
ok uuid_to_bin($uuid), "It's a valid UUID";
is join('-', unpack('x2 a8 a4 a4 a4 a12', $obj_rel->uuid_hex)),
    $obj_rel->uuid, 'Valid Hex UUID';
is $obj_rel->uuid_bin, uuid_to_bin($uuid), 'Valid binary UUID';
is MIME::Base64::decode_base64($obj_rel->uuid_base64),
    $obj_rel->uuid_bin, 'Valid Base64 UUID';
ok my $attr = $class->attributes('uuid'), "Get UUID attr object";
is $attr->get($obj_rel), $obj_rel->uuid, "Get UUID value";
is $attr->name, 'uuid', "Check UUID attr name";
is $attr->label, 'UUID', "Check UUID attr label";
ok $attr->required, 'Check UUID attr required';
eval { $attr->set($obj_rel, 'foo') };
ok my $err = $@, "Check UUID is read-only";
eval { $obj_rel->uuid('foo') };
ok $err = $@, "Check cannot set UUID";
ok my $wm = $attr->widget_meta, "Get UUID widget meta object";
is $wm->type, 'text', "Check UUID widget type";
is $wm->tip, 'The globally unique identifier for this object',
  "Check UUID widget tip";

# Check state.
is $obj_rel->state, ACTIVE, "Check for active state";
ok $obj_rel->state(INACTIVE), "Set state to INACTIVE";
is $obj_rel->state, INACTIVE, "Check for INACTIVE state";
ok $obj_rel->is_inactive, 'Check is_inactive';
ok $obj_rel->activate, "Activate";
ok ! $obj_rel->is_inactive, "Check not is_inactive";
ok $obj_rel->is_active, "Check is active";
ok ! $obj_rel->is_permanent, "Check not is_permanent";
ok ! $obj_rel->is_deleted, "Check not is_deleted";
ok $obj_rel->delete, "Delete";
ok $obj_rel->is_deleted, "Check is_deleted";
ok $obj_rel->deactivate, "Deactivate";
ok $obj_rel->is_inactive, 'Check is_inactive again';
ok $obj_rel->purge, "Purge";
ok ! $obj_rel->is_inactive, 'Check not is_inactive again';
ok $attr = $class->attributes('state'), "Get state attr object";
is $attr->get($obj_rel), $obj_rel->state, "Get state value";
is $attr->type, 'state', "Check state attr type";
is $attr->name, 'state', "Check state attr name";
is $attr->label, 'State', "Check state attr label";
ok $attr->required, 'Check state attr required';
ok $wm = $attr->widget_meta, "Get state widget meta object";
is $wm->type, 'dropdown', "Check state widget type";
is $wm->tip, 'The state of this object', "Check state widget tip";
