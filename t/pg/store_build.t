#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use File::Spec;
use Test::More;

use lib 't/lib', '../../lib';
use Kinetic::Build;
use File::Spec;
use Cwd;

my ($TEST_LIB, $CLASS, $BUILD, $DB_NAME);

BEGIN {
#   use Carp; $SIG{__DIE__} = \&Carp::confess;
    $CLASS = 'Kinetic::Build::Store';
    chdir 't';
    chdir 'build_sample';
    $TEST_LIB = File::Spec->catfile(File::Spec->updir, 'lib');
    $DB_NAME = '__kinetic_test__';

    $BUILD = Kinetic::Build->new(
        module_name     => 'KineticBuildOne',
        conf_file       => 'test.conf', # always writes to t/ and blib/
        accept_defaults => 1,
        store           => 'pg',
        quiet           => 1,
        source_dir      => $TEST_LIB,
        db_name         => $DB_NAME,
        db_user         => $DB_NAME,
        db_pass         => $DB_NAME,
    );
    $BUILD->create_build_script;
    eval {$BUILD->dispatch('build')};
    if ($@) {
        plan skip_all => "Could not dispatch to build: $@";
    } else {
        plan tests    => 21;
    }

    $BUILD = Kinetic::Build->resume;
    $ENV{KINETIC_CONF} = File::Spec->catfile(qw/t conf test.conf/);
    use_ok $CLASS or die;
}

#use Kinetic::Util::Config;
can_ok $CLASS, 'new';
ok my $bstore = $CLASS->new, '... and calling it should succeed';
isa_ok $bstore, $CLASS, "... and the object it returns";
isa_ok $bstore, 'Kinetic::Build::Store::DB::Pg',
  '... and the object it returns';

can_ok $bstore, 'metadata';
ok my $metadata = $bstore->metadata, '... and calling it should succeed';
isa_ok $metadata, 'Kinetic::Build' => '... and the object it returns';
is_deeply $metadata, $BUILD,
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
    my @tables = map { $_->view } $schema->classes;

    can_ok $bstore, '_dbh';
    ok my $dbh = $bstore->_dbh, 'We should have a database handle';
    isa_ok $dbh, 'DBI::db' => '... and the handle';

    foreach my $table (@tables) {
        my $sql = "SELECT * FROM $table";
        eval {$dbh->selectall_arrayref($sql)};
        ok ! $@, "... and it should tell us that '$table' exists in the database";
    }
}

END {
    $BUILD->dispatch('realclean');
    $bstore->switch_to_db('template1');
    sleep 1; # Wait for the connection to close.
    my $dbh = $bstore->_dbh;
    $dbh->do(qq{DROP DATABASE "$DB_NAME"});
}
