#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use lib 't/lib';
use Kinetic::TestSetup store => { class => 'Kinetic::Store::DB::Pg' };
use Test::More tests => 10;

package main;

BEGIN { use_ok 'Kinetic::Build::SchemaGen' };

ok my $sg = Kinetic::Build::SchemaGen->new, 'Get new SchemaGen';
isa_ok $sg, 'Kinetic::Build::SchemaGen';
isa_ok $sg, 'Kinetic::Build::SchemaGen::DB';
isa_ok $sg, 'Kinetic::Build::SchemaGen::DB::Pg';

ok $sg->load_classes('t/lib'), "Load classes";
ok my @classes = $sg->classes, "Get classes";
is $classes[0]->key, 'simple', "Check for simple class";


##############################################################################
# Check the SQL generated for the simple class.
my $simple = $classes[0];

( my $testsql = q{CREATE TABLE simple (
    id          INTEGER  NOT NULL DEFAULT NEXTVAL('kinetic_seq'),
    guid        TEXT     NOT NULL,
    name        TEXT     NOT NULL,
    description TEXT,
    state       INT2     NOT NULL DEFAULT '1'
);
}) =~ s/\s+/ /g;

ok my $sql = $sg->schema_for_class($simple), "Get schema for Simple class";
$sql =~ s/\s+/ /g;
is $sql, $testsql, "Check Simple class SQL";


