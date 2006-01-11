#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Kinetic::Build::Test store => { class => 'Kinetic::Store::DB::SQLite' };
#use Test::More 'no_plan';
use Test::More tests => 105;
use Test::NoWarnings; # Adds an extra test.
use Test::Differences;

FAKESQLITE: {
    # Fake out loading of SQLite store.
    package Kinetic::Store::DB::SQLite;
    use base 'Kinetic::Store::DB';
    use File::Spec::Functions 'catfile';
    $INC{catfile qw(Kinetic Store DB SQLite.pm)} = __FILE__;
}

BEGIN { use_ok 'Kinetic::Build::Schema' or die };

ok my $sg = Kinetic::Build::Schema->new, 'Get new Schema';
isa_ok $sg, 'Kinetic::Build::Schema';
isa_ok $sg, 'Kinetic::Build::Schema::DB';
isa_ok $sg, 'Kinetic::Build::Schema::DB::SQLite';

ok $sg->load_classes('t/sample/lib'), "Load classes";
is_deeply [ map { $_->key } $sg->classes ],
  [qw(simple one composed comp_comp two extend relation types_test)],
  "classes() returns classes in their proper dependency order";

for my $class ($sg->classes) {
    ok $class->is_a('Kinetic'), $class->package . ' is a Kinetic';
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
    uuid TEXT NOT NULL,
    state INTEGER NOT NULL DEFAULT 1,
    name TEXT COLLATE nocase NOT NULL,
    description TEXT COLLATE nocase
);
};
eq_or_diff $sg->table_for_class($simple), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
my $indexes = q{CREATE UNIQUE INDEX idx_simple_uuid ON _simple (uuid);
CREATE INDEX idx_simple_state ON _simple (state);
CREATE INDEX idx_simple_name ON _simple (name);
};
eq_or_diff $sg->indexes_for_class($simple), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the TRIGGER statements are correct.
my $constraints = q{CREATE TRIGGER cki_simple_state
BEFORE INSERT ON _simple
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
    WHERE  NEW.state NOT BETWEEN -1 AND 2;
END;

CREATE TRIGGER cku_simple_state
BEFORE UPDATE OF state ON _simple
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
    WHERE  NEW.state NOT BETWEEN -1 AND 2;
END;

CREATE TRIGGER ck_simple_uuid_once
BEFORE UPDATE ON _simple
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value of "uuid" cannot be changed')
    WHERE  OLD.uuid <> NEW.uuid OR NEW.uuid IS NULL;
END;
};

eq_or_diff join("\n", $sg->constraints_for_class($simple)), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
my $view = q{CREATE VIEW simple AS
  SELECT _simple.id AS id, _simple.uuid AS uuid, _simple.state AS state, _simple.name AS name, _simple.description AS description
  FROM   _simple;
};
eq_or_diff $sg->view_for_class($simple), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
my $insert = q{CREATE TRIGGER insert_simple
INSTEAD OF INSERT ON simple
FOR EACH ROW BEGIN
  INSERT INTO _simple (uuid, state, name, description)
  VALUES (COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.name, NEW.description);
END;
};
eq_or_diff $sg->insert_for_class($simple), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
my $update = q{CREATE TRIGGER update_simple
INSTEAD OF UPDATE ON simple
FOR EACH ROW BEGIN
  UPDATE _simple
  SET    state = NEW.state, name = NEW.name, description = NEW.description
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
is $sg->indexes_for_class($one), '',
  "... Schema class generates CREATE INDEX statements";

# Check that the boolean and foreign key triggers are in place.
$constraints = q{CREATE TRIGGER cki_one_bool
BEFORE INSERT ON simple_one
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain boolean violates check constraint "ck_boolean"')
    WHERE  NEW.bool NOT IN (1, 0);
END;

CREATE TRIGGER cku_one_bool
BEFORE UPDATE OF bool ON simple_one
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain boolean violates check constraint "ck_boolean"')
    WHERE  NEW.bool NOT IN (1, 0);
END;

CREATE TRIGGER pfki_simple_one_id
BEFORE INSERT ON simple_one
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'insert on table "simple_one" violates foreign key constraint "pfk_simple_one_id"')
    WHERE  NEW.id IS NOT NULL AND (SELECT id FROM _simple WHERE id = NEW.id) IS NULL;
END;

CREATE TRIGGER pfku_simple_one_id
BEFORE UPDATE ON simple_one
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'update on table "simple_one" violates foreign key constraint "pfk_simple_one_id"')
    WHERE  NEW.id IS NOT NULL AND (SELECT id FROM _simple WHERE id = NEW.id) IS NULL;
END;

CREATE TRIGGER pfkd_simple_one_id
BEFORE DELETE ON _simple
FOR EACH ROW BEGIN
  DELETE from simple_one WHERE id = OLD.id;
END;
};
eq_or_diff join("\n", $sg->constraints_for_class($one)), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW one AS
  SELECT simple.id AS id, simple.uuid AS uuid, simple.state AS state, simple.name AS name, simple.description AS description, simple_one.bool AS bool
  FROM   simple, simple_one
  WHERE  simple.id = simple_one.id;
};
eq_or_diff $sg->view_for_class($one), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_one
INSTEAD OF INSERT ON one
FOR EACH ROW BEGIN
  INSERT INTO _simple (uuid, state, name, description)
  VALUES (COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.name, NEW.description);

  INSERT INTO simple_one (id, bool)
  VALUES (last_insert_rowid(), COALESCE(NEW.bool, 1));
END;
};
eq_or_diff $sg->insert_for_class($one), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_one
INSTEAD OF UPDATE ON one
FOR EACH ROW BEGIN
  UPDATE _simple
  SET    state = NEW.state, name = NEW.name, description = NEW.description
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
    date DATETIME NOT NULL
);
};

eq_or_diff $sg->table_for_class($two), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE INDEX idx_two_one_id ON simple_two (one_id);
CREATE INDEX idx_two_age ON simple_two (age);
};

eq_or_diff $sg->indexes_for_class($two), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the constraint and foreign key triggers are correct.
$constraints = q{CREATE TRIGGER cki_two_age_unique
BEFORE INSERT ON simple_two
FOR EACH ROW BEGIN
    SELECT RAISE (ABORT, 'column age is not unique')
    WHERE  (
               SELECT 1
               FROM   _simple, simple_two
               WHERE  _simple.id = simple_two.id
                      AND _simple.state > -1
                      AND simple_two.age = NEW.age
               LIMIT  1
           );
END;

CREATE TRIGGER cku_two_age_unique
BEFORE UPDATE ON simple_two
FOR EACH ROW BEGIN
    SELECT RAISE (ABORT, 'column age is not unique')
    WHERE  NEW.age <> OLD.age AND (
               SELECT 1
               FROM   _simple, simple_two
               WHERE  _simple.id = simple_two.id
                      AND _simple.id <> NEW.id
                      AND _simple.state > -1
                      AND simple_two.age = NEW.age
               LIMIT  1
           );
END;

CREATE TRIGGER ckp_two_age_unique
BEFORE UPDATE ON _simple
FOR EACH ROW BEGIN
    SELECT RAISE (ABORT, 'column age is not unique')
    WHERE  NEW.state > -1 AND OLD.state < 0
           AND (SELECT 1 FROM simple_two WHERE id = NEW.id)
           AND (
               SELECT COUNT(age)
               FROM   simple_two
               WHERE  age = (
                   SELECT age FROM simple_two
                   WHERE id = NEW.id
               )
           ) > 1;
END;

CREATE TRIGGER pfki_simple_two_id
BEFORE INSERT ON simple_two
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'insert on table "simple_two" violates foreign key constraint "pfk_simple_two_id"')
    WHERE  NEW.id IS NOT NULL AND (SELECT id FROM _simple WHERE id = NEW.id) IS NULL;
END;

CREATE TRIGGER pfku_simple_two_id
BEFORE UPDATE ON simple_two
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'update on table "simple_two" violates foreign key constraint "pfk_simple_two_id"')
    WHERE  NEW.id IS NOT NULL AND (SELECT id FROM _simple WHERE id = NEW.id) IS NULL;
END;

CREATE TRIGGER pfkd_simple_two_id
BEFORE DELETE ON _simple
FOR EACH ROW BEGIN
  DELETE from simple_two WHERE id = OLD.id;
END;

CREATE TRIGGER fki_two_one_id
BEFORE INSERT ON simple_two
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'insert on table "simple_two" violates foreign key constraint "fk_two_one_id"')
    WHERE  (SELECT id FROM simple_one WHERE id = NEW.one_id) IS NULL;
END;

CREATE TRIGGER fku_two_one_id
BEFORE UPDATE ON simple_two
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'update on table "simple_two" violates foreign key constraint "fk_two_one_id"')
    WHERE  (SELECT id FROM simple_one WHERE id = NEW.one_id) IS NULL;
END;

CREATE TRIGGER fkd_two_one_id
BEFORE DELETE ON simple_one
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'delete on table "simple_one" violates foreign key constraint "fk_two_one_id"')
    WHERE  (SELECT one_id FROM simple_two WHERE one_id = OLD.id) IS NOT NULL;
END;
};
eq_or_diff join("\n", $sg->constraints_for_class($two)), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW two AS
  SELECT simple.id AS id, simple.uuid AS uuid, simple.state AS state, simple.name AS name, simple.description AS description, simple_two.one_id AS one__id, one.uuid AS one__uuid, one.state AS one__state, one.name AS one__name, one.description AS one__description, one.bool AS one__bool, simple_two.age AS age, simple_two.date AS date
  FROM   simple, simple_two, one
  WHERE  simple.id = simple_two.id AND simple_two.one_id = one.id;
};
eq_or_diff $sg->view_for_class($two), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_two
INSTEAD OF INSERT ON two
FOR EACH ROW BEGIN
  INSERT INTO _simple (uuid, state, name, description)
  VALUES (COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.name, NEW.description);

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
  SET    state = NEW.state, name = NEW.name, description = NEW.description
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
    uuid TEXT NOT NULL,
    state INTEGER NOT NULL DEFAULT 1,
    simple_id INTEGER NOT NULL REFERENCES _simple(id) ON DELETE CASCADE,
    one_id INTEGER NOT NULL REFERENCES simple_one(id) ON DELETE RESTRICT
);
};
eq_or_diff $sg->table_for_class($relation), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_relation_uuid ON _relation (uuid);
CREATE INDEX idx_relation_state ON _relation (state);
CREATE INDEX idx_relation_simple_id ON _relation (simple_id);
CREATE INDEX idx_relation_one_id ON _relation (one_id);
};

eq_or_diff $sg->indexes_for_class($relation), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the constraint and foreign key triggers are correct.
$constraints = q{CREATE TRIGGER cki_relation_state
BEFORE INSERT ON _relation
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
    WHERE  NEW.state NOT BETWEEN -1 AND 2;
END;

CREATE TRIGGER cku_relation_state
BEFORE UPDATE OF state ON _relation
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
    WHERE  NEW.state NOT BETWEEN -1 AND 2;
END;

CREATE TRIGGER ck_relation_uuid_once
BEFORE UPDATE ON _relation
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value of "uuid" cannot be changed')
    WHERE  OLD.uuid <> NEW.uuid OR NEW.uuid IS NULL;
END;

CREATE TRIGGER ck_relation_simple_id_once
BEFORE UPDATE ON _relation
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value of "simple_id" cannot be changed')
    WHERE  OLD.simple_id <> NEW.simple_id OR NEW.simple_id IS NULL;
END;

CREATE TRIGGER fki_relation_simple_id
BEFORE INSERT ON _relation
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'insert on table "_relation" violates foreign key constraint "fk_relation_simple_id"')
    WHERE  (SELECT id FROM _simple WHERE id = NEW.simple_id) IS NULL;
END;

CREATE TRIGGER fku_relation_simple_id
BEFORE UPDATE ON _relation
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'update on table "_relation" violates foreign key constraint "fk_relation_simple_id"')
    WHERE  (SELECT id FROM _simple WHERE id = NEW.simple_id) IS NULL;
END;

CREATE TRIGGER fkd_relation_simple_id
BEFORE DELETE ON _simple
FOR EACH ROW BEGIN
  DELETE from _relation WHERE simple_id = OLD.id;
END;

CREATE TRIGGER fki_relation_one_id
BEFORE INSERT ON _relation
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'insert on table "_relation" violates foreign key constraint "fk_relation_one_id"')
    WHERE  (SELECT id FROM simple_one WHERE id = NEW.one_id) IS NULL;
END;

CREATE TRIGGER fku_relation_one_id
BEFORE UPDATE ON _relation
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'update on table "_relation" violates foreign key constraint "fk_relation_one_id"')
    WHERE  (SELECT id FROM simple_one WHERE id = NEW.one_id) IS NULL;
END;

CREATE TRIGGER fkd_relation_one_id
BEFORE DELETE ON simple_one
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'delete on table "simple_one" violates foreign key constraint "fk_relation_one_id"')
    WHERE  (SELECT one_id FROM _relation WHERE one_id = OLD.id) IS NOT NULL;
END;
};
eq_or_diff join("\n", $sg->constraints_for_class($relation)), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW relation AS
  SELECT _relation.id AS id, _relation.uuid AS uuid, _relation.state AS state, _relation.simple_id AS simple__id, simple.uuid AS simple__uuid, simple.state AS simple__state, simple.name AS simple__name, simple.description AS simple__description, _relation.one_id AS one__id, one.uuid AS one__uuid, one.state AS one__state, one.name AS one__name, one.description AS one__description, one.bool AS one__bool
  FROM   _relation, simple, one
  WHERE  _relation.simple_id = simple.id AND _relation.one_id = one.id;
};
eq_or_diff $sg->view_for_class($relation), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_relation
INSTEAD OF INSERT ON relation
FOR EACH ROW BEGIN
  INSERT INTO _simple (uuid, state, name, description)
  SELECT COALESCE(NEW.simple__uuid, UUID_V4()), COALESCE(NEW.simple__state, 1), NEW.simple__name, NEW.simple__description
  WHERE  NEW.simple__id IS NULL;

  UPDATE simple
  SET    state = COALESCE(NEW.simple__state, state), name = COALESCE(NEW.simple__name, name), description = COALESCE(NEW.simple__description, description)
  WHERE  NEW.simple__id IS NOT NULL AND id = NEW.simple__id;

  INSERT INTO _relation (uuid, state, simple_id, one_id)
  VALUES (COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), COALESCE(NEW.simple__id, last_insert_rowid()), NEW.one__id);
END;
};
eq_or_diff $sg->insert_for_class($relation), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_relation
INSTEAD OF UPDATE ON relation
FOR EACH ROW BEGIN
  UPDATE simple
  SET    state = NEW.simple__state, name = NEW.simple__name, description = NEW.simple__description
  WHERE  id = OLD.simple__id;

  UPDATE _relation
  SET    state = NEW.state, one_id = NEW.one__id
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
    uuid TEXT NOT NULL,
    state INTEGER NOT NULL DEFAULT 1,
    one_id INTEGER REFERENCES simple_one(id) ON DELETE RESTRICT,
    color TEXT COLLATE nocase
);
};
eq_or_diff $sg->table_for_class($composed), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_composed_uuid ON _composed (uuid);
CREATE INDEX idx_composed_state ON _composed (state);
CREATE INDEX idx_composed_one_id ON _composed (one_id);
CREATE INDEX idx_composed_color ON _composed (color);
};

eq_or_diff $sg->indexes_for_class($composed), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the constraint and foreign key triggers are correct.
$constraints = q{CREATE TRIGGER cki_composed_state
BEFORE INSERT ON _composed
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
    WHERE  NEW.state NOT BETWEEN -1 AND 2;
END;

CREATE TRIGGER cku_composed_state
BEFORE UPDATE OF state ON _composed
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
    WHERE  NEW.state NOT BETWEEN -1 AND 2;
END;

CREATE TRIGGER ck_composed_uuid_once
BEFORE UPDATE ON _composed
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value of "uuid" cannot be changed')
    WHERE  OLD.uuid <> NEW.uuid OR NEW.uuid IS NULL;
END;

CREATE TRIGGER ck_composed_one_id_once
BEFORE UPDATE ON _composed
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value of "one_id" cannot be changed')
    WHERE  OLD.one_id IS NOT NULL AND (OLD.one_id <> NEW.one_id OR NEW.one_id IS NULL);
END;

CREATE TRIGGER cki_composed_color_unique
BEFORE INSERT ON _composed
FOR EACH ROW BEGIN
    SELECT RAISE (ABORT, 'column color is not unique')
    WHERE  (
               SELECT 1
               FROM   _composed
               WHERE  state > -1 AND color = NEW.color
               LIMIT  1
           );
END;

CREATE TRIGGER cku_composed_color_unique
BEFORE UPDATE ON _composed
FOR EACH ROW BEGIN
    SELECT RAISE (ABORT, 'column color is not unique')
    WHERE  (NEW.color <> OLD.color OR (
                NEW.state > -1 AND OLD.state < 0
            )) AND (
               SELECT 1 from _composed
               WHERE  id <> NEW.id
                      AND color = NEW.color
                      AND state > -1
               LIMIT 1
           );
END;

CREATE TRIGGER fki_composed_one_id
BEFORE INSERT ON _composed
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'insert on table "_composed" violates foreign key constraint "fk_composed_one_id"')
    WHERE  NEW.one_id IS NOT NULL AND (SELECT id FROM simple_one WHERE id = NEW.one_id) IS NULL;
END;

CREATE TRIGGER fku_composed_one_id
BEFORE UPDATE ON _composed
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'update on table "_composed" violates foreign key constraint "fk_composed_one_id"')
    WHERE  NEW.one_id IS NOT NULL AND (SELECT id FROM simple_one WHERE id = NEW.one_id) IS NULL;
END;

CREATE TRIGGER fkd_composed_one_id
BEFORE DELETE ON simple_one
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'delete on table "simple_one" violates foreign key constraint "fk_composed_one_id"')
    WHERE  (SELECT one_id FROM _composed WHERE one_id = OLD.id) IS NOT NULL;
END;
};
eq_or_diff join("\n", $sg->constraints_for_class($composed)), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW composed AS
  SELECT _composed.id AS id, _composed.uuid AS uuid, _composed.state AS state, _composed.one_id AS one__id, one.uuid AS one__uuid, one.state AS one__state, one.name AS one__name, one.description AS one__description, one.bool AS one__bool, _composed.color AS color
  FROM   _composed LEFT JOIN one ON _composed.one_id = one.id;
};
eq_or_diff $sg->view_for_class($composed), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_composed
INSTEAD OF INSERT ON composed
FOR EACH ROW BEGIN
  INSERT INTO _composed (uuid, state, one_id, color)
  VALUES (COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.one__id, NEW.color);
END;
};
eq_or_diff $sg->insert_for_class($composed), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_composed
INSTEAD OF UPDATE ON composed
FOR EACH ROW BEGIN
  UPDATE _composed
  SET    state = NEW.state, color = NEW.color
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
is $comp_comp->table, '_comp_comp', "... CompComp class has table '_comp_comp'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _comp_comp (
    id INTEGER NOT NULL PRIMARY KEY,
    uuid TEXT NOT NULL,
    state INTEGER NOT NULL DEFAULT 1,
    composed_id INTEGER NOT NULL REFERENCES _composed(id) ON DELETE RESTRICT
);
};
eq_or_diff $sg->table_for_class($comp_comp), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_comp_comp_uuid ON _comp_comp (uuid);
CREATE INDEX idx_comp_comp_state ON _comp_comp (state);
CREATE INDEX idx_comp_comp_composed_id ON _comp_comp (composed_id);
};

eq_or_diff $sg->indexes_for_class($comp_comp), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the constraint and foreign key triggers are correct.
$constraints = q{CREATE TRIGGER cki_comp_comp_state
BEFORE INSERT ON _comp_comp
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
    WHERE  NEW.state NOT BETWEEN -1 AND 2;
END;

CREATE TRIGGER cku_comp_comp_state
BEFORE UPDATE OF state ON _comp_comp
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
    WHERE  NEW.state NOT BETWEEN -1 AND 2;
END;

CREATE TRIGGER ck_comp_comp_uuid_once
BEFORE UPDATE ON _comp_comp
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value of "uuid" cannot be changed')
    WHERE  OLD.uuid <> NEW.uuid OR NEW.uuid IS NULL;
END;

CREATE TRIGGER ck_comp_comp_composed_id_once
BEFORE UPDATE ON _comp_comp
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value of "composed_id" cannot be changed')
    WHERE  OLD.composed_id <> NEW.composed_id OR NEW.composed_id IS NULL;
END;

CREATE TRIGGER fki_comp_comp_composed_id
BEFORE INSERT ON _comp_comp
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'insert on table "_comp_comp" violates foreign key constraint "fk_comp_comp_composed_id"')
    WHERE  (SELECT id FROM _composed WHERE id = NEW.composed_id) IS NULL;
END;

CREATE TRIGGER fku_comp_comp_composed_id
BEFORE UPDATE ON _comp_comp
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'update on table "_comp_comp" violates foreign key constraint "fk_comp_comp_composed_id"')
    WHERE  (SELECT id FROM _composed WHERE id = NEW.composed_id) IS NULL;
END;

CREATE TRIGGER fkd_comp_comp_composed_id
BEFORE DELETE ON _composed
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'delete on table "_composed" violates foreign key constraint "fk_comp_comp_composed_id"')
    WHERE  (SELECT composed_id FROM _comp_comp WHERE composed_id = OLD.id) IS NOT NULL;
END;
};

eq_or_diff join("\n", $sg->constraints_for_class($comp_comp)), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW comp_comp AS
  SELECT _comp_comp.id AS id, _comp_comp.uuid AS uuid, _comp_comp.state AS state, _comp_comp.composed_id AS composed__id, composed.uuid AS composed__uuid, composed.state AS composed__state, composed.one__id AS composed__one__id, composed.one__uuid AS composed__one__uuid, composed.one__state AS composed__one__state, composed.one__name AS composed__one__name, composed.one__description AS composed__one__description, composed.one__bool AS composed__one__bool, composed.color AS composed__color
  FROM   _comp_comp, composed
  WHERE  _comp_comp.composed_id = composed.id;
};
eq_or_diff $sg->view_for_class($comp_comp), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_comp_comp
INSTEAD OF INSERT ON comp_comp
FOR EACH ROW BEGIN
  INSERT INTO _comp_comp (uuid, state, composed_id)
  VALUES (COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.composed__id);
END;
};
eq_or_diff $sg->insert_for_class($comp_comp), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_comp_comp
INSTEAD OF UPDATE ON comp_comp
FOR EACH ROW BEGIN
  UPDATE _comp_comp
  SET    state = NEW.state
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

##############################################################################
# Grab the extends class.
ok my $extend = Kinetic::Meta->for_key('extend'), "Get extend class";
is $extend->key, 'extend', "... Extend class has key 'extend'";
is $extend->table, '_extend', "... CompComp class has table '_extend'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _extend (
    id INTEGER NOT NULL PRIMARY KEY,
    uuid TEXT NOT NULL,
    state INTEGER NOT NULL DEFAULT 1,
    two_id INTEGER NOT NULL REFERENCES simple_two(id) ON DELETE CASCADE
);
};
eq_or_diff $sg->table_for_class($extend), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_extend_uuid ON _extend (uuid);
CREATE INDEX idx_extend_state ON _extend (state);
CREATE INDEX idx_extend_two_id ON _extend (two_id);
};

eq_or_diff $sg->indexes_for_class($extend), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the constraint and foreign key triggers are correct.
$constraints = q{CREATE TRIGGER cki_extend_state
BEFORE INSERT ON _extend
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
    WHERE  NEW.state NOT BETWEEN -1 AND 2;
END;

CREATE TRIGGER cku_extend_state
BEFORE UPDATE OF state ON _extend
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
    WHERE  NEW.state NOT BETWEEN -1 AND 2;
END;

CREATE TRIGGER ck_extend_uuid_once
BEFORE UPDATE ON _extend
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value of "uuid" cannot be changed')
    WHERE  OLD.uuid <> NEW.uuid OR NEW.uuid IS NULL;
END;

CREATE TRIGGER ck_extend_two_id_once
BEFORE UPDATE ON _extend
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value of "two_id" cannot be changed')
    WHERE  OLD.two_id <> NEW.two_id OR NEW.two_id IS NULL;
END;

CREATE TRIGGER fki_extend_two_id
BEFORE INSERT ON _extend
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'insert on table "_extend" violates foreign key constraint "fk_extend_two_id"')
    WHERE  (SELECT id FROM simple_two WHERE id = NEW.two_id) IS NULL;
END;

CREATE TRIGGER fku_extend_two_id
BEFORE UPDATE ON _extend
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'update on table "_extend" violates foreign key constraint "fk_extend_two_id"')
    WHERE  (SELECT id FROM simple_two WHERE id = NEW.two_id) IS NULL;
END;

CREATE TRIGGER fkd_extend_two_id
BEFORE DELETE ON simple_two
FOR EACH ROW BEGIN
  DELETE from _extend WHERE two_id = OLD.id;
END;
};

eq_or_diff join("\n", $sg->constraints_for_class($extend)), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW extend AS
  SELECT _extend.id AS id, _extend.uuid AS uuid, _extend.state AS state, _extend.two_id AS two__id, two.uuid AS two__uuid, two.state AS two__state, two.name AS two__name, two.description AS two__description, two.one__id AS two__one__id, two.one__uuid AS two__one__uuid, two.one__state AS two__one__state, two.one__name AS two__one__name, two.one__description AS two__one__description, two.one__bool AS two__one__bool, two.age AS two__age, two.date AS two__date
  FROM   _extend, two
  WHERE  _extend.two_id = two.id;
};
eq_or_diff $sg->view_for_class($extend), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_extend
INSTEAD OF INSERT ON extend
FOR EACH ROW BEGIN
  INSERT INTO _simple (uuid, state, name, description)
  SELECT COALESCE(NEW.two__uuid, UUID_V4()), COALESCE(NEW.two__state, 1), NEW.two__name, NEW.two__description
  WHERE  NEW.two__id IS NULL;

  INSERT INTO simple_two (id, one_id, age, date)
  SELECT last_insert_rowid(), NEW.two__one__id, NEW.two__age, NEW.two__date
  WHERE  NEW.two__id IS NULL;

  UPDATE two
  SET    state = COALESCE(NEW.two__state, state), name = COALESCE(NEW.two__name, name), description = COALESCE(NEW.two__description, description), one__id = COALESCE(NEW.two__one__id, one__id), age = COALESCE(NEW.two__age, age), date = COALESCE(NEW.two__date, date)
  WHERE  NEW.two__id IS NOT NULL AND id = NEW.two__id;

  INSERT INTO _extend (uuid, state, two_id)
  VALUES (COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), COALESCE(NEW.two__id, last_insert_rowid()));
END;
};
eq_or_diff $sg->insert_for_class($extend), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_extend
INSTEAD OF UPDATE ON extend
FOR EACH ROW BEGIN
  UPDATE two
  SET    state = NEW.two__state, name = NEW.two__name, description = NEW.two__description, one__id = NEW.two__one__id, age = NEW.two__age, date = NEW.two__date
  WHERE  id = OLD.two__id;

  UPDATE _extend
  SET    state = NEW.state
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->update_for_class($extend), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE TRIGGER delete_extend
INSTEAD OF DELETE ON extend
FOR EACH ROW BEGIN
  DELETE FROM _extend
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->delete_for_class($extend), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff join("\n", $sg->schema_for_class($extend)),
  join("\n", $table, $indexes, $constraints, $view, $insert, $update, $delete),
  "... Schema class generates complete schema";

##############################################################################
# Grab the types_test class.
ok my $types_test = Kinetic::Meta->for_key('types_test'), "Get types_test class";
is $types_test->key, 'types_test', "... Types_Test class has key 'types_test'";
is $types_test->table, '_types_test', "... Types_Test class has table '_types_test'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _types_test (
    id INTEGER NOT NULL PRIMARY KEY,
    uuid TEXT NOT NULL,
    state INTEGER NOT NULL DEFAULT 1,
    version TEXT NOT NULL,
    duration TEXT NOT NULL,
    operator TEXT NOT NULL
);
};
eq_or_diff $sg->table_for_class($types_test), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_types_test_uuid ON _types_test (uuid);
CREATE INDEX idx_types_test_state ON _types_test (state);
CREATE INDEX idx_types_test_duration ON _types_test (duration);
};

eq_or_diff $sg->indexes_for_class($types_test), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the constraint and foreign key triggers are correct.
$constraints = q{CREATE TRIGGER cki_types_test_state
BEFORE INSERT ON _types_test
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
    WHERE  NEW.state NOT BETWEEN -1 AND 2;
END;

CREATE TRIGGER cku_types_test_state
BEFORE UPDATE OF state ON _types_test
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value for domain state violates check constraint "ck_state"')
    WHERE  NEW.state NOT BETWEEN -1 AND 2;
END;

CREATE TRIGGER ck_types_test_uuid_once
BEFORE UPDATE ON _types_test
FOR EACH ROW BEGIN
    SELECT RAISE(ABORT, 'value of "uuid" cannot be changed')
    WHERE  OLD.uuid <> NEW.uuid OR NEW.uuid IS NULL;
END;
};

eq_or_diff join("\n", $sg->constraints_for_class($types_test)), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW types_test AS
  SELECT _types_test.id AS id, _types_test.uuid AS uuid, _types_test.state AS state, _types_test.version AS version, _types_test.duration AS duration, _types_test.operator AS operator
  FROM   _types_test;
};
eq_or_diff $sg->view_for_class($types_test), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE TRIGGER insert_types_test
INSTEAD OF INSERT ON types_test
FOR EACH ROW BEGIN
  INSERT INTO _types_test (uuid, state, version, duration, operator)
  VALUES (COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.version, NEW.duration, NEW.operator);
END;
};
eq_or_diff $sg->insert_for_class($types_test), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE TRIGGER update_types_test
INSTEAD OF UPDATE ON types_test
FOR EACH ROW BEGIN
  UPDATE _types_test
  SET    state = NEW.state, version = NEW.version, duration = NEW.duration, operator = NEW.operator
  WHERE  id = OLD.id;
END;
};
eq_or_diff $sg->update_for_class($types_test), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE TRIGGER delete_types_test
INSTEAD OF DELETE ON types_test
FOR EACH ROW BEGIN
  DELETE FROM _types_test
  WHERE  id = OLD.id;
END;
};

eq_or_diff $sg->delete_for_class($types_test), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff join("\n", $sg->schema_for_class($types_test)),
  join("\n", $table, $indexes, $constraints, $view, $insert, $update, $delete),
  "... Schema class generates complete schema";
