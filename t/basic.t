#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 81;
use Data::UUID;

BEGIN {
    use_ok 'Kinetic';
    use_ok 'Kinetic::Util::Context';
    use_ok 'Kinetic::Util::Language';
    use_ok 'Kinetic::Util::Language::en_us';
    use_ok 'Kinetic::Util::State';
};

isa_ok( $Kinetic::VERSION, 'version');

package MyApp::TestThingy;
use base 'Kinetic';
BEGIN {
    use Test::More;
    ok my $km = Kinetic::Meta->new(
        key         => 'thingy',
        name        => 'Thingy',
        plural_name => 'Thingies',
    ), "Create TestThingy class";
    ok $km->build, "Build TestThingy class";
}

package main;
use Kinetic::Util::State qw(:all);

# Add new strings to the lexicon.
Kinetic::Util::Language::en_us->add_to_lexicon(
  'Thingy',
  'Thingy',
  'Thingies',
  'Thingies',
);

ok( Kinetic::Util::Context->language(Kinetic::Util::Language->get_handle('en_us')),
    "Set language context" );

# Check Meta objects.
ok my $class = MyApp::TestThingy->my_class, "Get meta class";
isa_ok $class, 'Kinetic::Meta::Class';
isa_ok $class, 'Class::Meta::Class';
is $class->key, 'thingy', "Check class key";
is $class->name, 'Thingy', "Check class name";
is $class->plural_name, 'Thingies', "Check class plural name";

ok my $kinetic = MyApp::TestThingy->new, "Create new TestThingy";
isa_ok $kinetic, 'MyApp::TestThingy';
isa_ok $kinetic, 'Kinetic';

# Check GUID.
my $uuid = Data::UUID->new;
ok my $guid = $kinetic->guid, "Get GUID";
ok $uuid->from_string($guid), "It's a valid GUID";
ok $uuid->from_hexstring($kinetic->guid_hex), "Valid Hex GUID";
ok $uuid->from_b64string($kinetic->guid_base64), "Valid Base 64 GUID";
ok $uuid->to_string($kinetic->guid_bin), "Valid binary GUID";
ok my $attr = $class->attributes('guid'), "Get GUID attr object";
is $attr->get($kinetic), $kinetic->guid, "Get GUID value";
is $attr->name, 'guid', "Check GUID attr name";
is $attr->label, 'GUID', "Check GUID attr label";
ok $attr->required, 'Check GUID attr required';
eval { $attr->set($kinetic, 'foo') };
ok my $err = $@, "Check GUID is read-only";
eval { $kinetic->guid('foo') };
ok $err = $@, "Check cannot set GUID";
ok my $wm = $attr->widget_meta, "Get GUID widget meta object";
is $wm->type, 'text', "Check GUID widget type";
is $wm->tip, 'The globally unique identifier for this object',
  "Check GUID widget tip";

# Check name.
is $kinetic->name, undef, "Check for undefined name";
ok $kinetic->name('foo'), "Set name to 'foo'";
is $kinetic->name, 'foo', "Check for name 'foo'";
ok $attr = $class->attributes('name'), "Get name attr object";
is $attr->get($kinetic), $kinetic->name, "Get name value";
is $attr->type, 'string', "Check name attr type";
is $attr->name, 'name', "Check name attr name";
is $attr->label, 'Name', "Check name attr label";
ok $attr->required, 'Check name attr required';
ok $wm = $attr->widget_meta, "Get name widget meta object";
is $wm->type, 'text', "Check name widget type";
is $wm->tip, 'The name of this object', "Check name widget tip";

# Check description.
is $kinetic->description, undef, "Check for undefined description";
ok $kinetic->description('foo'), "Set description to 'foo'";
is $kinetic->description, 'foo', "Check for description 'foo'";
ok $attr = $class->attributes('description'), "Get description attr object";
is $attr->get($kinetic), $kinetic->description, "Get description value";
is $attr->type, 'string', "Check description attr type";
is $attr->name, 'description', "Check description attr name";
is $attr->label, 'Description', "Check description attr label";
ok !$attr->required, 'Check description attr not required';
ok $wm = $attr->widget_meta, "Get description widget meta object";
is $wm->type, 'textarea', "Check description widget type";
is $wm->tip, 'The description of this object', "Check description widget tip";

# Check state.
is $kinetic->state, ACTIVE, "Check for active state";
ok $kinetic->state(INACTIVE), "Set state to INACTIVE";
is $kinetic->state, INACTIVE, "Check for INACTIVE state";
ok $kinetic->is_inactive, 'Check is_inactive';
ok $kinetic->activate, "Activate";
ok ! $kinetic->is_inactive, "Check not is_inactive";
ok $kinetic->is_active, "Check is active";
ok ! $kinetic->is_permanent, "Check not is_permanent";
ok ! $kinetic->is_deleted, "Check not is_deleted";
ok $kinetic->delete, "Delete";
ok $kinetic->is_deleted, "Check is_deleted";
ok $kinetic->deactivate, "Deactivate";
ok $kinetic->is_inactive, 'Check is_inactive again';
ok $kinetic->purge, "Purge";
ok ! $kinetic->is_inactive, 'Check not is_inactive again';
ok $attr = $class->attributes('state'), "Get state attr object";
is $attr->get($kinetic), $kinetic->state, "Get state value";
is $attr->type, 'state', "Check state attr type";
is $attr->name, 'state', "Check state attr name";
is $attr->label, 'State', "Check state attr label";
ok $attr->required, 'Check state attr required';
ok $wm = $attr->widget_meta, "Get state widget meta object";
is $wm->type, 'dropdown', "Check state widget type";
is $wm->tip, 'The state of this object', "Check state widget tip";
