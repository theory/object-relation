#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 13;
use Kinetic::Build::Test (
    store => { class   => 'Kinetic::Store::DB::Pg' },
    pg =>    { db_name => '__kinetic_test__' },
);

BEGIN {
    use_ok 'Kinetic::Build::Store';
    use_ok 'Kinetic::Build::Schema'
};

ok my $sb = Kinetic::Build::Store->new, "Load store builder";
isa_ok $sb, 'Kinetic::Build::Store';
isa_ok $sb, 'Kinetic::Build::Store::DB';
isa_ok $sb, 'Kinetic::Build::Store::DB::Pg';

ok my $sg = Kinetic::Build::Schema->new, 'Get new Schema';
isa_ok $sg, 'Kinetic::Build::Schema';
isa_ok $sg, 'Kinetic::Build::Schema::DB';
isa_ok $sg, 'Kinetic::Build::Schema::DB::Pg';

# Build the schema.
ok $sg->load_classes('t/lib'), "Load classes";
my @class_keys = qw(simple one two composed comp_comp);
my $file = 't/data/Pg.sql';
ok $sg->write_schema($file, { order => \@class_keys, with_kinetic => 1 }),
  "Write schema file with ordered classes and setup SQL";

# Build the store.
ok $sb->build($file), "Build data store";



##############################################################################
# Cleanup our mess.
END { File::Path::rmtree(File::Spec->catdir(qw(t data))) }
