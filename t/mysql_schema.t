#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More skip_all => "MySQL 5.01's updatable views just aren't ready";
use Kinetic::Build::Test store => { class => 'Kinetic::Store::DB::mysql' };

# Can't use ENUM() for state because numbers confuse it.
# Stupid text indexes require the number of characters to index from the
# beginning of a value. Could use FULLTEXT indexes, though. That might be
# cool. They don't seem to work with UNIQUE indexes, though.
( my $testsql = q{CREATE TABLE simple (
    id          INTEGER     NOT NULL PRIMARY KEY AUTO_INCREMENT,
    guid        LONGTEXT    NOT NULL,
    name        LONGTEXT    NOT NULL,
    description LONGTEXT,
    state       TINYINT     NOT NULL DEFAULT '1'
);

CREATE UNIQUE INDEX udx_simple_guid ON simple (guid(40));
CREATE INDEX idx_simple_name ON simple (name(10));
CREATE INDEX idx_simple_state ON simple (state);

CREATE TABLE simple_one (
    id    INTEGER  NOT NULL PRIMARY KEY REFERENCES simple(id),
    bool  BOOLEAN  NOT NULL DEFAULT '1'
);

CREATE VIEW one AS
  SELECT simple.id, simple.guid, simple.name, simple.description, simple.state, simple_one.bool
  FROM   simple, simple_one
  WHERE  simple.id = simple_one.id;

}) =~ s/[ ]+/ /g;

# This view should be updatable, but I just getn an error when I try to
# insert a value:
#
# mysql> insert into one (guid, name, description, state, bool)
#     -> values ('5', 'Fifth', '', 1, 1);
# ERROR 1288 (HY000): The target table one of the INSERT is not updatable
#
# But this example from http://dev.mysql.com/doc/mysql/en/CREATE_VIEW.html
# works:
#
# mysql> CREATE TABLE t1 (a INT);
# mysql> CREATE VIEW v1 AS SELECT * FROM t1 WHERE a < 2
#     -> WITH CHECK OPTION;
# mysql> CREATE VIEW v2 AS SELECT * FROM v1 WHERE a > 0
#     -> WITH LOCAL CHECK OPTION;
# mysql> CREATE VIEW v3 AS SELECT * FROM v1 WHERE a > 0
#     -> WITH CASCADED CHECK OPTION;
# mysql> INSERT INTO v2 VALUES (2);
# Query OK, 1 row affected (0.00 sec)
# mysql> INSERT INTO v3 VALUES (2);
# ERROR 1369 (HY000): CHECK OPTION failed 'test.v3'
#
# Go figure. We'll want to use WITH CASCADED CHECK OPTION once MySQL gets this
# stuff worked out.

