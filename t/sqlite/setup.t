#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 18;
use Test::NoWarnings; # Adds an extra test.
use Test::File;
use File::Spec;
use utf8;

BEGIN {
    use_ok 'Object::Relation::Setup::DB::SQLite' or die;
}

my $db_file = File::Spec->catfile(File::Spec->tmpdir, 'obj_rel.db');
END {
    unlink $db_file if -e $db_file;
}

##############################################################################
# Test the SQLite implementation.
ok my $setup = Object::Relation::Setup->new, 'Create a default Setup object';
ok $setup->class_dirs('t/sample/lib'), 'Set the class_dirs for the sample';

file_not_exists_ok $db_file, 'The database file should not yet exist';
ok $setup->setup, 'Set up the database';
file_exists_ok $db_file, 'The database file should now exist';

# Make sure that everything has been created.
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", '', '');
for my $view ( Object::Relation::Meta->keys ) {
    my $class = Object::Relation::Meta->for_key($view);
    my ($expect, $not) = $class->abstract
        ? ([], ' not')
        : ([[1]], '');
    is_deeply $dbh->selectall_arrayref(
        "SELECT 1 FROM sqlite_master WHERE type ='view' AND name = ?",
        {}, $view
    ), $expect, "View $view should$not exist";
}
$dbh->disconnect;
