#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use File::Spec;
use Test::More tests => 21;
#use Test::More 'no_plan';

use lib 't/lib', '../../lib';
use Kinetic::Build;
use File::Spec;
use Cwd;

my ($TEST_LIB, $CLASS, $BUILD);

BEGIN { 
use Carp;
#    $SIG{__DIE__} = \&Carp::confess;
    $CLASS = 'Kinetic::Build::Store';
    chdir 't';
    chdir 'build_sample';
    $TEST_LIB = File::Spec->catfile(qw/.. lib/);

    # tell Kinetic::Build where to read the conf file
    Kinetic::Build
        ->new(module_name => 'KineticBuildOne')
        ->dispatch('realclean');
    
    $BUILD = Kinetic::Build->new( 
        module_name     => 'KineticBuildOne',
        conf_file       => 'test.conf', # always writes to t/ and blib/
        accept_defaults => 1,
        store           => 'pg',
        source_dir      => $TEST_LIB,
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
    my @tables = map { $_->table } $schema->classes;

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
}


__END__
#use Test::More tests => 13;
use Kinetic::Build::Test (
    store => { class   => 'Kinetic::Store::DB::Pg' },
    pg =>    { db_name => '__kinetic_test__' },
);

BEGIN {
    use_ok 'Kinetic::Build::Store'  or die;
    use_ok 'Kinetic::Build::Schema' or die;
};

ok my $store = Kinetic::Build::Store->new, "Load store builder";
isa_ok $store, 'Kinetic::Build::Store';
isa_ok $store, 'Kinetic::Build::Store::DB';
isa_ok $store, 'Kinetic::Build::Store::DB::Pg';

ok my $schema = Kinetic::Build::Schema->new, 'Get new Schema';
isa_ok $schema, 'Kinetic::Build::Schema';
isa_ok $schema, 'Kinetic::Build::Schema::DB';
isa_ok $schema, 'Kinetic::Build::Schema::DB::Pg';

# Build the schema.
ok $schema->load_classes('t/lib'), "Load classes";

# Build the store.
ok $store->build('t/lib'), "Build data store";

ok ! $@, '... and "use"ing the class should not die';
my @tables = map { $_->table } $schema->classes;

can_ok $store, '_dbh';
ok my $dbh = $store->_dbh, 'We should have a database handle';
isa_ok $dbh, 'DBI::db' => '... and the handle';

foreach my $table (@tables) {
    my $sql = "SELECT * FROM $table";
    eval {$dbh->selectall_arrayref($sql)};
    ok ! $@, "... and it should tell us that '$table' exists in the database";
}

##############################################################################
# Cleanup our mess.
#END { File::Path::rmtree(File::Spec->catdir(qw(t data))) }
