#!/usr/bin/perl -w

# $Id$

use strict;
use Test::Exception;
use Test::MockModule;
#use Test::More 'no_plan';
use Test::More tests => 25;
use lib 't/lib', '../../lib';
use Kinetic::Build;
use File::Spec;
use Cwd;

my ($TEST_LIB, $CLASS, $BUILD);

BEGIN {
    $CLASS = 'Kinetic::Build::Store';
    chdir 't';
    chdir 'build_sample';
    $TEST_LIB = File::Spec->catfile(File::Spec->updir, 'lib');

    $BUILD = Kinetic::Build->new(
        module_name     => 'KineticBuildOne',
        conf_file       => 'test.conf', # always writes to t/ and blib/
        accept_defaults => 1,
        source_dir      => $TEST_LIB,
        quiet           => 1,
    );
    $BUILD->create_build_script;
    $BUILD->dispatch('build');

    $BUILD = Kinetic::Build->resume;
    $ENV{KINETIC_CONF} = File::Spec->catfile(qw/t conf test.conf/);
    use_ok $CLASS or die;
}

#use Kinetic::Util::Config;
can_ok $CLASS, 'new';
ok my $bstore = $CLASS->new, '... and calling it should succeed';
isa_ok $bstore, $CLASS, => "... and the object it returns";
isa_ok $bstore, 'Kinetic::Build::Store::DB::SQLite',
  '... and the object it returns';

can_ok $bstore, 'builder';
ok my $builder = $bstore->builder, '... and calling it should succeed';
isa_ok $builder, 'Kinetic::Build' => '... and the object it returns';
is_deeply $builder, $BUILD,
  '... and it should be the same data that Kinetic::Build->resume returns';

SKIP: {
    skip 'Bad store', undef unless $BUILD->notes('got_store');
    can_ok $bstore, 'build';
    ok $bstore->build, '... and calling it should succeed';

    can_ok $bstore, '_schema_class';
    my $schema_class = $bstore->_schema_class;
    eval "use $schema_class";
    ok ! $@, '... and "use"ing the class should not die';
    my $schema = $schema_class->new;
    $schema->load_classes($TEST_LIB);
    my @views = map { $_->key } $schema->classes;

    ok my $store = Kinetic::Store->new, 'Create Kinetic::Store object';
    isa_ok $store, 'Kinetic::Store';
    isa_ok $store, 'Kinetic::Store::DB';
    isa_ok $store, 'Kinetic::Store::DB::SQLite';
    can_ok $store, '_dbh';
    ok my $dbh = Kinetic::Store->new->_dbh, 'We should have a database handle';
    isa_ok $dbh, 'DBI::db' => '... and the handle';

    foreach my $table (@views) {
        my $sql = "SELECT * FROM $table";
        eval {$dbh->selectall_arrayref($sql)};
        ok ! $@, "... and it should tell us that '$table' exists in the database";
    }
}

END {
    $BUILD->dispatch('realclean');
}

