#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use lib 't/lib';
use Kinetic::TestSetup store => { class => 'Kinetic::Store::DB::Pg' };
use Test::More tests => 12;

package main;

BEGIN { use_ok 'Kinetic::Build::Schema' };

ok my $sg = Kinetic::Build::Schema->new, 'Get new Schema';
isa_ok $sg, 'Kinetic::Build::Schema';
isa_ok $sg, 'Kinetic::Build::Schema::DB';
isa_ok $sg, 'Kinetic::Build::Schema::DB::Pg';

ok $sg->load_classes('t/lib'), "Load classes";
ok my @classes = $sg->classes, "Get classes";
is $classes[0]->key, 'simple', "Check for simple class";


##############################################################################
# Check the SQL generated for the simple class.
my $simple = $classes[0];

( my $testsql = q{CREATE TABLE simple (
    id          INTEGER  NOT NULL PRIMARY KEY DEFAULT NEXTVAL('seq_kinetic'),
    guid        TEXT     NOT NULL,
    name        TEXT     NOT NULL,
    description TEXT,
    state       INT2     NOT NULL DEFAULT '1'
);

CREATE UNIQUE INDEX udx_simple_guid ON simple (LOWER(guid));
CREATE INDEX idx_simple_name ON simple (LOWER(name));
CREATE INDEX idx_simple_state ON simple (state);
}) =~ s/[ ]+/ /g;

ok my $sql = $sg->schema_for_class($simple), "Get schema for Simple class";
$sql =~ s/[ ]+/ /g;
is $sql, $testsql, "Check Simple class SQL";

##############################################################################
# Check the SQL generated for the subclass.
my $one = $classes[1];

( $testsql = q{CREATE TABLE one (
    simple_id   INTEGER  NOT NULL PRIMARY KEY,
    bool        BOOLEAN  NOT NULL DEFAULT '1'
);
}) =~ s/[ ]+/ /g;

ok $sql = $sg->schema_for_class($one), "Get schema for One class";
$sql =~ s/[ ]+/ /g;
is $sql, $testsql, "Check One class SQL";


