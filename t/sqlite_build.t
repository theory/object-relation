#!/usr/bin/perl -w

# $Id$

use strict;
use Kinetic::Build;
use DBI;

sub Diag;

my $CLASS = 'Kinetic::Build';
BEGIN { 
    chdir 't';
    chdir 'build_sample';
};
use Test::More;

my $build = $CLASS->new( 
    accept_defaults => 1,
    store           => 'sqlite',
    module_name     => 'KineticBuildOne',
);
my $dbh;
eval{ $dbh = DBI->connect($build->_dsn, '', '') };

plan $dbh
    ? 'no_plan'
    #? (tests => 1)
    : (skip_all => 'Cannot connect to SQLite');
$build->_dbh($dbh);
ok(1);
