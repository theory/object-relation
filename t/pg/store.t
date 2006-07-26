#!/usr/bin/perl -w

# $Id: store.t 3063 2006-07-21 23:07:19Z theory $

use warnings;
use strict;
use Test::File;

BEGIN {
    unless ($ENV{OBJ_REL_CLASS} && $ENV{OBJ_REL_CLASS} =~ /DB::Pg$/) {
        require Test::More;
        Test::More::plan( skip_all => 'Not testing live PostgreSQL store' );
    }
}

use lib qw(t/lib t/sample/lib);

use TEST::Object::Relation::TestSetup (
    class        => $ENV{OBJ_REL_CLASS},
    user         => $ENV{OBJ_REL_USER}         || '',
    pass         => $ENV{OBJ_REL_PASS}         || '',
    super_user   => $ENV{OBJ_REL_SUPER_USER}   || '',
    super_pass   => $ENV{OBJ_REL_SUPER_PASS}   || '',
    dsn          => $ENV{OBJ_REL_DSN}          || '',
    template_dsn => $ENV{OBJ_REL_TEMPLATE_DSN} || '',
);

use TEST::Class::Object::Relation 't/store';

TEST::Class::Object::Relation->runall;
