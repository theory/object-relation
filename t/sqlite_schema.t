#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use lib 't/lib';
use Kinetic::TestSetup store => { class => 'Kinetic::Store::DB::SQLite' };
use Test::More tests => 8;

BEGIN { use_ok 'Kinetic::Build::Schema' };

ok my $sg = Kinetic::Build::Schema->new, 'Get new Schema';
isa_ok $sg, 'Kinetic::Build::Schema';
isa_ok $sg, 'Kinetic::Build::Schema::DB';
isa_ok $sg, 'Kinetic::Build::Schema::DB::SQLite';

ok $sg->load_classes('t/lib'), "Load classes";
my %classes;
for my $class ($sg->classes) {
    ok $class->is_a('Kinetic'), "Class is a Kinetic";
    $classes{$class->package} = $class;
}
is $classes{'TestApp::Simple'}->key, 'simple', "Check for simple class";

##############################################################################
# Check the SQL generated for the simple class.
my $simple = $classes{'TestApp::Simple'};

( my $testsql = q{CREATE TABLE simple (
    id          INTEGER NOT NULL PRIMARY KEY,
    guid        TEXT    NOT NULL,
    name        TEXT    NOT NULL,
    description TEXT,
    state       STATE   NOT NULL
);

CREATE UNIQUE INDEX udx_simple_guid ON simple (guid);
CREATE INDEX idx_simple_name ON simple (name);
CREATE INDEX idx_simple_state ON simple (state);

}) =~ s/[ ]+/ /g;

ok my $sql = $sg->schema_for_class($simple), "Get schema for Simple class";
$sql =~ s/[ ]+/ /g;
is $sql, $testsql, "Check Simple class SQL";

