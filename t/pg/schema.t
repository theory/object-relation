#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Kinetic::Build::Test store => { class => 'Kinetic::Store::DB::Pg' };

#use Test::More 'no_plan';
use Test::More tests => 113;
use Test::NoWarnings; # Adds an extra test.
use Test::Differences;

FAKEPG: {
    # Fake out loading of Pg store.
    package Kinetic::Store::DB::Pg;
    use base 'Kinetic::Store::DB';
    use File::Spec::Functions 'catfile';
    $INC{ catfile qw(Kinetic Store DB Pg.pm) } = __FILE__;
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
    [qw(simple one composed comp_comp two extend relation types_test)],
    "classes() returns classes in their proper dependency order";

for my $class ( $sg->classes ) {
    ok $class->is_a('Kinetic'), $class->package . ' is a Kinetic';
}

##############################################################################
# Check Setup SQL.
is join( "\n", $sg->setup_code),
    q{CREATE DOMAIN state AS SMALLINT NOT NULL DEFAULT 1
CONSTRAINT ck_state CHECK (
   VALUE BETWEEN -1 AND 2
);

CREATE DOMAIN operator AS TEXT
CONSTRAINT ck_operator CHECK (
   VALUE IN('==', '!=', 'eq', 'ne', '=~', '!~', '>', '<', '>=', '<=', 'gt',
            'lt', 'ge', 'le')
);

CREATE DOMAIN media_type AS TEXT
CONSTRAINT ck_media_type CHECK (
   VALUE ~ '^\\\\w+/\\\\w+$'
);

CREATE DOMAIN attribute AS TEXT
CONSTRAINT ck_attribute CHECK (
   VALUE ~ '^\\\\w+\\\\.\\\\w+$'
);

CREATE DOMAIN version AS TEXT
  CONSTRAINT ck_version CHECK (
     VALUE ~ '^v?\\\\d[\\\\d._]+$'
  );
},
 "Pg setup SQL has state domain";

##############################################################################
# Grab the simple class.
ok my $simple = Kinetic::Meta->for_key('simple'), "Get simple class";
is $simple->key,   'simple',  "... Simple class has key 'simple'";
is $simple->table, '_simple', "... Simple class has table '_simple'";

# Check that the CREATE SEQUENCE statement is correct.
my $seq = "CREATE SEQUENCE seq_simple;\n";
is $sg->sequence_for_class($simple), $seq,
    '... Schema class generates CREATE SEQUENCE statement';

# Check that the CREATE TABLE statement is correct.
my $table = q{CREATE TABLE _simple (
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_simple'),
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
CREATE INDEX idx_simple_name ON _simple (LOWER(name));
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
eq_or_diff left_justify( join("\n", $sg->constraints_for_class($simple)) ),
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
  VALUES (NEXTVAL('seq_simple'), COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.name, NEW.description);
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
        "\n", $seq, $table, $indexes, $constraints, $view, $insert, $update,
        $delete
    )
  ),
  "... Schema class generates complete schema";

##############################################################################
# Grab the one class.
ok my $one = Kinetic::Meta->for_key('one'), "Get one class";
is $one->key,   'one',        "... One class has key 'one'";
is $one->table, 'simple_one', "... One class has table 'simple_one'";

# Check that the CREATE SEQUENCE statement is correct.
$seq = '';
is $sg->sequence_for_class($one), $seq,
    '... There should be no sequence for an inheriting class';

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
$insert = q{CREATE RULE insert_one AS
ON INSERT TO one DO INSTEAD (
  INSERT INTO _simple (id, uuid, state, name, description)
  VALUES (NEXTVAL('seq_simple'), COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.name, NEW.description);

  INSERT INTO simple_one (id, bool)
  VALUES (CURRVAL('seq_simple'), COALESCE(NEW.bool, true));
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

# Check that the CREATE SEQUENCE statement is correct.
is $sg->sequence_for_class($two), $seq,
    '... There should be no sequence for an inheriting class';

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
CREATE INDEX idx_two_age ON simple_two (age);
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
  ADD CONSTRAINT fk_two_one_id FOREIGN KEY (one_id)
  REFERENCES simple_one(id) ON DELETE RESTRICT;

CREATE FUNCTION cki_two_age_unique() RETURNS trigger AS '
  BEGIN
    /* Lock the relevant records in the parent and child tables. */
    PERFORM true
    FROM    simple_two, _simple
    WHERE   simple_two.id = _simple.id AND age = NEW.age FOR UPDATE;
    IF (SELECT true
        FROM   two
        WHERE  id <> NEW.id AND age = NEW.age AND state > -1
        LIMIT 1
    ) THEN
        RAISE EXCEPTION ''duplicate key violates unique constraint "ck_two_age_unique"'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER cki_two_age_unique BEFORE INSERT ON simple_two
FOR EACH ROW EXECUTE PROCEDURE cki_two_age_unique();

CREATE FUNCTION cku_two_age_unique() RETURNS trigger AS '
  BEGIN
    IF (NEW.age <> OLD.age) THEN
        /* Lock the relevant records in the parent and child tables. */
        PERFORM true
        FROM    simple_two, _simple
        WHERE   simple_two.id = _simple.id AND age = NEW.age FOR UPDATE;
        IF (SELECT true
            FROM   two
            WHERE  id <> NEW.id AND age = NEW.age AND state > -1
            LIMIT 1
        ) THEN
            RAISE EXCEPTION ''duplicate key violates unique constraint "ck_two_age_unique"'';
        END IF;
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER cku_two_age_unique BEFORE UPDATE ON simple_two
FOR EACH ROW EXECUTE PROCEDURE cku_two_age_unique();

CREATE FUNCTION ckp_two_age_unique() RETURNS trigger AS '
  BEGIN
    IF (NEW.state > -1 AND OLD.state < 0
        AND (SELECT true FROM simple_two WHERE id = NEW.id)
       ) THEN
        /* Lock the relevant records in the parent and child tables. */
        PERFORM true
        FROM    simple_two, _simple
        WHERE   simple_two.id = _simple.id
                AND age = (SELECT age FROM simple_two WHERE id = NEW.id)
        FOR UPDATE;

        IF (SELECT COUNT(age)
            FROM   simple_two
            WHERE age = (SELECT age FROM simple_two WHERE id = NEW.id)
        ) > 1 THEN
            RAISE EXCEPTION ''duplicate key violates unique constraint "ck_two_age_unique"'';
        END IF;
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER ckp_two_age_unique BEFORE UPDATE ON _simple
FOR EACH ROW EXECUTE PROCEDURE ckp_two_age_unique();
};

eq_or_diff left_justify( join("\n", $sg->constraints_for_class($two)) ),
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
  VALUES (NEXTVAL('seq_simple'), COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.name, NEW.description);

  INSERT INTO simple_two (id, one_id, age, date)
  VALUES (CURRVAL('seq_simple'), NEW.one__id, NEW.age, NEW.date);
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
        "\n", $table, $indexes, $constraints, $view, $insert, $update,
        $delete
    )
  ),
  "... Schema class generates complete schema";

##############################################################################
# Grab the relation class.
ok my $relation = Kinetic::Meta->for_key('relation'), "Get relation class";
is $relation->key,   'relation',  "... Relation class has key 'relation'";
is $relation->table, '_relation', "... Relation class has table '_relation'";

# Check that the CREATE SEQUENCE statement is correct.
$seq = "CREATE SEQUENCE seq_relation;\n";
is $sg->sequence_for_class($relation), $seq,
    '... Schema class generates CREATE SEQUENCE statement';

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _relation (
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_relation'),
    uuid UUID NOT NULL DEFAULT UUID_V4(),
    state STATE NOT NULL DEFAULT 1,
    simple_id INTEGER NOT NULL,
    one_id INTEGER NOT NULL
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

# Check that the ALTER TABLE ADD CONSTRAINT statements are correct.
$constraints = q{ALTER TABLE _relation
  ADD CONSTRAINT pk_relation_id PRIMARY KEY (id);

ALTER TABLE _relation
  ADD CONSTRAINT fk_relation_simple_id FOREIGN KEY (simple_id)
  REFERENCES _simple(id) ON DELETE CASCADE;

ALTER TABLE _relation
  ADD CONSTRAINT fk_relation_one_id FOREIGN KEY (one_id)
  REFERENCES simple_one(id) ON DELETE RESTRICT;

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

eq_or_diff left_justify( join("\n", $sg->constraints_for_class($relation)) ),
  left_justify($constraints), "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW relation AS
  SELECT _relation.id AS id, _relation.uuid AS uuid, _relation.state AS state, _relation.simple_id AS simple__id, simple.uuid AS simple__uuid, simple.state AS simple__state, simple.name AS simple__name, simple.description AS simple__description, _relation.one_id AS one__id, one.uuid AS one__uuid, one.state AS one__state, one.name AS one__name, one.description AS one__description, one.bool AS one__bool
  FROM   _relation, simple, one
  WHERE  _relation.simple_id = simple.id AND _relation.one_id = one.id;
};

eq_or_diff $sg->view_for_class($relation), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE RULE insert_relation AS
ON INSERT TO relation WHERE NEW.simple__id IS NULL DO INSTEAD (
  INSERT INTO simple (uuid, state, name, description)
  VALUES (COALESCE(NEW.simple__uuid, UUID_V4()), COALESCE(NEW.simple__state, 1), NEW.simple__name, NEW.simple__description);

  INSERT INTO _relation (id, uuid, state, simple_id, one_id)
  VALUES (NEXTVAL('seq_relation'), COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), CURRVAL('seq_simple'), NEW.one__id);
);

CREATE RULE extend_relation AS
ON INSERT TO relation WHERE NEW.simple__id IS NOT NULL DO INSTEAD (
  UPDATE simple
  SET    state = COALESCE(NEW.simple__state, state), name = COALESCE(NEW.simple__name, name), description = COALESCE(NEW.simple__description, description)
  WHERE  id = NEW.simple__id;

  INSERT INTO _relation (id, uuid, state, simple_id, one_id)
  VALUES (NEXTVAL('seq_relation'), COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.simple__id, NEW.one__id);
);

CREATE RULE insert_relation_dummy AS
ON INSERT TO relation DO INSTEAD NOTHING;
};
eq_or_diff $sg->insert_for_class($relation), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_relation AS
ON UPDATE TO relation DO INSTEAD (
  UPDATE _relation
  SET    state = NEW.state, one_id = NEW.one__id
  WHERE  id = OLD.id;

  UPDATE simple
  SET    state = NEW.simple__state, name = NEW.simple__name, description = NEW.simple__description
  WHERE  id = OLD.simple__id;
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
        "\n", $seq, $table, $indexes, $constraints, $view, $insert, $update,
        $delete
    )
  ),
  "... Schema class generates complete schema";

##############################################################################
# Grab the composed class.
ok my $composed = Kinetic::Meta->for_key('composed'), "Get composed class";
is $composed->key,   'composed',  "... Composed class has key 'composed'";
is $composed->table, '_composed', "... Composed class has table '_composed'";

# Check that the CREATE SEQUENCE statement is correct.
$seq = "CREATE SEQUENCE seq_composed;\n";
is $sg->sequence_for_class($composed), $seq,
    '... Schema class generates CREATE SEQUENCE statement';

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _composed (
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_composed'),
    uuid UUID NOT NULL DEFAULT UUID_V4(),
    state STATE NOT NULL DEFAULT 1,
    one_id INTEGER,
    color TEXT
);
};
eq_or_diff $sg->table_for_class($composed), $table,
  "... Schema class generates CREATE TABLE statement";

# Check that the CREATE INDEX statements are correct.
$indexes = q{CREATE UNIQUE INDEX idx_composed_uuid ON _composed (uuid);
CREATE INDEX idx_composed_state ON _composed (state);
CREATE INDEX idx_composed_one_id ON _composed (one_id);
CREATE UNIQUE INDEX idx_composed_color ON _composed (LOWER(color)) WHERE state > -1;
};

eq_or_diff $sg->indexes_for_class($composed), $indexes,
  "... Schema class generates CREATE INDEX statements";

# Check that the ALTER TABLE ADD CONSTRAINT statements are correct.
$constraints = q{ALTER TABLE _composed
  ADD CONSTRAINT pk_composed_id PRIMARY KEY (id);

ALTER TABLE _composed
  ADD CONSTRAINT fk_composed_one_id FOREIGN KEY (one_id)
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
eq_or_diff left_justify( join("\n", $sg->constraints_for_class($composed)) ),
  left_justify($constraints), "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW composed AS
  SELECT _composed.id AS id, _composed.uuid AS uuid, _composed.state AS state, _composed.one_id AS one__id, one.uuid AS one__uuid, one.state AS one__state, one.name AS one__name, one.description AS one__description, one.bool AS one__bool, _composed.color AS color
  FROM   _composed LEFT JOIN one ON _composed.one_id = one.id;
};
eq_or_diff $sg->view_for_class($composed), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE RULE insert_composed AS
ON INSERT TO composed DO INSTEAD (
  INSERT INTO _composed (id, uuid, state, one_id, color)
  VALUES (NEXTVAL('seq_composed'), COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.one__id, NEW.color);
);
};
eq_or_diff $sg->insert_for_class($composed), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_composed AS
ON UPDATE TO composed DO INSTEAD (
  UPDATE _composed
  SET    state = NEW.state, color = NEW.color
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
        "\n", $seq, $table, $indexes, $constraints, $view, $insert, $update,
        $delete
    )
  ),
  "... Schema class generates complete schema";

##############################################################################
# Grab the comp_comp class.
ok my $comp_comp = Kinetic::Meta->for_key('comp_comp'), "Get comp_comp class";
is $comp_comp->key,   'comp_comp',  "... CompComp class has key 'comp_comp'";
is $comp_comp->table, '_comp_comp', "... CompComp class has table 'comp_comp'";

# Check that the CREATE SEQUENCE statement is correct.
$seq = "CREATE SEQUENCE seq_comp_comp;\n";
is $sg->sequence_for_class($comp_comp), $seq,
    '... Schema class generates CREATE SEQUENCE statement';

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _comp_comp (
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_comp_comp'),
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
  ADD CONSTRAINT fk_comp_comp_composed_id FOREIGN KEY (composed_id)
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
eq_or_diff left_justify( join("\n", $sg->constraints_for_class($comp_comp)) ),
  left_justify($constraints), "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW comp_comp AS
  SELECT _comp_comp.id AS id, _comp_comp.uuid AS uuid, _comp_comp.state AS state, _comp_comp.composed_id AS composed__id, composed.uuid AS composed__uuid, composed.state AS composed__state, composed.one__id AS composed__one__id, composed.one__uuid AS composed__one__uuid, composed.one__state AS composed__one__state, composed.one__name AS composed__one__name, composed.one__description AS composed__one__description, composed.one__bool AS composed__one__bool, composed.color AS composed__color
  FROM   _comp_comp, composed
  WHERE  _comp_comp.composed_id = composed.id;
};
eq_or_diff $sg->view_for_class($comp_comp), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE RULE insert_comp_comp AS
ON INSERT TO comp_comp DO INSTEAD (
  INSERT INTO _comp_comp (id, uuid, state, composed_id)
  VALUES (NEXTVAL('seq_comp_comp'), COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.composed__id);
);
};
eq_or_diff $sg->insert_for_class($comp_comp), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_comp_comp AS
ON UPDATE TO comp_comp DO INSTEAD (
  UPDATE _comp_comp
  SET    state = NEW.state
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
        "\n", $seq, $table, $indexes, $constraints, $view, $insert, $update,
        $delete
    )
  ),
  "... Schema class generates complete schema";

##############################################################################
# Grab the extends class.
ok my $extend = Kinetic::Meta->for_key('extend'), "Get extend class";
is $extend->key, 'extend', "... Extend class has key 'extend'";
is $extend->table, '_extend', "... Extend class has table '_extend'";

# Check that the CREATE SEQUENCE statement is correct.
$seq = "CREATE SEQUENCE seq_extend;\n";
is $sg->sequence_for_class($extend), $seq,
    '... Schema class generates CREATE SEQUENCE statement';

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _extend (
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_extend'),
    uuid UUID NOT NULL DEFAULT UUID_V4(),
    state STATE NOT NULL DEFAULT 1,
    two_id INTEGER NOT NULL
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
$constraints = q{ALTER TABLE _extend
  ADD CONSTRAINT pk_extend_id PRIMARY KEY (id);

ALTER TABLE _extend
  ADD CONSTRAINT fk_extend_two_id FOREIGN KEY (two_id)
  REFERENCES simple_two(id) ON DELETE CASCADE;

CREATE FUNCTION extend_uuid_once() RETURNS trigger AS '
  BEGIN
    IF OLD.uuid <> NEW.uuid OR NEW.uuid IS NULL
        THEN RAISE EXCEPTION ''value of "uuid" cannot be changed'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql;

CREATE TRIGGER extend_uuid_once BEFORE UPDATE ON _extend
FOR EACH ROW EXECUTE PROCEDURE extend_uuid_once();

CREATE FUNCTION extend_two_id_once() RETURNS trigger AS '
  BEGIN
    IF OLD.two_id <> NEW.two_id OR NEW.two_id IS NULL
        THEN RAISE EXCEPTION ''value of "two_id" cannot be changed'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql;

CREATE TRIGGER extend_two_id_once BEFORE UPDATE ON _extend
FOR EACH ROW EXECUTE PROCEDURE extend_two_id_once();
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
$insert = q{CREATE RULE insert_extend AS
ON INSERT TO extend WHERE NEW.two__id IS NULL DO INSTEAD (
  INSERT INTO two (uuid, state, name, description, one__id, age, date)
  VALUES (COALESCE(NEW.two__uuid, UUID_V4()), COALESCE(NEW.two__state, 1), NEW.two__name, NEW.two__description, NEW.two__one__id, NEW.two__age, NEW.two__date);

  INSERT INTO _extend (id, uuid, state, two_id)
  VALUES (NEXTVAL('seq_extend'), COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), CURRVAL('seq_simple'));
);

CREATE RULE extend_extend AS
ON INSERT TO extend WHERE NEW.two__id IS NOT NULL DO INSTEAD (
  UPDATE two
  SET    state = COALESCE(NEW.two__state, state), name = COALESCE(NEW.two__name, name), description = COALESCE(NEW.two__description, description), one__id = COALESCE(NEW.two__one__id, one__id), age = COALESCE(NEW.two__age, age), date = COALESCE(NEW.two__date, date)
  WHERE  id = NEW.two__id;

  INSERT INTO _extend (id, uuid, state, two_id)
  VALUES (NEXTVAL('seq_extend'), COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.two__id);
);

CREATE RULE insert_extend_dummy AS
ON INSERT TO extend DO INSTEAD NOTHING;
};
eq_or_diff $sg->insert_for_class($extend), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_extend AS
ON UPDATE TO extend DO INSTEAD (
  UPDATE _extend
  SET    state = NEW.state
  WHERE  id = OLD.id;

  UPDATE two
  SET    state = NEW.two__state, name = NEW.two__name, description = NEW.two__description, one__id = NEW.two__one__id, age = NEW.two__age, date = NEW.two__date
  WHERE  id = OLD.two__id;
);
};
eq_or_diff $sg->update_for_class($extend), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE RULE delete_extend AS
ON DELETE TO extend DO INSTEAD (
  DELETE FROM _extend
  WHERE  id = OLD.id;
);
};
eq_or_diff $sg->delete_for_class($extend), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff left_justify( join ( "\n", $sg->schema_for_class($extend) ) ),
  left_justify(
    join (
        "\n", $seq, $table, $indexes, $constraints, $view, $insert, $update,
        $delete
    )
  ),
  "... Schema class generates complete schema";

##############################################################################
# Grab the types_test class.
ok my $types_test = Kinetic::Meta->for_key('types_test'), "Get types_test class";
is $types_test->key, 'types_test', "... Types_Test class has key 'types_test'";
is $types_test->table, '_types_test', "... Types_Test class has table '_types_test'";

# Check that the CREATE SEQUENCE statement is correct.
$seq = "CREATE SEQUENCE seq_types_test;\n";
is $sg->sequence_for_class($types_test), $seq,
    '... Schema class generates CREATE SEQUENCE statement';

# Check that the CREATE TABLE statement is correct.
$table = q{CREATE TABLE _types_test (
    id INTEGER NOT NULL DEFAULT NEXTVAL('seq_types_test'),
    uuid UUID NOT NULL DEFAULT UUID_V4(),
    state STATE NOT NULL DEFAULT 1,
    version VERSION NOT NULL,
    duration INTERVAL NOT NULL,
    operator OPERATOR NOT NULL,
    media_type MEDIA_TYPE NOT NULL,
    attribute ATTRIBUTE
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
$constraints = q{ALTER TABLE _types_test
  ADD CONSTRAINT pk_types_test_id PRIMARY KEY (id);

CREATE FUNCTION types_test_uuid_once() RETURNS trigger AS '
  BEGIN
    IF OLD.uuid <> NEW.uuid OR NEW.uuid IS NULL
        THEN RAISE EXCEPTION ''value of "uuid" cannot be changed'';
    END IF;
    RETURN NEW;
  END;
' LANGUAGE plpgsql;

CREATE TRIGGER types_test_uuid_once BEFORE UPDATE ON _types_test
FOR EACH ROW EXECUTE PROCEDURE types_test_uuid_once();
};

eq_or_diff join("\n", $sg->constraints_for_class($types_test)), $constraints,
  "... Schema class generates CONSTRAINT statement";

# Check that the CREATE VIEW statement is correct.
$view = q{CREATE VIEW types_test AS
  SELECT _types_test.id AS id, _types_test.uuid AS uuid, _types_test.state AS state, _types_test.version AS version, _types_test.duration AS duration, _types_test.operator AS operator, _types_test.media_type AS media_type, _types_test.attribute AS attribute
  FROM   _types_test;
};
eq_or_diff $sg->view_for_class($types_test), $view,
  "... Schema class generates CREATE VIEW statement";

# Check that the INSERT rule/trigger is correct.
$insert = q{CREATE RULE insert_types_test AS
ON INSERT TO types_test DO INSTEAD (
  INSERT INTO _types_test (id, uuid, state, version, duration, operator, media_type, attribute)
  VALUES (NEXTVAL('seq_types_test'), COALESCE(NEW.uuid, UUID_V4()), COALESCE(NEW.state, 1), NEW.version, NEW.duration, NEW.operator, NEW.media_type, NEW.attribute);
);
};
eq_or_diff $sg->insert_for_class($types_test), $insert,
  "... Schema class generates view INSERT rule";

# Check that the UPDATE rule/trigger is correct.
$update = q{CREATE RULE update_types_test AS
ON UPDATE TO types_test DO INSTEAD (
  UPDATE _types_test
  SET    state = NEW.state, version = NEW.version, duration = NEW.duration, operator = NEW.operator, media_type = NEW.media_type, attribute = NEW.attribute
  WHERE  id = OLD.id;
);
};
eq_or_diff $sg->update_for_class($types_test), $update,
  "... Schema class generates view UPDATE rule";

# Check that the DELETE rule/trigger is correct.
$delete = q{CREATE RULE delete_types_test AS
ON DELETE TO types_test DO INSTEAD (
  DELETE FROM _types_test
  WHERE  id = OLD.id;
);
};
eq_or_diff $sg->delete_for_class($types_test), $delete,
  "... Schema class generates view DELETE rule";

# Check that a complete schema is properly generated.
eq_or_diff left_justify( join ( "\n", $sg->schema_for_class($types_test) ) ),
  left_justify(
    join (
        "\n", $seq, $table, $indexes, $constraints, $view, $insert, $update,
        $delete
    )
  ),
  "... Schema class generates complete schema";
