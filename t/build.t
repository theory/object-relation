#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 51;
use Test::File;
use Test::File::Contents;
use lib 't/lib';
use TieOut;

BEGIN { use_ok 'Kinetic::Build' };

chdir 't';
chdir 'build_sample';

# First, tie off our file handles.
my $stdout = tie *STDOUT, 'TieOut' or die "Cannot tie STDOUT: $!\n";
my $stderr = tie *STDERR, 'TieOut' or die "Cannot tie STDERR: $!\n";
my $stdin = tie *STDIN, 'TieOut' or die "Cannot tie STDIN: $!\n";

# Make sure that inheritance is working properly for the property methods.
ok( Kinetic::Build->valid_property('accept_defaults'),
    "accept_defatuls is a valid property" );
ok( Kinetic::Build->valid_property('module_name'),
    "module_name is a valid property" );
ok my @props = Kinetic::Build->valid_properties,
  "Can get list of valid properties";
cmp_ok scalar @props, '>', 10, "Get all properties";
ok grep({ $_ eq 'accept_defaults' } @props),
  "accept_defaults is in the list of properties";

# Check default values of attributes.
ok my $build = Kinetic::Build->new( module_name => 'KineticBuildOne' ),
  "Create build object";
ok !$build->accept_defaults,
  "... The accept_defaults option should be false by default";
is $build->store, 'sqlite',
  '... The store attribute should default to "sqlite"';
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

ok $build = Kinetic::Build->new(
    module_name => 'KineticBuildOne',
    conf_file => 'test.conf',
    db_file   => 'test.db',
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

$build->dispatch('realclean');
file_not_exists_ok 't/conf/test.conf',
  '... The test config file should be gone';

{
    # Set up some parameters.
    local @ARGV = (
        '--accept_defaults' => 1,
        '--store'           => 'postgresql',
        '--db_name'         => 'wild',
        '--db_user'         => 'wild',
        '--db_pass'         => 'wild',
        '--db_host'         => 'db.example.com',
        '--db_port'         => '2222',
        '--db_file'         => 'wild.db',
        '--conf_file'       => 'test.conf',
    );

    ok $build = Kinetic::Build->new( module_name => 'KineticBuildOne' ),
      "Create another build object";
    ok $build->accept_defaults,
      "... The accept_defaults option should be true with --accept_defaults";
    is $build->store, 'postgresql',
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

    # Built it.
    $build->dispatch('build');
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

    $build->dispatch('realclean');
    file_not_exists_ok 'blib/conf/test.conf',
      '... There should no longer be a config file for installation';
}

END {
    # Clean up our mess.
    $build->dispatch('realclean') if -e 'Build'
}
