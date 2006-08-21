#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 32;
use Test::NoWarnings; # Adds an extra test.

{
    # Fake out loading of Pg store.
    package Object::Relation::Store::DB::Pg;
    $INC{'Object/Relation/Store/Handle/DB/Pg.pm'} = __FILE__;
    sub _add_store_meta { 1 }
}

BEGIN { use_ok 'Object::Relation::Schema' or die };

ok my $sg = Object::Relation::Schema->new(
    'Object::Relation::Store::DB::Pg'
), 'Get new Schema';
isa_ok $sg, 'Object::Relation::Schema';
isa_ok $sg, 'Object::Relation::Schema::DB';
isa_ok $sg, 'Object::Relation::Schema::DB::Pg';

ok $sg->load_classes('t/sample/lib'), "Load classes";
my $file = 't/data/Pg.sql';
ok $sg->write_schema($file), "Write schema file";
my $fn = File::Spec->catfile(split m{/}, $file);
ok -e $fn, "... File exists";

open my $schema, '<', $fn or die "Cannot open '$fn': $!\n";
my @schema = <$schema>;
close $schema;
ok @schema, "... File has contents";

# Test writing out class schemas in the proper order

my @class_keys = map { $_->key } $sg->classes;
test_contains_order(\@schema, @class_keys);

# Test outputting setup SQL at the beginning of the file.
ok $sg->write_schema($file, { with_obj_rel => 1 }),
  "Write schema file with ordered classes and setup SQL";
ok -e $fn, "... File exists";
open $schema, '<', $fn or die "Cannot open '$fn': $!\n";
@schema = <$schema>;
close $schema;
ok @schema, "... Got schema file contents";
is $schema[0], "CREATE DOMAIN state AS SMALLINT NOT NULL DEFAULT 1\n",
  "... Got setup SQL";
test_contains_order(\@schema, @class_keys);


##############################################################################
# Cleanup our mess.
END { unlink $file }

sub test_contains {
    my ($contents, $find) = @_;
    ok contains($contents, $find), "... File contains '$find'";
}

sub test_contains_order {
    my ($contents, @finds) = @_;
    for (@$contents) {
        if (/CREATE VIEW $finds[0]/) {
          ok 1, "... File contains 'CREATE VIEW $finds[0]' in proper order";
          shift @finds;
          last unless @finds;
      }
    }
    for (@finds) {
        ok 0, "...Did not find '$_' in its proper order";
    }
}

sub contains {
    my ($contents, $find) = @_;
    for (@$contents) {
        return 1 if /$find/;
    }
    return;
}
