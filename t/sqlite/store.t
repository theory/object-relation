#!/usr/bin/perl -w

# $Id: store.t 3063 2006-07-21 23:07:19Z theory $

use warnings;
use strict;
use Test::File;

BEGIN {
    $ENV{OBJ_REL_CLASS} = 'DB::SQLite';
    $ENV{OBJ_REL_DSN}   = 'dbi:SQLite:dbname='
        . File::Spec->catfile(File::Spec->tmpdir, 'obj_rel.db');
}

use lib qw(t/lib t/sample/lib);

use TEST::Object::Relation::TestSetup (
    class => $ENV{OBJ_REL_CLASS},
    dsn   => $ENV{OBJ_REL_DSN},
);

use TEST::Class::Object::Relation 't/store';

TEST::Class::Object::Relation->runall;
