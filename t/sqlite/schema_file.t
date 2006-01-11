#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Kinetic::Build::Test store => { class => 'Kinetic::Store::DB::SQLite' };
use Test::More tests => 30;
use Test::NoWarnings; # Adds an extra test.

{
    # Fake out loading of SQLite store.
    package Kinetic::Store::DB::SQLite;
    use File::Spec::Functions 'catfile';
    $INC{catfile qw(Kinetic Store DB SQLite.pm)} = __FILE__;
    sub _add_store_meta { 1 }
}

BEGIN { use_ok 'Kinetic::Build::Schema' or die };

ok my $sg = Kinetic::Build::Schema->new, 'Get new Schema';
isa_ok $sg, 'Kinetic::Build::Schema';
isa_ok $sg, 'Kinetic::Build::Schema::DB';
isa_ok $sg, 'Kinetic::Build::Schema::DB::SQLite';

ok $sg->load_classes('t/sample/lib'), "Load classes";
my $file = 't/data/SQLite.sql';
ok $sg->write_schema($file), "Write schema file";
my $fn = File::Spec->catfile(split m{/}, $file);
ok -e $fn, "... File exists";

open my $schema, '<', $fn or die "Cannot open '$fn': $!\n";
my @schema = <$schema>;
close $schema;
ok @schema, "... File has contents";

my @class_keys = map { $_->key } $sg->classes;
test_contains_order(\@schema, @class_keys);

# Test outputting setup SQL at the beginning of the file.
ok $sg->write_schema($file, { with_kinetic => 1 }),
  "Write schema file with ordered classes and setup SQL";
ok -e $fn, "... File exists";
open $schema, '<', $fn or die "Cannot open '$fn': $!\n";
@schema = <$schema>;
close $schema;
ok @schema, "... Got schema file contents";

is $schema[0], "CREATE TABLE _simple (\n",
  "... Got first create table statement";
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
