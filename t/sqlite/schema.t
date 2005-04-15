#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Kinetic::Build::Test store => { class => 'Kinetic::Store::DB::SQLite' };
use Test::More 'no_plan';
#use Test::More tests => 80;
use Test::Differences;

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
is_deeply [ map { $_->key } $sg->classes ],
  [qw(simple one two relation composed comp_comp)],
  "classes() returns classes in their proper dependency order";

for my $class ($sg->classes) {
    ok $class->is_a('Kinetic'), "Class is a Kinetic";
}

##############################################################################
# Check Setup SQL.
is $sg->setup_code, undef, "SQLite setup SQL is undefined";

##############################################################################
# Grab the simple class.
ok my $simple = Kinetic::Meta->for_key('simple'), "Get simple class";
is $simple->key, 'simple', "... Simple class has key 'simple'";
is $simple->table, '_simple', "... Simple class has table '_simple'";

# Check that the CREATE TABLE statement is correct.
my $table = q{CREATE TABLE _simple (
    id INTEGER NOT NULL PRIMARY KEY,
    guid TEXT NOT NULL,
    state INTEGER NOT NULL DEFAULT 1,
    name TEXT COLLATE nocase NOT NULL,
    description TEXT COLLATE nocase
);
};
eq_or_diff $sg->table_for_class($simple), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
my $indexes = q{CREATE UNIQUE INDEX idx_simple_guid ON _simple (guid);
CREATE INDEX idx_simple_state ON _simple (state);
CREATE INDEX idx_simple_name ON _simple (name);
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

CREATE TRIGGER ck_simple_guid_once
BEFORE UPDATE ON _simple
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN OLD.guid <> NEW.guid OR NEW.guid IS NULL
    THEN RAISE(ABORT, 'value of "guid" cannot be changed')
  END;
END;
};

eq_or_diff $sg->constraints_for_class($simple), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
my $view = q{CREATE VIEW simple AS
  SELECT _simple.id AS id, _simple.guid AS guid, _simple.state AS state, _simple.name AS name, _simple.description AS description
  FROM   _simple;
};
eq_or_diff $sg->view_for_class($simple), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
my $insert = q{CREATE TRIGGER insert_simple
INSTEAD OF INSERT ON simple
FOR EACH ROW BEGIN
  INSERT INTO _simple (guid, state, name, description)
  VALUES (NEW.guid, NEW.state, NEW.name, NEW.description);
END;
};
eq_or_diff $sg->insert_for_class($simple), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
my $update = q{CREATE TRIGGER update_simple
INSTEAD OF UPDATE ON simple
FOR EACH ROW BEGIN
  UPDATE _simple
  SET    guid = NEW.guid, state = NEW.state, name = NEW.name, description = NEW.description
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
eq_or_diff join("\n", $sg->schema_for_class($simple)),
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

CREATE TRIGGER pfki_simple_one_id
BEFORE INSERT ON simple_one
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT id FROM _simple WHERE id = NEW.id) IS NULL
    THEN RAISE(ABORT, 'insert on table "simple_one" violates foreign key constraint "pfk_simple_one_id"')
  END;
END;

CREATE TRIGGER pfku_simple_one_id
BEFORE UPDATE ON simple_one
FOR EACH ROW BEGIN
  SELECT CASE WHEN (SELECT id FROM _simple WHERE id = NEW.id) IS NULL
    THEN RAISE(ABORT, 'update on table "simple_one" violates foreign key constraint "pfk_simple_one_id"')
  END;
END;

CREATE TRIGGER pfkd_simple_one_id
BEFORE DELETE ON _simple
FOR EACH ROW BEGIN
  DELETE from simple_one WHERE id = OLD.id;
END;
};
eq_or_diff $sg->constraints_for_class($one), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW one AS
  SELECT simple.id AS id, simple.guid AS guid, simple.state AS state, simple.name AS name, simple.description AS description, simple_one.bool AS bool
  FROM   simple, simple_one
  WHERE  simple.id = simple_one.id;
};
eq_or_diff $sg->view_for_class($one), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_one
INSTEAD OF INSERT ON one
FOR EACH ROW BEGIN
  INSERT INTO _simple (guid, state, name, description)
  VALUES (NEW.guid, NEW.state, NEW.name, NEW.description);

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
  SET    guid = NEW.guid, state = NEW.state, name = NEW.name, description = NEW.description
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
eq_or_diff join("\n", $sg->schema_for_class($one)),
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
    one_id INTEGER NOT NULL REFERENCES simple_one(id) ON DELETE RESTRICT,
    age INTEGER,
    date TEXT NOT NULL
);
};

eq_or_diff $sg->table_for_class($two), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = qq{CREATE INDEX idx_two_one_id ON simple_two (one_id);\n};

eq_or_diff $sg->indexes_for_class($two), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the constraint and foreign key triggers are correct.
$constraints = q{CREATE TRIGGER pfki_simple_two_id
BEFORE INSERT ON simple_two
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT id FROM _simple WHERE id = NEW.id) IS NULL
    THEN RAISE(ABORT, 'insert on table "simple_two" violates foreign key constraint "pfk_simple_two_id"')
  END;
END;

CREATE TRIGGER pfku_simple_two_id
BEFORE UPDATE ON simple_two
FOR EACH ROW BEGIN
  SELECT CASE WHEN (SELECT id FROM _simple WHERE id = NEW.id) IS NULL
    THEN RAISE(ABORT, 'update on table "simple_two" violates foreign key constraint "pfk_simple_two_id"')
  END;
END;

CREATE TRIGGER pfkd_simple_two_id
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
  SELECT CASE
    WHEN (SELECT one_id FROM simple_two WHERE one_id = OLD.id) IS NOT NULL
    THEN RAISE(ABORT, 'delete on table "simple_one" violates foreign key constraint "fk_two_one_id"')
  END;
END;
};
eq_or_diff $sg->constraints_for_class($two), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW two AS
  SELECT simple.id AS id, simple.guid AS guid, simple.state AS state, simple.name AS name, simple.description AS description, simple_two.one_id AS one__id, one.guid AS one__guid, one.state AS one__state, one.name AS one__name, one.description AS one__description, one.bool AS one__bool, simple_two.age AS age, simple_two.date AS date
  FROM   simple, simple_two, one
  WHERE  simple.id = simple_two.id AND simple_two.one_id = one.id;
};
eq_or_diff $sg->view_for_class($two), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_two
INSTEAD OF INSERT ON two
FOR EACH ROW BEGIN
  INSERT INTO _simple (guid, state, name, description)
  VALUES (NEW.guid, NEW.state, NEW.name, NEW.description);

  INSERT INTO simple_two (id, one_id, age, date)
  VALUES (last_insert_rowid(), NEW.one__id, NEW.age, NEW.date);
END;
};
eq_or_diff $sg->insert_for_class($two), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_two
INSTEAD OF UPDATE ON two
FOR EACH ROW BEGIN
  UPDATE _simple
  SET    guid = NEW.guid, state = NEW.state, name = NEW.name, description = NEW.description
  WHERE  id = OLD.id;

  UPDATE simple_two
  SET    one_id = NEW.one__id, age = NEW.age, date = NEW.date
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
eq_or_diff join("\n", $sg->schema_for_class($two)),
  join("\n", $table, $indexes, $constraints, $view, $insert, $update, $delete),
  "... Schema class generates complete schema";

##############################################################################
# Grab the relation class.
ok my $relation = Kinetic::Meta->for_key('relation'), "Get relation class";
is $relation->key, 'relation', "... Relation class has key 'relation'";
is $relation->table, '_relation', "... Relation class has table '_relation'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _relation (
    id INTEGER NOT NULL PRIMARY KEY,
    guid TEXT NOT NULL,
    state INTEGER NOT NULL DEFAULT 1,
    one_id INTEGER NOT NULL REFERENCES simple_one(id) ON DELETE RESTRICT,
    simple_id INTEGER NOT NULL REFERENCES _simple(id) ON DELETE RESTRICT
);
};
eq_or_diff $sg->table_for_class($relation), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_relation_guid ON _relation (guid);
CREATE INDEX idx_relation_state ON _relation (state);
CREATE INDEX idx_relation_one_id ON _relation (one_id);
CREATE INDEX idx_relation_simple_id ON _relation (simple_id);
};

eq_or_diff $sg->indexes_for_class($relation), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the constraint and foreign key triggers are correct.
$constraints = q{CREATE TRIGGER cki_relation_state
BEFORE INSERT ON _relation
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN NEW.state NOT BETWEEN -1 AND 2
    THEN RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
  END;
END;

CREATE TRIGGER cku_relation_state
BEFORE UPDATE OF state ON _relation
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN NEW.state NOT BETWEEN -1 AND 2
    THEN RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
  END;
END;

CREATE TRIGGER ck_relation_guid_once
BEFORE UPDATE ON _relation
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN OLD.guid <> NEW.guid OR NEW.guid IS NULL
    THEN RAISE(ABORT, 'value of "guid" cannot be changed')
  END;
END;

CREATE TRIGGER fki_relation_one_id
BEFORE INSERT ON _relation
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT id FROM simple_one WHERE id = NEW.one_id) IS NULL
    THEN RAISE(ABORT, 'insert on table "_relation" violates foreign key constraint "fk_relation_one_id"')
  END;
END;

CREATE TRIGGER fku_relation_one_id
BEFORE UPDATE ON _relation
FOR EACH ROW BEGIN
  SELECT CASE WHEN (SELECT id FROM simple_one WHERE id = NEW.one_id) IS NULL
    THEN RAISE(ABORT, 'update on table "_relation" violates foreign key constraint "fk_relation_one_id"')
  END;
END;

CREATE TRIGGER fkd_relation_one_id
BEFORE DELETE ON simple_one
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT one_id FROM _relation WHERE one_id = OLD.id) IS NOT NULL
    THEN RAISE(ABORT, 'delete on table "simple_one" violates foreign key constraint "fk_relation_one_id"')
  END;
END;

CREATE TRIGGER fki_relation_simple_id
BEFORE INSERT ON _relation
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT id FROM _simple WHERE id = NEW.simple_id) IS NULL
    THEN RAISE(ABORT, 'insert on table "_relation" violates foreign key constraint "fk_relation_simple_id"')
  END;
END;

CREATE TRIGGER fku_relation_simple_id
BEFORE UPDATE ON _relation
FOR EACH ROW BEGIN
  SELECT CASE WHEN (SELECT id FROM _simple WHERE id = NEW.simple_id) IS NULL
    THEN RAISE(ABORT, 'update on table "_relation" violates foreign key constraint "fk_relation_simple_id"')
  END;
END;

CREATE TRIGGER fkd_relation_simple_id
BEFORE DELETE ON _simple
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN (SELECT simple_id FROM _relation WHERE simple_id = OLD.id) IS NOT NULL
    THEN RAISE(ABORT, 'delete on table "_simple" violates foreign key constraint "fk_relation_simple_id"')
  END;
END;
};
eq_or_diff $sg->constraints_for_class($relation), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW relation AS
  SELECT _relation.id AS id, _relation.guid AS guid, _relation.state AS state, _relation.one_id AS one__id, one.guid AS one__guid, one.state AS one__state, one.name AS one__name, one.description AS one__description, one.bool AS one__bool, _relation.simple_id AS simple__id, simple.guid AS simple__guid, simple.state AS simple__state, simple.name AS simple__name, simple.description AS simple__description
  FROM   _relation, one, simple
  WHERE  _relation.one_id = one.id AND _relation.simple_id = simple.id;
};
eq_or_diff $sg->view_for_class($relation), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_relation
INSTEAD OF INSERT ON relation
FOR EACH ROW BEGIN
  INSERT INTO _relation (guid, state, one_id, simple_id)
  VALUES (NEW.guid, NEW.state, NEW.one__id, NEW.simple__id);
END;
};
eq_or_diff $sg->insert_for_class($relation), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_relation
INSTEAD OF UPDATE ON relation
FOR EACH ROW BEGIN
  UPDATE _relation
  SET    guid = NEW.guid, state = NEW.state, one_id = NEW.one__id, simple_id = NEW.simple__id
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->update_for_class($relation), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE TRIGGER delete_relation
INSTEAD OF DELETE ON relation
FOR EACH ROW BEGIN
  DELETE FROM _relation
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->delete_for_class($relation), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff join("\n", $sg->schema_for_class($relation)),
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
    state INTEGER NOT NULL DEFAULT 1,
    one_id INTEGER REFERENCES simple_one(id) ON DELETE RESTRICT
);
};
eq_or_diff $sg->table_for_class($composed), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_composed_guid ON _composed (guid);
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

CREATE TRIGGER ck_composed_guid_once
BEFORE UPDATE ON _composed
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN OLD.guid <> NEW.guid OR NEW.guid IS NULL
    THEN RAISE(ABORT, 'value of "guid" cannot be changed')
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
  SELECT CASE
    WHEN (SELECT one_id FROM _composed WHERE one_id = OLD.id) IS NOT NULL
    THEN RAISE(ABORT, 'delete on table "simple_one" violates foreign key constraint "fk_composed_one_id"')
  END;
END;
};
eq_or_diff $sg->constraints_for_class($composed), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW composed AS
  SELECT _composed.id AS id, _composed.guid AS guid, _composed.state AS state, _composed.one_id AS one__id, one.guid AS one__guid, one.state AS one__state, one.name AS one__name, one.description AS one__description, one.bool AS one__bool
  FROM   _composed LEFT JOIN one ON _composed.one_id = one.id;
};
eq_or_diff $sg->view_for_class($composed), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_composed
INSTEAD OF INSERT ON composed
FOR EACH ROW BEGIN
  INSERT INTO _composed (guid, state, one_id)
  VALUES (NEW.guid, NEW.state, NEW.one__id);
END;
};
eq_or_diff $sg->insert_for_class($composed), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_composed
INSTEAD OF UPDATE ON composed
FOR EACH ROW BEGIN
  UPDATE _composed
  SET    guid = NEW.guid, state = NEW.state, one_id = NEW.one__id
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
eq_or_diff join("\n", $sg->schema_for_class($composed)),
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
    state INTEGER NOT NULL DEFAULT 1,
    composed_id INTEGER NOT NULL REFERENCES _composed(id) ON DELETE RESTRICT
);
};
eq_or_diff $sg->table_for_class($comp_comp), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_comp_comp_guid ON _comp_comp (guid);
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

CREATE TRIGGER ck_comp_comp_guid_once
BEFORE UPDATE ON _comp_comp
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN OLD.guid <> NEW.guid OR NEW.guid IS NULL
    THEN RAISE(ABORT, 'value of "guid" cannot be changed')
  END;
END;

CREATE TRIGGER ck_comp_comp_composed_id_once
BEFORE UPDATE ON _comp_comp
FOR EACH ROW BEGIN
  SELECT CASE
    WHEN OLD.composed_id <> NEW.composed_id OR NEW.composed_id IS NULL
    THEN RAISE(ABORT, 'value of "composed_id" cannot be changed')
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
  SELECT _comp_comp.id AS id, _comp_comp.guid AS guid, _comp_comp.state AS state, _comp_comp.composed_id AS composed__id, composed.guid AS composed__guid, composed.state AS composed__state, composed.one__id AS composed__one__id, composed.one__guid AS composed__one__guid, composed.one__state AS composed__one__state, composed.one__name AS composed__one__name, composed.one__description AS composed__one__description, composed.one__bool AS composed__one__bool
  FROM   _comp_comp, composed
  WHERE  _comp_comp.composed_id = composed.id;
};
eq_or_diff $sg->view_for_class($comp_comp), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_comp_comp
INSTEAD OF INSERT ON comp_comp
FOR EACH ROW BEGIN
  INSERT INTO _comp_comp (guid, state, composed_id)
  VALUES (NEW.guid, NEW.state, NEW.composed__id);
END;
};
eq_or_diff $sg->insert_for_class($comp_comp), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_comp_comp
INSTEAD OF UPDATE ON comp_comp
FOR EACH ROW BEGIN
  UPDATE _comp_comp
  SET    guid = NEW.guid, state = NEW.state, composed_id = NEW.composed__id
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
eq_or_diff join("\n", $sg->schema_for_class($comp_comp)),
  join("\n", $table, $indexes, $constraints, $view, $insert, $update, $delete),
  "... Schema class generates complete schema";

