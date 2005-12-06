#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 60;
#use Test::More 'no_plan';
use OSSP::uuid;
use MIME::Base64 ();

BEGIN {
    use_ok 'Kinetic' or die;
    use_ok 'Kinetic::Util::Context' or die;
    use_ok 'Kinetic::Util::Language' or die;
    use_ok 'Kinetic::Util::Language::en_us' or die;
    use_ok 'Kinetic::Util::State' or die;
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

# Check UUID.
$kinetic->_save_prep; # Force UUID generation.
my $ug = OSSP::uuid->new;
ok my $uuid = $kinetic->uuid, "Get UUID";
ok $ug->import(str => $uuid), "It's a valid UUID";
is join('-', unpack('x2 a8 a4 a4 a4 a12', $kinetic->uuid_hex)),
    $kinetic->uuid, 'Valid Hex UUID';
is $kinetic->uuid_bin, $ug->export('bin'), 'Valid binary UUID';
is MIME::Base64::decode_base64($kinetic->uuid_base64),
    $kinetic->uuid_bin, 'Valid Base64 UUID';
ok my $attr = $class->attributes('uuid'), "Get UUID attr object";
is $attr->get($kinetic), $kinetic->uuid, "Get UUID value";
is $attr->name, 'uuid', "Check UUID attr name";
is $attr->label, 'UUID', "Check UUID attr label";
ok $attr->required, 'Check UUID attr required';
eval { $attr->set($kinetic, 'foo') };
ok my $err = $@, "Check UUID is read-only";
eval { $kinetic->uuid('foo') };
ok $err = $@, "Check cannot set UUID";
ok my $wm = $attr->widget_meta, "Get UUID widget meta object";
is $wm->type, 'text', "Check UUID widget type";
is $wm->tip, 'The globally unique identifier for this object',
  "Check UUID widget tip";
ok $kinetic = MyApp::TestThingy->new(
    uuid => '12CAD854-08BD-11D9-8AF0-8AB02ED80375'
), "Create new kinetic and assign a UUID";
is $kinetic->uuid, '12CAD854-08BD-11D9-8AF0-8AB02ED80375',
  "Our UUID should have been assigned";
eval {  MyApp::TestThingy->new(uuid => 'foo' ) };
ok $err = $@, "We should get an error when using a bogus UUID";

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
