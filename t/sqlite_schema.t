#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use lib 't/lib';
use Kinetic::TestSetup store => { class => 'Kinetic::Store::DB::SQLite' };
use Test::More tests => 19;

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
    state       INTEGER NOT NULL
);

CREATE UNIQUE INDEX udx_simple_guid ON simple (guid);
CREATE INDEX idx_simple_name ON simple (name);
CREATE INDEX idx_simple_state ON simple (state);

}) =~ s/[ ]+/ /g;

ok my $sql = $sg->schema_for_class($simple), "Get schema for Simple class";
$sql =~ s/[ ]+/ /g;
is $sql, $testsql, "Check Simple class SQL";

##############################################################################
# Check the SQL generated for the One subclass.
my $one = $classes{'TestApp::Simple::One'};

( $testsql = q{CREATE TABLE simple_one (
    id    INTEGER  NOT NULL PRIMARY KEY REFERENCES simple(id),
    bool  INTEGER  NOT NULL DEFAULT '1'
);

CREATE VIEW one AS
  SELECT simple.id, simple.guid, simple.name, simple.description, simple.state, simple_one.bool
  FROM   simple, simple_one
  WHERE  simple.id = simple_one.id;

CREATE TRIGGER insert_one
INSTEAD OF INSERT ON one
FOR EACH ROW BEGIN
  INSERT INTO simple (guid, name, description, state)
  VALUES (NEW.guid, NEW.name, NEW.description, NEW.state);

  INSERT INTO simple_one (id, bool)
  VALUES (last_insert_rowid(), NEW.bool);
END;

CREATE TRIGGER update_one
INSTEAD OF UPDATE ON one
FOR EACH ROW BEGIN
  UPDATE simple
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state
  WHERE  id = OLD.id;

  UPDATE simple_one
  SET    bool = NEW.bool
  WHERE  id = OLD.id;
END;

CREATE TRIGGER delete_one
INSTEAD OF DELETE ON one
FOR EACH ROW BEGIN
    DELETE FROM simple_one
    WHERE  id = OLD.id;
END;

}) =~ s/[ ]+/ /g;

ok $sql = $sg->schema_for_class($one), "Get schema for One class";
$sql =~ s/[ ]+/ /g;
is $sql, $testsql, "Check One class SQL";

##############################################################################
# Check the SQL generated for the Two subclass.
my $two = $classes{'TestApp::Simple::Two'};

( $testsql = q{CREATE TABLE simple_two (
    id      INTEGER  NOT NULL PRIMARY KEY REFERENCES simple(id),
    one_id  INTEGER  NOT NULL REFERENCES simple_one(id)
);

CREATE INDEX idx_two_one_id ON simple_two (one_id);

CREATE VIEW two AS
  SELECT simple.id, simple.guid, simple.name, simple.description, simple.state, simple_two.one_id, one.guid AS "one.guid", one.name AS "one.name", one.description AS "one.description", one.state AS "one.state", one.bool AS "one.bool"
  FROM simple, simple_two, one
  WHERE simple.id = simple_two.id AND simple_two.one_id = one.id;

CREATE TRIGGER insert_two
INSTEAD OF INSERT ON two
FOR EACH ROW BEGIN
  INSERT INTO simple (guid, name, description, state)
  VALUES (NEW.guid, NEW.name, NEW.description, NEW.state);

  INSERT INTO simple_two (id, one_id)
  VALUES (last_insert_rowid(), NEW.one_id);
END;

CREATE TRIGGER update_two
INSTEAD OF UPDATE ON two
FOR EACH ROW BEGIN
  UPDATE simple
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state
  WHERE  id = OLD.id;

  UPDATE simple_two
  SET    one_id = NEW.one_id
  WHERE  id = OLD.id;
END;

CREATE TRIGGER delete_two
INSTEAD OF DELETE ON two
FOR EACH ROW BEGIN
    DELETE FROM simple_two
    WHERE  id = OLD.id;
END;

}) =~ s/[ ]+/ /g;

ok $sql = $sg->schema_for_class($two), "Get schema for Two class";
$sql =~ s/[ ]+/ /g;
is $sql, $testsql, "Check Two class SQL";

##############################################################################
# Check the SQL generated for the composed class.
my $composed = $classes{'TestApp::Composed'};

( $testsql = q{CREATE TABLE _composed (
    id          INTEGER NOT NULL PRIMARY KEY,
    guid        TEXT    NOT NULL,
    name        TEXT    NOT NULL,
    description TEXT,
    state       INTEGER NOT NULL,
    one_id      INTEGER  NOT NULL REFERENCES simple_one(id)
);

CREATE UNIQUE INDEX udx_composed_guid ON _composed (guid);
CREATE INDEX idx_composed_name ON _composed (name);
CREATE INDEX idx_composed_state ON _composed (state);
CREATE INDEX idx_composed_one_id ON _composed (one_id);

CREATE VIEW composed AS
  SELECT _composed.id, _composed.guid, _composed.name, _composed.description, _composed.state, _composed.one_id, one.guid AS "one.guid", one.name AS "one.name", one.description AS "one.description", one.state AS "one.state", one.bool AS "one.bool"
  FROM _composed, one
  WHERE _composed.one_id = one.id;

CREATE TRIGGER insert_composed
INSTEAD OF INSERT ON composed
FOR EACH ROW BEGIN
  INSERT INTO _composed (guid, name, description, state, one_id)
  VALUES (NEW.guid, NEW.name, NEW.description, NEW.state, NEW.one_id);
END;

CREATE TRIGGER update_composed
INSTEAD OF UPDATE ON composed
FOR EACH ROW BEGIN
  UPDATE _composed
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state, one_id = NEW.one_id
  WHERE  id = OLD.id;
END;

CREATE TRIGGER delete_composed
INSTEAD OF DELETE ON composed
FOR EACH ROW BEGIN
    DELETE FROM _composed
    WHERE  id = OLD.id;
END;

}) =~ s/[ ]+/ /g;

ok $sql = $sg->schema_for_class($composed), "Get schema for Composed class";
$sql =~ s/[ ]+/ /g;
is $sql, $testsql, "Check Composed class SQL";

__END__
This stuff works!

CREATE TABLE simple (
    id          INTEGER NOT NULL PRIMARY KEY,
    guid        TEXT    NOT NULL,
    name        TEXT    NOT NULL,
    description TEXT,
    state       INTEGER   NOT NULL
);

CREATE UNIQUE INDEX udx_simple_guid ON simple (guid);
CREATE INDEX idx_simple_name ON simple (name);
CREATE INDEX idx_simple_state ON simple (state);



CREATE TABLE simple_one (
    id    INTEGER  NOT NULL PRIMARY KEY REFERENCES simple(id),
    bool  INTEGER  NOT NULL DEFAULT '1'
);

CREATE VIEW one AS
  SELECT simple.id, simple.guid, simple.name, simple.description, simple.state, simple_one.bool
  FROM   simple, simple_one
  WHERE  simple.id = simple_one.id;

CREATE TRIGGER insert_one
INSTEAD OF INSERT ON one
FOR EACH ROW BEGIN
  INSERT INTO simple (guid, name, description, state)
  VALUES (NEW.guid, NEW.name, NEW.description, NEW.state);

  INSERT INTO simple_one (id, bool)
  VALUES (last_insert_rowid(), NEW.bool);
END;

CREATE TRIGGER update_one
INSTEAD OF UPDATE ON one
FOR EACH ROW BEGIN
  UPDATE simple
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state
  WHERE  id = OLD.id;

  UPDATE simple_one
  SET    bool = NEW.bool
  WHERE  id = OLD.id;
END;

CREATE TRIGGER delete_one 
INSTEAD OF DELETE ON one
FOR EACH ROW BEGIN
    DELETE FROM simple_one
    WHERE  id = OLD.id;
END;



CREATE TABLE simple_two (
    id      INTEGER  NOT NULL PRIMARY KEY REFERENCES simple(id),
    one_id  INTEGER  NOT NULL REFERENCES simple_one(id)
);

CREATE INDEX idx_two_one_id ON simple_two (one_id);

CREATE VIEW two AS
  SELECT simple.id, simple.guid, simple.name, simple.description, simple.state, simple_two.one_id, one.guid AS "one.guid", one.name AS "one.name", one.description AS "one.description", one.state AS "one.state", one.bool AS "one.bool"
  FROM simple, simple_two, one
  WHERE simple.id = simple_two.id AND simple_two.one_id = one.id;

CREATE TRIGGER insert_two
INSTEAD OF INSERT ON two
FOR EACH ROW BEGIN
  INSERT INTO simple (guid, name, description, state)
  VALUES (NEW.guid, NEW.name, NEW.description, NEW.state);

  INSERT INTO simple_two (id, one_id)
  VALUES (last_insert_rowid(), NEW.one_id);
END;

CREATE TRIGGER update_two
INSTEAD OF UPDATE ON two
FOR EACH ROW BEGIN
  UPDATE simple
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state
  WHERE  id = OLD.id;

  UPDATE simple_two
  SET    one_id = NEW.one_id
  WHERE  id = OLD.id;
END;

CREATE TRIGGER delete_two
INSTEAD OF DELETE ON two
FOR EACH ROW BEGIN
    DELETE FROM simple_two
    WHERE  id = OLD.id;
END;

