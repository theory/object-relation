#!/usr/bin/perl -w

# $Id: store.t 3063 2006-07-21 23:07:19Z theory $

use warnings;
use strict;
use Test::File;

BEGIN {
    $ENV{KS_CLASS} = 'DB::SQLite';
    $ENV{KS_DSN}   = 'dbi:SQLite:dbname='
        . File::Spec->catfile(File::Spec->tmpdir, 'kinetic.db');
}

use lib qw(t/lib t/sample/lib);

use TEST::Kinetic::TestSetup (
    class => $ENV{KS_CLASS},
    dsn   => $ENV{KS_DSN},
);

use TEST::Class::Kinetic 't/store';

TEST::Class::Kinetic->runall;
