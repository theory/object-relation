#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Kinetic::Build::Test store => { class => 'Kinetic::Store::DB::Pg' };
use Test::More tests => 68;
use Test::Differences;

BEGIN { use_ok 'Kinetic::Build::Schema' or die };

ok my $sg = Kinetic::Build::Schema->new, 'Get new Schema';
isa_ok $sg, 'Kinetic::Build::Schema';
isa_ok $sg, 'Kinetic::Build::Schema::DB';
isa_ok $sg, 'Kinetic::Build::Schema::DB::Pg';

ok $sg->load_classes('t/lib'), "Load classes";
is_deeply [ map { $_->key } $sg->classes ],
  [qw(simple one two composed comp_comp)],
  "classes() returns classes in their proper dependency order";

for my $class ($sg->classes) {
    ok $class->is_a('Kinetic'), "Class is a Kinetic";
}

##############################################################################
# Check Setup SQL.
is $sg->setup_code, 'CREATE SEQUENCE seq_kinetic;

CREATE DOMAIN state AS SMALLINT NOT NULL DEFAULT 1
CONSTRAINT ck_state CHECK (
   VALUE BETWEEN -1 AND 2
);
', "Pg setup SQL has sequence, state domain";

##############################################################################
# Grab the simple class.
ok my $simple = Kinetic::Meta->for_key('simple'), "Get simple class";
is $simple->key, 'simple', "... Simple class has key 'simple'";
is $simple->table, '_simple', "... Simple class has table '_simple'";

# Check that the CREATE TABLE statement is correct.
my $table = q{CREATE TABLE _simple (
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_kinetic'),
    guid TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    state STATE NOT NULL DEFAULT 1
);
};
eq_or_diff $sg->table_for_class($simple), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
my $indexes = q{CREATE UNIQUE INDEX idx_simple_guid ON _simple (LOWER(guid));
CREATE INDEX idx_simple_name ON _simple (LOWER(name));
CREATE INDEX idx_simple_state ON _simple (state);
};
eq_or_diff $sg->indexes_for_class($simple), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the ALTER TABLE ADD CONSTRAINT statements are correct.
my $constraints = q{ALTER TABLE _simple
  ADD CONSTRAINT pk_simple_id PRIMARY KEY (id);
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
my $insert = q{CREATE RULE insert_simple AS
ON INSERT TO simple DO INSTEAD (
  INSERT INTO _simple (id, guid, name, description, state)
  VALUES (NEXTVAL('seq_kinetic'), NEW.guid, NEW.name, NEW.description, NEW.state);
);
};
eq_or_diff $sg->insert_for_class($simple), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
my $update = q{CREATE RULE update_simple AS
ON UPDATE TO simple DO INSTEAD (
  UPDATE _simple
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state
  WHERE  id = OLD.id;
);
};
eq_or_diff $sg->update_for_class($simple), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
my $delete = q{CREATE RULE delete_simple AS
ON DELETE TO simple DO INSTEAD (
  DELETE FROM _simple
  WHERE  id = OLD.id;
);
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
    id INTEGER NOT NULL,
    bool BOOLEAN NOT NULL DEFAULT true
);
};
eq_or_diff $sg->table_for_class($one), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
is $sg->indexes_for_class($one), undef,
  "... Schema class generates CREATE INDEX statements";

# Check that the ALTER TABLE ADD CONSTRAINT statements are correct.
$constraints = q{ALTER TABLE simple_one
  ADD CONSTRAINT pk_one_id PRIMARY KEY (id);

ALTER TABLE simple_one
  ADD CONSTRAINT pfk_simple_one_id FOREIGN KEY (id)
  REFERENCES _simple(id) ON DELETE CASCADE;
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
$insert = q{CREATE RULE insert_one AS
ON INSERT TO one DO INSTEAD (
  INSERT INTO _simple (id, guid, name, description, state)
  VALUES (NEXTVAL('seq_kinetic'), NEW.guid, NEW.name, NEW.description, NEW.state);

  INSERT INTO simple_one (id, bool)
  VALUES (CURRVAL('seq_kinetic'), NEW.bool);
);
};
eq_or_diff $sg->insert_for_class($one), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_one AS
ON UPDATE TO one DO INSTEAD (
  UPDATE _simple
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state
  WHERE  id = OLD.id;

  UPDATE simple_one
  SET    bool = NEW.bool
  WHERE  id = OLD.id;
);
};
eq_or_diff $sg->update_for_class($one), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE RULE delete_one AS
ON DELETE TO one DO INSTEAD (
  DELETE FROM simple_one
  WHERE  id = OLD.id;
);
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
    id INTEGER NOT NULL,
    one_id INTEGER NOT NULL
);
};
eq_or_diff $sg->table_for_class($two), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = qq{CREATE INDEX idx_two_one_id ON simple_two (one_id);\n};

eq_or_diff $sg->indexes_for_class($two), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the ALTER TABLE ADD CONSTRAINT statements are correct.
$constraints = q{ALTER TABLE simple_two
  ADD CONSTRAINT pk_two_id PRIMARY KEY (id);

ALTER TABLE simple_two
  ADD CONSTRAINT pfk_simple_two_id FOREIGN KEY (id)
  REFERENCES _simple(id) ON DELETE CASCADE;

ALTER TABLE simple_two
  ADD CONSTRAINT fk_one_id FOREIGN KEY (one_id)
  REFERENCES simple_one(id) ON DELETE CASCADE;
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
$insert = q{CREATE RULE insert_two AS
ON INSERT TO two DO INSTEAD (
  INSERT INTO _simple (id, guid, name, description, state)
  VALUES (NEXTVAL('seq_kinetic'), NEW.guid, NEW.name, NEW.description, NEW.state);

  INSERT INTO simple_two (id, one_id)
  VALUES (CURRVAL('seq_kinetic'), NEW.one_id);
);
};
eq_or_diff $sg->insert_for_class($two), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_two AS
ON UPDATE TO two DO INSTEAD (
  UPDATE _simple
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state
  WHERE  id = OLD.id;

  UPDATE simple_two
  SET    one_id = NEW.one_id
  WHERE  id = OLD.id;
);
};
eq_or_diff $sg->update_for_class($two), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE RULE delete_two AS
ON DELETE TO two DO INSTEAD (
  DELETE FROM simple_two
  WHERE  id = OLD.id;
);
};
eq_or_diff $sg->delete_for_class($two), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff join("\n", $sg->schema_for_class($two)),
  join("\n", $table, $indexes, $constraints, $view, $insert, $update, $delete),
  "... Schema class generates complete schema";

##############################################################################
# Grab the composed class.
ok my $composed = Kinetic::Meta->for_key('composed'), "Get composed class";
is $composed->key, 'composed', "... Composed class has key 'composed'";
is $composed->table, '_composed', "... Composed class has table '_composed'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _composed (
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_kinetic'),
    guid TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    state STATE NOT NULL DEFAULT 1,
    one_id INTEGER
);
};
eq_or_diff $sg->table_for_class($composed), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_composed_guid ON _composed (LOWER(guid));
CREATE INDEX idx_composed_name ON _composed (LOWER(name));
CREATE INDEX idx_composed_state ON _composed (state);
CREATE INDEX idx_composed_one_id ON _composed (one_id);
};

eq_or_diff $sg->indexes_for_class($composed), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the ALTER TABLE ADD CONSTRAINT statements are correct.
$constraints = q{ALTER TABLE _composed
  ADD CONSTRAINT pk_composed_id PRIMARY KEY (id);

ALTER TABLE _composed
  ADD CONSTRAINT fk_one_id FOREIGN KEY (one_id)
  REFERENCES simple_one(id) ON DELETE CASCADE;

CREATE FUNCTION composed_one_id_once() RETURNS trigger AS '
  BEGIN
    IF OLD.one_id IS NOT NULL AND (OLD.one_id <> NEW.one_id OR NEW.one_id IS NULL)
        THEN RAISE EXCEPTION ''value of "one_id" cannot be changed'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql;

CREATE TRIGGER composed_one_id_once BEFORE UPDATE ON _composed
    FOR EACH ROW EXECUTE PROCEDURE composed_one_id_once();
};
eq_or_diff $sg->constraints_for_class($composed), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW composed AS
  SELECT _composed.id, _composed.guid, _composed.name, _composed.description, _composed.state, _composed.one_id, one.guid AS "one.guid", one.name AS "one.name", one.description AS "one.description", one.state AS "one.state", one.bool AS "one.bool"
  FROM   _composed LEFT JOIN one ON _composed.one_id = one.id;
};
eq_or_diff $sg->view_for_class($composed), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE RULE insert_composed AS
ON INSERT TO composed DO INSTEAD (
  INSERT INTO _composed (id, guid, name, description, state, one_id)
  VALUES (NEXTVAL('seq_kinetic'), NEW.guid, NEW.name, NEW.description, NEW.state, NEW.one_id);
);
};
eq_or_diff $sg->insert_for_class($composed), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_composed AS
ON UPDATE TO composed DO INSTEAD (
  UPDATE _composed
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state, one_id = NEW.one_id
  WHERE  id = OLD.id;
);
};
eq_or_diff $sg->update_for_class($composed), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE RULE delete_composed AS
ON DELETE TO composed DO INSTEAD (
  DELETE FROM _composed
  WHERE  id = OLD.id;
);
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
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_kinetic'),
    guid TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    state STATE NOT NULL DEFAULT 1,
    composed_id INTEGER NOT NULL
);
};
eq_or_diff $sg->table_for_class($comp_comp), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_comp_comp_guid ON _comp_comp (LOWER(guid));
CREATE INDEX idx_comp_comp_name ON _comp_comp (LOWER(name));
CREATE INDEX idx_comp_comp_state ON _comp_comp (state);
CREATE INDEX idx_comp_comp_composed_id ON _comp_comp (composed_id);
};

eq_or_diff $sg->indexes_for_class($comp_comp), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the ALTER TABLE ADD CONSTRAINT statements are correct.
$constraints = q{ALTER TABLE _comp_comp
  ADD CONSTRAINT pk_comp_comp_id PRIMARY KEY (id);

ALTER TABLE _comp_comp
  ADD CONSTRAINT fk_composed_id FOREIGN KEY (composed_id)
  REFERENCES _composed(id) ON DELETE RESTRICT;

CREATE FUNCTION comp_comp_composed_id_once() RETURNS trigger AS '
  BEGIN
    IF OLD.composed_id <> NEW.composed_id OR NEW.composed_id IS NULL
        THEN RAISE EXCEPTION ''value of "composed_id" cannot be changed'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql;

CREATE TRIGGER comp_comp_composed_id_once BEFORE UPDATE ON _comp_comp
    FOR EACH ROW EXECUTE PROCEDURE comp_comp_composed_id_once();
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
$insert = q{CREATE RULE insert_comp_comp AS
ON INSERT TO comp_comp DO INSTEAD (
  INSERT INTO _comp_comp (id, guid, name, description, state, composed_id)
  VALUES (NEXTVAL('seq_kinetic'), NEW.guid, NEW.name, NEW.description, NEW.state, NEW.composed_id);
);
};
eq_or_diff $sg->insert_for_class($comp_comp), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_comp_comp AS
ON UPDATE TO comp_comp DO INSTEAD (
  UPDATE _comp_comp
  SET    guid = NEW.guid, name = NEW.name, description = NEW.description, state = NEW.state, composed_id = NEW.composed_id
  WHERE  id = OLD.id;
);
};
eq_or_diff $sg->update_for_class($comp_comp), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE RULE delete_comp_comp AS
ON DELETE TO comp_comp DO INSTEAD (
  DELETE FROM _comp_comp
  WHERE  id = OLD.id;
);
};
eq_or_diff $sg->delete_for_class($comp_comp), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff join("\n", $sg->schema_for_class($comp_comp)),
  join("\n", $table, $indexes, $constraints, $view, $insert, $update, $delete),
  "... Schema class generates complete schema";
