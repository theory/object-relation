#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use lib 't/lib';
use Kinetic::TestSetup store => { class => 'Kinetic::Store::DB::SQLite' };
use Test::More tests => 66;
use Test::Differences;

BEGIN { use_ok 'Kinetic::Build::Schema' };

ok my $sg = Kinetic::Build::Schema->new, 'Get new Schema';
isa_ok $sg, 'Kinetic::Build::Schema';
isa_ok $sg, 'Kinetic::Build::Schema::DB';
isa_ok $sg, 'Kinetic::Build::Schema::DB::SQLite';

ok $sg->load_classes('t/lib'), "Load classes";
for my $class ($sg->classes) {
    ok $class->is_a('Kinetic'), "Class is a Kinetic";
}

##############################################################################
# Grab the simple class.
ok my $simple = Kinetic::Meta->for_key('simple'), "Get simple class";
is $simple->key, 'simple', "... Simple class has key 'simple'";
is $simple->table, '_simple', "... Simple class has table '_simple'";

# Check that the CREATE TABLE statement is correct.
my $table = q{CREATE TABLE _simple (
    id INTEGER NOT NULL PRIMARY KEY,
    guid TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    state INTEGER NOT NULL DEFAULT 1
);
};
eq_or_diff $sg->table_for_class($simple), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
my $indexes = q{CREATE UNIQUE INDEX idx_simple_guid ON _simple (guid);
CREATE INDEX idx_simple_name ON _simple (name);
CREATE INDEX idx_simple_state ON _simple (state);
};
eq_or_diff $sg->indexes_for_class($simple), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the TRIGGER statements are correct.
my $constraints = q{CREATE TRIGGER cki_simple_state
BEFORE INSERT ON _simple
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN NEW.state NOT BETWEEN -1 AND 2
    THEN RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
  END;
END;

CREATE TRIGGER cku_simple_state
BEFORE UPDATE OF state ON _simple
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN NEW.state NOT BETWEEN -1 AND 2
    THEN RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
  END;
END;
};

eq_or_diff $sg->constraints_for_class($simple), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
my $view = q{CREATE VIEW simple AS
  SELECT _simple.id, _simple.guid, _simple.name, _simple.description, _simple.state
  FROM   _simple;
};
eq_or_diff $sg->view_for_class($simple), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
my $insert = q{CREATE TRIGGER insert_simple
INSTEAD OF INSERT ON simple
FOR EACH ROW BEGIN
  INSERT INTO _simple (guid, name, description, state)
  VALUES (NEW.guid, NEW.name, NEW.description, NEW.state);
END;
};
eq_or_diff $sg->insert_for_class($simple), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
my $update = q{CREATE TRIGGER update_simple
INSTEAD OF UPDATE ON simple
FOR EACH ROW BEGIN
  UPDATE _simple
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->update_for_class($simple), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
my $delete = q{CREATE TRIGGER delete_simple
INSTEAD OF DELETE ON simple
FOR EACH ROW BEGIN
  DELETE FROM _simple
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->delete_for_class($simple), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff $sg->schema_for_class($simple),
  join("\n", $table, $indexes, $constraints, $view, $insert, $update, $delete),
  "... Schema class generates complete schema";

##############################################################################
# Grab the one class.
ok my $one = Kinetic::Meta->for_key('one'), "Get one class";
is $one->key, 'one', "... One class has key 'one'";
is $one->table, 'simple_one', "... One class has table 'simple_one'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE simple_one (
    id INTEGER NOT NULL PRIMARY KEY REFERENCES _simple(id) ON DELETE CASCADE,
    bool SMALLINT NOT NULL DEFAULT 1
);
};

eq_or_diff $sg->table_for_class($one), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
is $sg->indexes_for_class($one), undef,
  "... Schema class generates CREATE INDEX statements";

# Check that the boolean and foreign key triggers are in place.
$constraints = q{CREATE TRIGGER cki_one_bool
BEFORE INSERT ON simple_one
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN NEW.bool NOT IN (1, 0)
    THEN RAISE(ABORT, 'value for domain boolean violates check constraint "ck_boolean"')
  END;
END;

CREATE TRIGGER cku_one_bool
BEFORE UPDATE OF bool ON simple_one
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN NEW.bool NOT IN (1, 0)
    THEN RAISE(ABORT, 'value for domain boolean violates check constraint "ck_boolean"')
  END;
END;

CREATE TRIGGER pfki_one_id
BEFORE INSERT ON simple_one
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT id FROM _simple WHERE id = NEW.id) IS NULL
    THEN RAISE(ABORT, 'insert on table "simple_one" violates foreign key constraint "pfk_one_id"')
  END;
END;

CREATE TRIGGER pfku_one_id
BEFORE UPDATE ON simple_one
FOR EACH ROW BEGIN
  SELECT CASE WHEN (SELECT id FROM _simple WHERE id = NEW.id) IS NULL
    THEN RAISE(ABORT, 'update on table "simple_one" violates foreign key constraint "pfk_one_id"')
  END;
END;

CREATE TRIGGER pfkd_one_id
BEFORE DELETE ON _simple
FOR EACH ROW BEGIN
  DELETE from simple_one WHERE id = OLD.id;
END;
};
eq_or_diff $sg->constraints_for_class($one), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW one AS
  SELECT simple.id, simple.guid, simple.name, simple.description, simple.state, simple_one.bool
  FROM   simple, simple_one
  WHERE  simple.id = simple_one.id;
};
eq_or_diff $sg->view_for_class($one), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_one
INSTEAD OF INSERT ON one
FOR EACH ROW BEGIN
  INSERT INTO _simple (guid, name, description, state)
  VALUES (NEW.guid, NEW.name, NEW.description, NEW.state);

  INSERT INTO simple_one (id, bool)
  VALUES (last_insert_rowid(), NEW.bool);
END;
};
eq_or_diff $sg->insert_for_class($one), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_one
INSTEAD OF UPDATE ON one
FOR EACH ROW BEGIN
  UPDATE _simple
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state
  WHERE  id = OLD.id;

  UPDATE simple_one
  SET    bool = NEW.bool
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->update_for_class($one), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE TRIGGER delete_one
INSTEAD OF DELETE ON one
FOR EACH ROW BEGIN
  DELETE FROM simple_one
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->delete_for_class($one), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff $sg->schema_for_class($one),
  join("\n", $table, $constraints, $view, $insert, $update, $delete),
  "... Schema class generates complete schema";

##############################################################################
# Grab the two class.
ok my $two = Kinetic::Meta->for_key('two'), "Get two class";
is $two->key, 'two', "... Two class has key 'two'";
is $two->table, 'simple_two', "... Two class has table 'simple_two'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE simple_two (
    id INTEGER NOT NULL PRIMARY KEY REFERENCES _simple(id) ON DELETE CASCADE,
    one_id INTEGER NOT NULL REFERENCES simple_one(id) ON DELETE CASCADE
);
};
eq_or_diff $sg->table_for_class($two), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = qq{CREATE INDEX idx_two_one_id ON simple_two (one_id);\n};

eq_or_diff $sg->indexes_for_class($two), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the constraint and foreign key triggers are correct.
$constraints = q{CREATE TRIGGER pfki_two_id
BEFORE INSERT ON simple_two
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT id FROM _simple WHERE id = NEW.id) IS NULL
    THEN RAISE(ABORT, 'insert on table "simple_two" violates foreign key constraint "pfk_two_id"')
  END;
END;

CREATE TRIGGER pfku_two_id
BEFORE UPDATE ON simple_two
FOR EACH ROW BEGIN
  SELECT CASE WHEN (SELECT id FROM _simple WHERE id = NEW.id) IS NULL
    THEN RAISE(ABORT, 'update on table "simple_two" violates foreign key constraint "pfk_two_id"')
  END;
END;

CREATE TRIGGER pfkd_two_id
BEFORE DELETE ON _simple
FOR EACH ROW BEGIN
  DELETE from simple_two WHERE id = OLD.id;
END;

CREATE TRIGGER fki_two_one_id
BEFORE INSERT ON simple_two
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT id FROM simple_one WHERE id = NEW.one_id) IS NULL
    THEN RAISE(ABORT, 'insert on table "simple_two" violates foreign key constraint "fk_two_one_id"')
  END;
END;

CREATE TRIGGER fku_two_one_id
BEFORE UPDATE ON simple_two
FOR EACH ROW BEGIN
  SELECT CASE WHEN (SELECT id FROM simple_one WHERE id = NEW.one_id) IS NULL
    THEN RAISE(ABORT, 'update on table "simple_two" violates foreign key constraint "fk_two_one_id"')
  END;
END;

CREATE TRIGGER fkd_two_one_id
BEFORE DELETE ON simple_one
FOR EACH ROW BEGIN
  DELETE from simple_two WHERE one_id = OLD.id;
END;
};
eq_or_diff $sg->constraints_for_class($two), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW two AS
  SELECT simple.id, simple.guid, simple.name, simple.description, simple.state, simple_two.one_id, one.guid AS "one.guid", one.name AS "one.name", one.description AS "one.description", one.state AS "one.state", one.bool AS "one.bool"
  FROM   simple, simple_two, one
  WHERE  simple.id = simple_two.id AND simple_two.one_id = one.id;
};
eq_or_diff $sg->view_for_class($two), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_two
INSTEAD OF INSERT ON two
FOR EACH ROW BEGIN
  INSERT INTO _simple (guid, name, description, state)
  VALUES (NEW.guid, NEW.name, NEW.description, NEW.state);

  INSERT INTO simple_two (id, one_id)
  VALUES (last_insert_rowid(), NEW.one_id);
END;
};
eq_or_diff $sg->insert_for_class($two), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_two
INSTEAD OF UPDATE ON two
FOR EACH ROW BEGIN
  UPDATE _simple
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state
  WHERE  id = OLD.id;

  UPDATE simple_two
  SET    one_id = NEW.one_id
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->update_for_class($two), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE TRIGGER delete_two
INSTEAD OF DELETE ON two
FOR EACH ROW BEGIN
  DELETE FROM simple_two
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->delete_for_class($two), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff $sg->schema_for_class($two),
  join("\n", $table, $indexes, $constraints, $view, $insert, $update, $delete),
  "... Schema class generates complete schema";

##############################################################################
# Grab the composed class.
ok my $composed = Kinetic::Meta->for_key('composed'), "Get composed class";
is $composed->key, 'composed', "... Composed class has key 'composed'";
is $composed->table, '_composed', "... Composed class has table '_composed'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _composed (
    id INTEGER NOT NULL PRIMARY KEY,
    guid TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    state INTEGER NOT NULL DEFAULT 1,
    one_id INTEGER NOT NULL REFERENCES simple_one(id) ON DELETE CASCADE
);
};
eq_or_diff $sg->table_for_class($composed), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_composed_guid ON _composed (guid);
CREATE INDEX idx_composed_name ON _composed (name);
CREATE INDEX idx_composed_state ON _composed (state);
CREATE INDEX idx_composed_one_id ON _composed (one_id);
};

eq_or_diff $sg->indexes_for_class($composed), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the constraint and foreign key triggers are correct.
$constraints = q{CREATE TRIGGER cki_composed_state
BEFORE INSERT ON _composed
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN NEW.state NOT BETWEEN -1 AND 2
    THEN RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
  END;
END;

CREATE TRIGGER cku_composed_state
BEFORE UPDATE OF state ON _composed
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN NEW.state NOT BETWEEN -1 AND 2
    THEN RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
  END;
END;

CREATE TRIGGER ck_composed_one_id_once
BEFORE UPDATE ON _composed
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN OLD.one_id IS NOT NULL AND (OLD.one_id <> NEW.one_id OR NEW.one_id IS NULL)
    THEN RAISE(ABORT, 'value of "one_id" cannot be changed')
  END;
END;

CREATE TRIGGER fki_composed_one_id
BEFORE INSERT ON _composed
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT id FROM simple_one WHERE id = NEW.one_id) IS NULL
    THEN RAISE(ABORT, 'insert on table "_composed" violates foreign key constraint "fk_composed_one_id"')
  END;
END;

CREATE TRIGGER fku_composed_one_id
BEFORE UPDATE ON _composed
FOR EACH ROW BEGIN
  SELECT CASE WHEN (SELECT id FROM simple_one WHERE id = NEW.one_id) IS NULL
    THEN RAISE(ABORT, 'update on table "_composed" violates foreign key constraint "fk_composed_one_id"')
  END;
END;

CREATE TRIGGER fkd_composed_one_id
BEFORE DELETE ON simple_one
FOR EACH ROW BEGIN
  DELETE from _composed WHERE one_id = OLD.id;
END;
};
eq_or_diff $sg->constraints_for_class($composed), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW composed AS
  SELECT _composed.id, _composed.guid, _composed.name, _composed.description, _composed.state, _composed.one_id, one.guid AS "one.guid", one.name AS "one.name", one.description AS "one.description", one.state AS "one.state", one.bool AS "one.bool"
  FROM   _composed, one
  WHERE  _composed.one_id = one.id;
};
eq_or_diff $sg->view_for_class($composed), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_composed
INSTEAD OF INSERT ON composed
FOR EACH ROW BEGIN
  INSERT INTO _composed (guid, name, description, state, one_id)
  VALUES (NEW.guid, NEW.name, NEW.description, NEW.state, NEW.one_id);
END;
};
eq_or_diff $sg->insert_for_class($composed), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_composed
INSTEAD OF UPDATE ON composed
FOR EACH ROW BEGIN
  UPDATE _composed
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state, one_id = NEW.one_id
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->update_for_class($composed), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE TRIGGER delete_composed
INSTEAD OF DELETE ON composed
FOR EACH ROW BEGIN
  DELETE FROM _composed
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->delete_for_class($composed), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff $sg->schema_for_class($composed),
  join("\n", $table, $indexes, $constraints, $view, $insert, $update, $delete),
  "... Schema class generates complete schema";

##############################################################################
# Grab the comp_comp class.
ok my $comp_comp = Kinetic::Meta->for_key('comp_comp'), "Get comp_comp class";
is $comp_comp->key, 'comp_comp', "... CompComp class has key 'comp_comp'";
is $comp_comp->table, '_comp_comp', "... CompComp class has table 'comp_comp'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _comp_comp (
    id INTEGER NOT NULL PRIMARY KEY,
    guid TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    state INTEGER NOT NULL DEFAULT 1,
    composed_id INTEGER NOT NULL REFERENCES _composed(id) ON DELETE RESTRICT
);
};
eq_or_diff $sg->table_for_class($comp_comp), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_comp_comp_guid ON _comp_comp (guid);
CREATE INDEX idx_comp_comp_name ON _comp_comp (name);
CREATE INDEX idx_comp_comp_state ON _comp_comp (state);
CREATE INDEX idx_comp_comp_composed_id ON _comp_comp (composed_id);
};

eq_or_diff $sg->indexes_for_class($comp_comp), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the constraint and foreign key triggers are correct.
$constraints = q{CREATE TRIGGER cki_comp_comp_state
BEFORE INSERT ON _comp_comp
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN NEW.state NOT BETWEEN -1 AND 2
    THEN RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
  END;
END;

CREATE TRIGGER cku_comp_comp_state
BEFORE UPDATE OF state ON _comp_comp
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN NEW.state NOT BETWEEN -1 AND 2
    THEN RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
  END;
END;

CREATE TRIGGER fki_comp_comp_composed_id
BEFORE INSERT ON _comp_comp
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT id FROM _composed WHERE id = NEW.composed_id) IS NULL
    THEN RAISE(ABORT, 'insert on table "_comp_comp" violates foreign key constraint "fk_comp_comp_composed_id"')
  END;
END;

CREATE TRIGGER fku_comp_comp_composed_id
BEFORE UPDATE ON _comp_comp
FOR EACH ROW BEGIN
  SELECT CASE WHEN (SELECT id FROM _composed WHERE id = NEW.composed_id) IS NULL
    THEN RAISE(ABORT, 'update on table "_comp_comp" violates foreign key constraint "fk_comp_comp_composed_id"')
  END;
END;

CREATE TRIGGER fkd_comp_comp_composed_id
BEFORE DELETE ON _composed
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT composed_id FROM _comp_comp WHERE composed_id = OLD.id) IS NOT NULL
    THEN RAISE(ABORT, 'delete on table "_composed" violates foreign key constraint "fk_comp_comp_composed_id"')
  END;
END;
};

eq_or_diff $sg->constraints_for_class($comp_comp), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW comp_comp AS
  SELECT _comp_comp.id, _comp_comp.guid, _comp_comp.name, _comp_comp.description, _comp_comp.state, _comp_comp.composed_id, composed.guid AS "composed.guid", composed.name AS "composed.name", composed.description AS "composed.description", composed.state AS "composed.state", composed.one_id AS "composed.one_id", composed."one.guid" AS "composed.one.guid", composed."one.name" AS "composed.one.name", composed."one.description" AS "composed.one.description", composed."one.state" AS "composed.one.state", composed."one.bool" AS "composed.one.bool"
  FROM   _comp_comp, composed
  WHERE  _comp_comp.composed_id = composed.id;
};
eq_or_diff $sg->view_for_class($comp_comp), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_comp_comp
INSTEAD OF INSERT ON comp_comp
FOR EACH ROW BEGIN
  INSERT INTO _comp_comp (guid, name, description, state, composed_id)
  VALUES (NEW.guid, NEW.name, NEW.description, NEW.state, NEW.composed_id);
END;
};
eq_or_diff $sg->insert_for_class($comp_comp), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_comp_comp
INSTEAD OF UPDATE ON comp_comp
FOR EACH ROW BEGIN
  UPDATE _comp_comp
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state, composed_id = NEW.composed_id
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->update_for_class($comp_comp), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE TRIGGER delete_comp_comp
INSTEAD OF DELETE ON comp_comp
FOR EACH ROW BEGIN
  DELETE FROM _comp_comp
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->delete_for_class($comp_comp), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff $sg->schema_for_class($comp_comp),
  join("\n", $table, $indexes, $constraints, $view, $insert, $update, $delete),
  "... Schema class generates complete schema";

