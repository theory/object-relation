#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use lib 't/lib';
use Kinetic::TestSetup store => { class => 'Kinetic::Store::DB::Pg' };
use Test::More tests => 14;

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
    id          INTEGER NOT NULL DEFAULT NEXTVAL('seq_kinetic'),
    guid        TEXT    NOT NULL,
    name        TEXT    NOT NULL,
    description TEXT,
    state       STATE   NOT NULL
);

CREATE UNIQUE INDEX udx_simple_guid ON simple (LOWER(guid));
CREATE INDEX idx_simple_name ON simple (LOWER(name));
CREATE INDEX idx_simple_state ON simple (state);

ALTER TABLE simple
 ADD CONSTRAINT pk_simple PRIMARY KEY (id);

}) =~ s/[ ]+/ /g;

ok my $sql = $sg->schema_for_class($simple), "Get schema for Simple class";
$sql =~ s/[ ]+/ /g;
is $sql, $testsql, "Check Simple class SQL";

##############################################################################
# Check the SQL generated for the One subclass.
my $one = $classes[1];

( $testsql = q{CREATE TABLE simple_one (
    id    INTEGER  NOT NULL,
    bool  BOOLEAN  NOT NULL DEFAULT '1'
);

ALTER TABLE simple_one
 ADD CONSTRAINT pk_simple_one PRIMARY KEY (id);

ALTER TABLE simple_one
 ADD CONSTRAINT pfk_simple_id FOREIGN KEY (id)
 REFERENCES simple(id) ON DELETE CASCADE;

CREATE VIEW one AS
  SELECT simple.id, simple.guid, simple.name, simple.description, simple.state, simple_one.bool
  FROM   simple, simple_one
  WHERE  simple.id = simple_one.id;

CREATE RULE insert_one AS
ON INSERT TO one DO INSTEAD (
  INSERT INTO simple (id, guid, name, description, state)
  VALUES (NEXTVAL('seq_kinetic'), NEW.guid, NEW.name, NEW.description, NEW.state);

  INSERT INTO simple_one (id, bool)
  VALUES (CURRVAL('seq_kinetic'), NEW.bool);
);

CREATE RULE update_one AS
ON UPDATE TO one DO INSTEAD (
  UPDATE simple
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state
  WHERE  id = OLD.id;

  UPDATE simple_one
  SET    bool = NEW.bool
  WHERE  id = OLD.id;
);

CREATE RULE delete_one AS
ON DELETE TO one DO INSTEAD (
    DELETE FROM simple_one
    WHERE  id = OLD.id;
);

}) =~ s/[ ]+/ /g;

ok $sql = $sg->schema_for_class($one), "Get schema for One class";
$sql =~ s/[ ]+/ /g;
is $sql, $testsql, "Check One class SQL";

##############################################################################
# Check the SQL generated for the Two subclass.
my $two = $classes[2];

( $testsql = q{CREATE TABLE simple_two (
    id      INTEGER  NOT NULL,
    one_id  INTEGER  NOT NULL
);

CREATE INDEX idx_simple_two_one_id ON simple_two (one_id);

ALTER TABLE simple_two
 ADD CONSTRAINT pk_simple_two PRIMARY KEY (id);

ALTER TABLE simple_two
 ADD CONSTRAINT pfk_simple_id FOREIGN KEY (id)
 REFERENCES simple(id) ON DELETE CASCADE;

ALTER TABLE simple_two
 ADD CONSTRAINT fk_simple_one_id FOREIGN KEY (one_id)
 REFERENCES simple_one(id) ON DELETE CASCADE;

CREATE VIEW two AS
  SELECT simple.id, simple.guid, simple.name, simple.description, simple.state, simple_two.one_id, one.guid AS "one.guid", one.name AS "one.name", one.description AS "one.description", one.state AS "one.state", one.bool AS "one.bool"
  FROM simple, simple_two, one
  WHERE simple.id = simple_two.id AND simple_two.one_id = one.id;

CREATE RULE insert_two AS
ON INSERT TO two DO INSTEAD (
  INSERT INTO simple (id, guid, name, description, state)
  VALUES (NEXTVAL('seq_kinetic'), NEW.guid, NEW.name, NEW.description, NEW.state);

  INSERT INTO simple_two (id, one_id)
  VALUES (CURRVAL('seq_kinetic'), NEW.one_id);
);

CREATE RULE update_two AS
ON UPDATE TO two DO INSTEAD (
  UPDATE simple
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state
  WHERE  id = OLD.id;

  UPDATE simple_two
  SET    one_id = NEW.one_id
  WHERE  id = OLD.id;
);

CREATE RULE delete_two AS
ON DELETE TO two DO INSTEAD (
    DELETE FROM simple_two
    WHERE  id = OLD.id;
);

}) =~ s/[ ]+/ /g;

ok $sql = $sg->schema_for_class($two), "Get schema for Two class";
$sql =~ s/[ ]+/ /g;
is $sql, $testsql, "Check Two class SQL";
