#!/usr/bin/perl -w

# $Id$

use strict;
use Test::MockModule;
#use Test::More 'no_plan';
use Test::More tests => 80;
use Test::File;
use Test::File::Contents;
use lib 't/lib';
use TieOut;

my $CLASS;
BEGIN { 
    $CLASS = 'Kinetic::Build';
    use_ok $CLASS or die;
};

chdir 't';
chdir 'build_sample';

# First, tie off our file handles.
my $stdout = tie *STDOUT, 'TieOut' or die "Cannot tie STDOUT: $!\n";
my $stdin  = tie *STDIN,  'TieOut' or die "Cannot tie STDIN: $!\n";

# Make sure that inheritance is working properly for the property methods.
ok( $CLASS->valid_property('accept_defaults'),
    "accept_defaults is a valid property" );
ok( $CLASS->valid_property('module_name'),
    "module_name is a valid property" );
ok my @props = $CLASS->valid_properties,
  "Can get list of valid properties";
cmp_ok scalar @props, '>', 10, "Get all properties";
ok grep({ $_ eq 'accept_defaults' } @props),
  "accept_defaults is in the list of properties";

# Check default values of attributes.
ok my $build = $CLASS->new( module_name => 'KineticBuildOne' ),
  "Create build object";
ok !$build->accept_defaults,
  "... The accept_defaults option should be false by default";
is $build->store, 'sqlite',
  '... The store attribute should default to "sqlite"';
is $build->_fetch_store_class, 'Kinetic::Store::DB::SQLite',
  '... The store class attribute should be correct';
is $build->db_name, 'kinetic',
  '... The db_name attribute should default to "kinetic"';
is $build->db_user, 'kinetic',
  '... The db_user attribute should default to "kinetic"';
is $build->db_pass, 'kinetic',
  '... The db_pass attribute should default to "kinetic"';
is $build->db_host, undef,
  '... The db_host attribute should be undef by default';
is $build->db_port, undef,
  '... The db_port attribute should be undef by default';
is $build->db_root_user, undef,
  '... The db_root_user attribute should be undefined by default';
is $build->db_root_pass, '',
  '... The db_root_pass attribute should be an empty string by default';
is $build->db_file, 'kinetic.db',
  '... The db_file should default to "kinetic.db"';
is $build->conf_file, 'kinetic.conf',
  '... The conf_file should default to "kinetic.conf"';

ok $build = $CLASS->new(
    module_name => 'KineticBuildOne',
    conf_file   => 'test.conf',
    db_file     => 'test.db',
),
  "Create a sample build object";
is $build->conf_file, 'test.conf',
  '... The conf_file should now be "test.conf"';

# Create the script file.
ok $build->create_build_script, "... The build script should be creatable"
  or diag $stdout->read;
ok $stdout->read, '... There should be output to STDOUT';

# Set up a response to the prompt (take the default).
# XXX This won't work on systems that don't have SQLite installed. Generalize
# for such cases later.
print STDIN "\n";
# Built it.
$build->dispatch('build');
# We should be prompted to confirm our choice.
ok my $out = $stdout->read, '... There should be output to STDOUT after build';
like $out, qr/Path to SQLite executable?/,
  '... There should be a prompt for SQLite.';

# We should have files for SQLite databases.
file_exists_ok 'blib/store/test.db',
  '... There should be a database file for installation';
file_exists_ok 't/store/test.db',
  '... There should be a database file for testing';

# We should have copies of the configuration file.
file_exists_ok 'blib/conf/test.conf',
  '... There should be a config file for installation';
file_exists_ok 't/conf/test.conf',
  '... There should be a config file for testing';
file_contents_like 'blib/conf/test.conf', qr/file\s+=>\s+'test\.db',/,
  '... The database file name should be set properly';
file_contents_like 'blib/conf/test.conf', qr/#\s*pg\s+=>\s+{/,
  '... The PostgreSQL section should be commented out.';
file_contents_like 'blib/conf/test.conf', qr/\n\s*store\s*=>\s*{\s*class\s*=>\s*'Kinetic::Store::DB::SQLite'/,
  '... The store should point to the correct data store';
$build->dispatch('realclean');
file_not_exists_ok 't/conf/test.conf',
  '... The test config file should be gone';

{
    # Set up some parameters.
    local @ARGV = (
        '--accept_defaults' => 1,
        '--store'           => 'pg',
        '--db_name'         => 'wild',
        '--db_user'         => 'wild',
        '--db_pass'         => 'wild',
        '--db_host'         => 'db.example.com',
        '--db_port'         => '2222',
        '--db_file'         => 'wild.db',
        '--conf_file'       => 'test.conf',
    );

    ok $build = $CLASS->new( module_name => 'KineticBuildOne' ),
      "Create another build object";
}

ok $build->accept_defaults,
  "... The accept_defaults option should be true with --accept_defaults";
is $build->store, 'pg',
  "... The store option can be specified on the command-line";
is $build->db_name, 'wild',
  '... The db_name attribute should be "wild"';
is $build->db_user, 'wild',
  '... The db_user attribute should be "wild"';
is $build->db_pass, 'wild',
  '... The db_pass attribute should be "wild"';
is $build->db_host, 'db.example.com',
  '... The db_host attribute should be "db.example.com"';
is $build->db_port, 2222,
  '... The db_port attribute should be 2222';
is $build->db_root_user, undef,
  '... The db_root_user attribute should be undefined';
is $build->db_root_pass, '',
  '... The db_root_pass attribute should be an empty string by default';
is $build->db_file, 'wild.db',
  '... The db_file attribute should be set to "wild.db"';
is $build->conf_file, 'test.conf',
  '... The conf_file attribute should be set to "test.conf"';
is $build->_fetch_store_class, 'Kinetic::Store::DB::Pg',
  '... The store class attribute should be correct';

# Build it.
my $module = newmock('DBI');
$module->mock('connect', sub {1});
my $mockclass = newmock($CLASS);
$mockclass->mock('check_pg', sub {1});
$build->dispatch('build');
undef $module;
undef $mockclass;
ok $stdout->read, '... There should be output to STDOUT after build';

# We should not have files for SQLite databases.
file_not_exists_ok 'blib/store/test.db',
  '... There should not be a database file for installation';
file_not_exists_ok 't/store/test.db',
  '... There should not be a database file for testing';

# We should have copies of the configuration file.
file_exists_ok 'blib/conf/test.conf',
  '... There should be a config file for installation';
file_exists_ok 't/conf/test.conf',
  '... There should be a config file for testing';
file_contents_like 'blib/conf/test.conf', qr/db_name\s+=>\s+'wild',/,
  '... The database name should be set properly';
file_contents_like 'blib/conf/test.conf', qr/#\s*sqlite\s+=>\s+{/,
  '... The SQLite section should be commented out.';
file_contents_like 'blib/conf/test.conf', qr/\n\s*store\s*=>\s*{\s*class\s*=>\s*'Kinetic::Store::DB::Pg'/,
  '... The store should point to the correct data store';
$build->dispatch('realclean');
file_not_exists_ok 'blib/conf/test.conf',
  '... There should no longer be a config file for installation';

{
    # Check SQLite installation.
    can_ok($CLASS, 'check_sqlite');
    $build = $CLASS->new(module_name => 'KineticBuildOne', accept_defaults => 1);

    my $sqlite = newmock('App::Info::RDBMS::SQLite');
    $sqlite->mock(installed => sub {0} );
    like checkstore($build),
      qr/SQLite is not installed./,
      '... and it should warn you if SQLite is not installed';

    $sqlite->mock(installed => sub { 1 });
    $sqlite->mock(version =>  sub { '2.0.0' });
    like checkstore($build),
      qr/SQLite version 2.0.0 is installed, but we need version .* or newer/,
      '... and it should warn you if SQLite is not a new enough version';

    $sqlite->mock(version => sub { 4.0 } );
    $sqlite->mock(executable => sub { 0 } );
    like checkstore($build),
      qr/DBD::SQLite is installed but we require the sqlite3 executable/,
      '... and it should warn you if the sqlite executable is not installed';

    $sqlite->mock(executable => sub {1} );
    ok(!checkstore($build),
       '... and if all parameters are correct, we should have no errors');
}

{
    # Check the PostgreSQL installation.
    can_ok($CLASS, 'check_pg');
    $build = $CLASS->new(
        accept_defaults => 1,
        module_name     => 'KineticBuildOne',
        store           => 'pg',
    );

    my $pg = newmock('App::Info::RDBMS::PostgreSQL');
    $pg->mock(installed => sub {0} );
    my $class = newmock($CLASS);
    like checkstore($build),
      qr/PostgreSQL is not installed./,
      '... and it should warn you if Postgres is not installed';

    $pg->mock(installed => sub { 1 } );
    $pg->mock(version => sub { '2.0.0' } );
    like checkstore($build),
        qr/PostgreSQL version 2.0.0 is installed, but we need version .* or newer/,
        '... and it should warn you if PostgreSQL is not a new enough version';

    $pg->mock(version => sub { '7.4.5' });
    $pg->mock(createlang => sub {''});
    like checkstore($build), qr/createlang must be available for plpgsql support/,
      '... and it should warn you if createlang is not available';

    $pg->mock(createlang => sub {1});
    $build->notes(got_store => 0);
    $build->db_root_user('');
    $class->mock(_connect_as_user => sub {0});
    like checkstore($build), qr/Can't connect as kinetic to template1.*/,
      'If we do not have a root user: it should warn us if the normal user cannot connect';

    # XXX Actually, if the db_name exists, the db_user should be able to connect to
    # it (no need to connect to template1). If db_name doesn't exist, then db_user
    # needs to be able to connect to template1 and must have permission to create
    # databases. If you attempt to connect to db_name, it will fail with 'database
    # "db_name" does not exist' even if db_user does not exist.

    $class->mock(_connect_as_user => sub {1});
    $class->mock(_db_exists => sub {0});
    $class->mock(_can_create_db => sub {0});
    like checkstore($build),
      qr/User kinetic does not have permission to create databases/,
      '... or if the normal user does not have permission to create databases';

    $class->mock(_can_create_db => sub {1});
    ok !checkstore($build),
      '... but we should have no error messages if normal user can create the db';

    $build->notes(got_store => 0);
    $build->db_root_user('postgres');
    $class->mock(_connect_as_root => sub {0});
    like checkstore($build), qr/Can't connect as postgres to template1/,
        'If we have a root user, we should die if they cannot connect';

    # XXX Actually, if the db_name exists, the db_root_user should be able to
    # connect to it (no need to connect to template1). If db_name doesn't exist,
    # then db_root_user needs to be able to connect to template1 and must have
    # permission to create databases.

    $class->mock(_connect_as_root => sub {1});
    $class->mock(_is_root_user => sub {0});
    like checkstore($build), qr/We thought postgres was root, but it is not/,
      '... and we should die if the root user is not really the root user';

    $class->mock(_is_root_user => sub {1});
    $class->mock(_db_exists => sub {0});
    $class->mock(_can_create_db => sub {0});
    like checkstore($build),
      qr/User postgres does not have permission to create databases/,
      '... or if they do not have permission to create databases';

    $class->mock(_db_exists => sub {1});
    $class->mock(_user_exists => sub {0});
    ok !checkstore($build), '... if the user does not exist, we should not die';
    is $build->notes('default_user'), 'kinetic does not exist',
      '... but the notes should let us know';

    $build->notes(default_user => '');
    $class->mock(_user_exists => sub {1});
    ok !checkstore($build), '... and the build should complete without error';
    ok !$build->notes('default_user'),
      '... but if the user exists, we should not have notes';
    # XXX We should verify the contents of the notes, I think.
}

can_ok $build, '_dsn';
$build->db_name('foobar');
$build->db_host(undef);
$build->db_port(undef);
is $build->_dsn, 'dbi:Pg:dbname=foobar',
    '... and it should return a proper dsn';
$build->db_host('somehost');
is $build->_dsn, 'dbi:Pg:dbname=foobar;host=somehost',
    '... and properly handle an optional host';
$build->db_port(2323);
is $build->_dsn, 'dbi:Pg:dbname=foobar;host=somehost;port=2323',
    '... and properly handle an optional port';

$build->db_port('foo');
eval {$build->_dsn};
like $@, qr/The database port must be a numeric value/,
  '... and die us if we have an invalid port';

$build->db_port(undef);
$build->db_name(undef);
eval {$build->_dsn};
like $@, qr/Cannot create dsn without a db_name/,
  '... and die us if we do not have a db_name';
  
sub checkstore {
    my $mock = newmock($CLASS);
    my $error;
    $mock->mock(_fatal_error => sub { shift; $error = join '' => @_; die });
    eval { local $^W; shift->ACTION_check_store };
    return $error;
}

sub newmock { Test::MockModule->new(shift) }

END {
    # Clean up our mess.
    $build->dispatch('realclean') if -e 'Build'
}
