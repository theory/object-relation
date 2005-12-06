#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Kinetic::Build::Test store => { class => 'Kinetic::Store::DB::Pg' };

#use Test::More 'no_plan';
use Test::More tests => 80;
use Test::Differences;

{

    # Fake out loading of Pg store.
    package Kinetic::Store::DB::Pg;
    use File::Spec::Functions 'catfile';
    $INC{ catfile qw(Kinetic Store DB Pg.pm) } = __FILE__;
    sub _add_store_meta { 1 }
}

BEGIN { use_ok 'Kinetic::Build::Schema' or die }

sub left_justify {
    my $text = shift;
    $text =~ s/^\s+//gsm;
    return $text;
}

ok my $sg = Kinetic::Build::Schema->new, 'Get new Schema';
isa_ok $sg, 'Kinetic::Build::Schema';
isa_ok $sg, 'Kinetic::Build::Schema::DB';
isa_ok $sg, 'Kinetic::Build::Schema::DB::Pg';

ok $sg->load_classes('t/sample/lib'), "Load classes";
is_deeply [ map { $_->key } $sg->classes ],
  [qw(simple one composed comp_comp relation two)],
  "classes() returns classes in their proper dependency order";

for my $class ( $sg->classes ) {
    ok $class->is_a('Kinetic'), "Class is a Kinetic";
}

# XXX Hanky-panky. You didn't see this. Necessary for testing C<unique>
# attributes without unduly affecting other tests. I plan to change this soon
# by adding new attributes.
{
    for my $spec ( [ simple => 'name' ], [ two => 'date' ], ) {
        my $class = Kinetic::Meta->for_key( $spec->[0] );
        my $attr  = $class->attributes( $spec->[1] );
        $attr->{unique}  = 1;
        $attr->{indexed} = 1;
    }
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
is $simple->key,   'simple',  "... Simple class has key 'simple'";
is $simple->table, '_simple', "... Simple class has table '_simple'";

# Check that the CREATE TABLE statement is correct.
my $table = q{CREATE TABLE _simple (
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_kinetic'),
    uuid UUID NOT NULL DEFAULT UUID_V4(),
    state STATE NOT NULL DEFAULT 1,
    name TEXT NOT NULL,
    description TEXT
);
};
eq_or_diff $sg->table_for_class($simple), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
my $indexes = q{CREATE UNIQUE INDEX idx_simple_uuid ON _simple (uuid);
CREATE INDEX idx_simple_state ON _simple (state);
CREATE UNIQUE INDEX idx_simple_name ON _simple (LOWER(name)) WHERE state > -1;
};
eq_or_diff $sg->indexes_for_class($simple), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the ALTER TABLE ADD CONSTRAINT statements are correct.
my $constraints = q{ALTER TABLE _simple
  ADD CONSTRAINT pk_simple_id PRIMARY KEY (id);

CREATE FUNCTION simple_uuid_once() RETURNS trigger AS '
  BEGIN
    IF OLD.uuid <> NEW.uuid OR NEW.uuid IS NULL
        THEN RAISE EXCEPTION ''value of "uuid" cannot be changed'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql;

CREATE TRIGGER simple_uuid_once BEFORE UPDATE ON _simple
    FOR EACH ROW EXECUTE PROCEDURE simple_uuid_once();
};
eq_or_diff left_justify( $sg->constraints_for_class($simple) ),
  left_justify($constraints), "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
my $view = q{CREATE VIEW simple AS
  SELECT _simple.id AS id, _simple.uuid AS uuid, _simple.state AS state, _simple.name AS name, _simple.description AS description
  FROM   _simple;
};
eq_or_diff $sg->view_for_class($simple), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
my $insert = q{CREATE RULE insert_simple AS
ON INSERT TO simple DO INSTEAD (
  INSERT INTO _simple (id, uuid, state, name, description)
  VALUES (NEXTVAL('seq_kinetic'), COALESCE(NEW.uuid, UUID_V4()), NEW.state, NEW.name, NEW.description);
);
};
eq_or_diff $sg->insert_for_class($simple), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
my $update = q{CREATE RULE update_simple AS
ON UPDATE TO simple DO INSTEAD (
  UPDATE _simple
  SET    state = NEW.state, name = NEW.name, description = NEW.description
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
eq_or_diff left_justify( join ( "\n", $sg->schema_for_class($simple) ) ),
  left_justify(
    join (
        "\n", $table, $indexes, $constraints, $view, $insert, $update, $delete
    )
  ),
  "... Schema class generates complete schema";

##############################################################################
# Grab the one class.
ok my $one = Kinetic::Meta->for_key('one'), "Get one class";
is $one->key,   'one',        "... One class has key 'one'";
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
is $sg->indexes_for_class($one), '',
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
  SELECT simple.id AS id, simple.uuid AS uuid, simple.state AS state, simple.name AS name, simple.description AS description, simple_one.bool AS bool
  FROM   simple, simple_one
  WHERE  simple.id = simple_one.id;
};
eq_or_diff $sg->view_for_class($one), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE RULE insert_one AS
ON INSERT TO one DO INSTEAD (
  INSERT INTO _simple (id, uuid, state, name, description)
  VALUES (NEXTVAL('seq_kinetic'), COALESCE(NEW.uuid, UUID_V4()), NEW.state, NEW.name, NEW.description);

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
  SET    state = NEW.state, name = NEW.name, description = NEW.description
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
eq_or_diff join ( "\n", $sg->schema_for_class($one) ),
  join ( "\n", $table, $constraints, $view, $insert, $update, $delete ),
  "... Schema class generates complete schema";

##############################################################################
# Grab the two class.
ok my $two = Kinetic::Meta->for_key('two'), "Get two class";
is $two->key,   'two',        "... Two class has key 'two'";
is $two->table, 'simple_two', "... Two class has table 'simple_two'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE simple_two (
    id INTEGER NOT NULL,
    one_id INTEGER NOT NULL,
    age INTEGER,
    date TIMESTAMP NOT NULL
);
};
eq_or_diff $sg->table_for_class($two), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = qq{CREATE INDEX idx_two_one_id ON simple_two (one_id);
CREATE INDEX idx_two_date ON simple_two (date);
};

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
  REFERENCES simple_one(id) ON DELETE RESTRICT;

CREATE FUNCTION cki_two_date_unique() RETURNS trigger AS '
  BEGIN
    /* Lock the relevant records in the parent and child tables. */
    PERFORM true
    FROM    simple_two, _simple
    WHERE   simple_two.id = _simple.id AND date = NEW.date FOR UPDATE;
    IF (SELECT true
        FROM   two
        WHERE  id <> NEW.id AND date = NEW.date AND state > -1
        LIMIT 1
    ) THEN
        RAISE EXCEPTION ''duplicate key violates unique constraint "ck_simple_two_date_unique"'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER cki_two_date_unique BEFORE INSERT ON simple_two
    FOR EACH ROW EXECUTE PROCEDURE cki_two_date_unique();

CREATE FUNCTION cku_two_date_unique() RETURNS trigger AS '
  BEGIN
    IF (NEW.date <> OLD.date) THEN
        /* Lock the relevant records in the parent and child tables. */
        PERFORM true
        FROM    simple_two, _simple
        WHERE   simple_two.id = _simple.id AND date = NEW.date FOR UPDATE;
        IF (SELECT true
            FROM   two
            WHERE  id <> NEW.id AND date = NEW.date AND state > -1
            LIMIT 1
        ) THEN
            RAISE EXCEPTION ''duplicate key violates unique constraint "ck_simple_two_date_unique"'';
        END IF;
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER cku_two_date_unique BEFORE UPDATE ON simple_two
    FOR EACH ROW EXECUTE PROCEDURE cku_two_date_unique();

CREATE FUNCTION ckp_two_date_unique() RETURNS trigger AS '
  BEGIN
    IF (NEW.state > -1 AND OLD.state < 0
        AND (SELECT true FROM simple_two WHERE id = NEW.id)
       ) THEN
        /* Lock the relevant records in the parent and child tables. */
        PERFORM true
        FROM    simple_two, _simple
        WHERE   simple_two.id = _simple.id
                AND date = (SELECT date FROM simple_two WHERE id = NEW.id)
        FOR UPDATE;

        IF (SELECT COUNT(date)
            FROM   simple_two
            WHERE date = (SELECT date FROM simple_two WHERE id = NEW.id)
        ) > 1 THEN
            RAISE EXCEPTION ''duplicate key violates unique constraint "ck_simple_two_date_unique"'';
        END IF;
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER ckp_two_date_unique BEFORE UPDATE ON _simple
    FOR EACH ROW EXECUTE PROCEDURE ckp_two_date_unique();
};

eq_or_diff left_justify( $sg->constraints_for_class($two) ),
  left_justify($constraints), "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW two AS
  SELECT simple.id AS id, simple.uuid AS uuid, simple.state AS state, simple.name AS name, simple.description AS description, simple_two.one_id AS one__id, one.uuid AS one__uuid, one.state AS one__state, one.name AS one__name, one.description AS one__description, one.bool AS one__bool, simple_two.age AS age, simple_two.date AS date
  FROM   simple, simple_two, one
  WHERE  simple.id = simple_two.id AND simple_two.one_id = one.id;
};
eq_or_diff $sg->view_for_class($two), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE RULE insert_two AS
ON INSERT TO two DO INSTEAD (
  INSERT INTO _simple (id, uuid, state, name, description)
  VALUES (NEXTVAL('seq_kinetic'), COALESCE(NEW.uuid, UUID_V4()), NEW.state, NEW.name, NEW.description);

  INSERT INTO simple_two (id, one_id, age, date)
  VALUES (CURRVAL('seq_kinetic'), NEW.one__id, NEW.age, NEW.date);
);
};
eq_or_diff $sg->insert_for_class($two), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_two AS
ON UPDATE TO two DO INSTEAD (
  UPDATE _simple
  SET    state = NEW.state, name = NEW.name, description = NEW.description
  WHERE  id = OLD.id;

  UPDATE simple_two
  SET    one_id = NEW.one__id, age = NEW.age, date = NEW.date
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
eq_or_diff left_justify( join ( "\n", $sg->schema_for_class($two) ) ),
  left_justify(
    join (
        "\n", $table, $indexes, $constraints, $view, $insert, $update, $delete
    )
  ),
  "... Schema class generates complete schema";

##############################################################################
# Grab the relation class.
ok my $relation = Kinetic::Meta->for_key('relation'), "Get relation class";
is $relation->key,   'relation',  "... Relation class has key 'relation'";
is $relation->table, '_relation', "... Relation class has table '_relation'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _relation (
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_kinetic'),
    uuid UUID NOT NULL DEFAULT UUID_V4(),
    state STATE NOT NULL DEFAULT 1,
    one_id INTEGER NOT NULL,
    simple_id INTEGER NOT NULL
);
};
eq_or_diff $sg->table_for_class($relation), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_relation_uuid ON _relation (uuid);
CREATE INDEX idx_relation_state ON _relation (state);
CREATE INDEX idx_relation_one_id ON _relation (one_id);
CREATE INDEX idx_relation_simple_id ON _relation (simple_id);
};

eq_or_diff $sg->indexes_for_class($relation), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the ALTER TABLE ADD CONSTRAINT statements are correct.
$constraints = q{ALTER TABLE _relation
  ADD CONSTRAINT pk_relation_id PRIMARY KEY (id);

ALTER TABLE _relation
  ADD CONSTRAINT fk_one_id FOREIGN KEY (one_id)
  REFERENCES simple_one(id) ON DELETE RESTRICT;

ALTER TABLE _relation
  ADD CONSTRAINT fk_simple_id FOREIGN KEY (simple_id)
  REFERENCES _simple(id) ON DELETE RESTRICT;

CREATE FUNCTION relation_uuid_once() RETURNS trigger AS '
  BEGIN
    IF OLD.uuid <> NEW.uuid OR NEW.uuid IS NULL
        THEN RAISE EXCEPTION ''value of "uuid" cannot be changed'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql;

CREATE TRIGGER relation_uuid_once BEFORE UPDATE ON _relation
    FOR EACH ROW EXECUTE PROCEDURE relation_uuid_once();

CREATE FUNCTION relation_one_id_once() RETURNS trigger AS '
  BEGIN
    IF OLD.one_id <> NEW.one_id OR NEW.one_id IS NULL
        THEN RAISE EXCEPTION ''value of "one_id" cannot be changed'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql;

CREATE TRIGGER relation_one_id_once BEFORE UPDATE ON _relation
    FOR EACH ROW EXECUTE PROCEDURE relation_one_id_once();

CREATE FUNCTION relation_simple_id_once() RETURNS trigger AS '
  BEGIN
    IF OLD.simple_id <> NEW.simple_id OR NEW.simple_id IS NULL
        THEN RAISE EXCEPTION ''value of "simple_id" cannot be changed'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql;

CREATE TRIGGER relation_simple_id_once BEFORE UPDATE ON _relation
    FOR EACH ROW EXECUTE PROCEDURE relation_simple_id_once();
};

eq_or_diff left_justify( $sg->constraints_for_class($relation) ),
  left_justify($constraints), "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW relation AS
  SELECT _relation.id AS id, _relation.uuid AS uuid, _relation.state AS state, _relation.one_id AS one__id, one.uuid AS one__uuid, one.state AS one__state, one.name AS one__name, one.description AS one__description, one.bool AS one__bool, _relation.simple_id AS simple__id, simple.uuid AS simple__uuid, simple.state AS simple__state, simple.name AS simple__name, simple.description AS simple__description
  FROM   _relation, one, simple
  WHERE  _relation.one_id = one.id AND _relation.simple_id = simple.id;
};

eq_or_diff $sg->view_for_class($relation), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE RULE insert_relation AS
ON INSERT TO relation DO INSTEAD (
  INSERT INTO _relation (id, uuid, state, one_id, simple_id)
  VALUES (NEXTVAL('seq_kinetic'), COALESCE(NEW.uuid, UUID_V4()), NEW.state, NEW.one__id, NEW.simple__id);
);
};
eq_or_diff $sg->insert_for_class($relation), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_relation AS
ON UPDATE TO relation DO INSTEAD (
  UPDATE _relation
  SET    state = NEW.state, one_id = NEW.one__id, simple_id = NEW.simple__id
  WHERE  id = OLD.id;
);
};
eq_or_diff $sg->update_for_class($relation), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE RULE delete_relation AS
ON DELETE TO relation DO INSTEAD (
  DELETE FROM _relation
  WHERE  id = OLD.id;
);
};
eq_or_diff $sg->delete_for_class($relation), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff left_justify( join ( "\n", $sg->schema_for_class($relation) ) ),
  left_justify(
    join (
        "\n", $table, $indexes, $constraints, $view, $insert, $update, $delete
    )
  ),
  "... Schema class generates complete schema";

##############################################################################
# Grab the composed class.
ok my $composed = Kinetic::Meta->for_key('composed'), "Get composed class";
is $composed->key,   'composed',  "... Composed class has key 'composed'";
is $composed->table, '_composed', "... Composed class has table '_composed'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _composed (
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_kinetic'),
    uuid UUID NOT NULL DEFAULT UUID_V4(),
    state STATE NOT NULL DEFAULT 1,
    one_id INTEGER
);
};
eq_or_diff $sg->table_for_class($composed), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_composed_uuid ON _composed (uuid);
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
  REFERENCES simple_one(id) ON DELETE RESTRICT;

CREATE FUNCTION composed_uuid_once() RETURNS trigger AS '
  BEGIN
    IF OLD.uuid <> NEW.uuid OR NEW.uuid IS NULL
        THEN RAISE EXCEPTION ''value of "uuid" cannot be changed'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql;

CREATE TRIGGER composed_uuid_once BEFORE UPDATE ON _composed
    FOR EACH ROW EXECUTE PROCEDURE composed_uuid_once();

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
eq_or_diff left_justify( $sg->constraints_for_class($composed) ),
  left_justify($constraints), "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW composed AS
  SELECT _composed.id AS id, _composed.uuid AS uuid, _composed.state AS state, _composed.one_id AS one__id, one.uuid AS one__uuid, one.state AS one__state, one.name AS one__name, one.description AS one__description, one.bool AS one__bool
  FROM   _composed LEFT JOIN one ON _composed.one_id = one.id;
};
eq_or_diff $sg->view_for_class($composed), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE RULE insert_composed AS
ON INSERT TO composed DO INSTEAD (
  INSERT INTO _composed (id, uuid, state, one_id)
  VALUES (NEXTVAL('seq_kinetic'), COALESCE(NEW.uuid, UUID_V4()), NEW.state, NEW.one__id);
);
};
eq_or_diff $sg->insert_for_class($composed), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_composed AS
ON UPDATE TO composed DO INSTEAD (
  UPDATE _composed
  SET    state = NEW.state, one_id = NEW.one__id
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
eq_or_diff left_justify( join ( "\n", $sg->schema_for_class($composed) ) ),
  left_justify(
    join (
        "\n", $table, $indexes, $constraints, $view, $insert, $update, $delete
    )
  ),
  "... Schema class generates complete schema";

##############################################################################
# Grab the comp_comp class.
ok my $comp_comp = Kinetic::Meta->for_key('comp_comp'), "Get comp_comp class";
is $comp_comp->key,   'comp_comp',  "... CompComp class has key 'comp_comp'";
is $comp_comp->table, '_comp_comp', "... CompComp class has table 'comp_comp'";

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _comp_comp (
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_kinetic'),
    uuid UUID NOT NULL DEFAULT UUID_V4(),
    state STATE NOT NULL DEFAULT 1,
    composed_id INTEGER NOT NULL
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

# Check that the ALTER TABLE ADD CONSTRAINT statements are correct.
$constraints = q{ALTER TABLE _comp_comp
  ADD CONSTRAINT pk_comp_comp_id PRIMARY KEY (id);

ALTER TABLE _comp_comp
  ADD CONSTRAINT fk_composed_id FOREIGN KEY (composed_id)
  REFERENCES _composed(id) ON DELETE RESTRICT;

CREATE FUNCTION comp_comp_uuid_once() RETURNS trigger AS '
  BEGIN
    IF OLD.uuid <> NEW.uuid OR NEW.uuid IS NULL
        THEN RAISE EXCEPTION ''value of "uuid" cannot be changed'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql;

CREATE TRIGGER comp_comp_uuid_once BEFORE UPDATE ON _comp_comp
    FOR EACH ROW EXECUTE PROCEDURE comp_comp_uuid_once();

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
eq_or_diff left_justify( $sg->constraints_for_class($comp_comp) ),
  left_justify($constraints), "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW comp_comp AS
  SELECT _comp_comp.id AS id, _comp_comp.uuid AS uuid, _comp_comp.state AS state, _comp_comp.composed_id AS composed__id, composed.uuid AS composed__uuid, composed.state AS composed__state, composed.one__id AS composed__one__id, composed.one__uuid AS composed__one__uuid, composed.one__state AS composed__one__state, composed.one__name AS composed__one__name, composed.one__description AS composed__one__description, composed.one__bool AS composed__one__bool
  FROM   _comp_comp, composed
  WHERE  _comp_comp.composed_id = composed.id;
};
eq_or_diff $sg->view_for_class($comp_comp), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE RULE insert_comp_comp AS
ON INSERT TO comp_comp DO INSTEAD (
  INSERT INTO _comp_comp (id, uuid, state, composed_id)
  VALUES (NEXTVAL('seq_kinetic'), COALESCE(NEW.uuid, UUID_V4()), NEW.state, NEW.composed__id);
);
};
eq_or_diff $sg->insert_for_class($comp_comp), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_comp_comp AS
ON UPDATE TO comp_comp DO INSTEAD (
  UPDATE _comp_comp
  SET    state = NEW.state, composed_id = NEW.composed__id
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
eq_or_diff left_justify( join ( "\n", $sg->schema_for_class($comp_comp) ) ),
  left_justify(
    join (
        "\n", $table, $indexes, $constraints, $view, $insert, $update, $delete
    )
  ),
  "... Schema class generates complete schema";
