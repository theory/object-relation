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
    store           => 'pg',
    module_name     => 'KineticBuildOne',
);
my $dbh   = get_dbh($build);

plan $dbh
    #? 'no_plan'
    ? (tests => 12)
    : (skip_all => 'Could not connect to postgres');
$build->_dbh($dbh);

can_ok $build, '_user_exists';
my $users = $dbh->selectcol_arrayref("select usename from pg_catalog.pg_user");
my $unknown_user = make_not_in($users);
ok $build->_user_exists($users->[0]),
  '... and it should return true for existing users';
ok ! $build->_user_exists($unknown_user),
  '... and false for non-existing users';

can_ok $build, '_is_root_user';
$users = $dbh->selectcol_arrayref("select usename from pg_catalog.pg_user where usesuper is true");
my $non_root_user = make_not_in($users);
ok $build->_is_root_user($users->[0]),
  '... and it should return true for root users';
ok ! $build->_is_root_user($non_root_user),
  '... and false for non-root users';

can_ok $build, '_can_create_db';
$users = $dbh->selectcol_arrayref("select usename from pg_catalog.pg_user where usecreatedb is true");
my $cannot_create_db = make_not_in($users);
ok $build->_can_create_db($users->[0]),
  '... and it should return true if the user can create databases';
ok ! $build->_can_create_db($cannot_create_db),
  '... and false if they cannot';

can_ok $build, '_db_exists';
my $databases = $dbh->selectcol_arrayref("select datname from pg_catalog.pg_database");
my $non_existent_database = make_not_in($databases);
my $db_name = $build->db_name;
$build->db_name($databases->[0]);
ok $build->_db_exists,
  '... and it should return true if the database exists';

$build->db_name($non_existent_database);
ok !$build->_db_exists,
  '... and false if it does not';
$build->db_name($db_name);

sub make_not_in {
    my $arrayref = shift;
    my %element  = map { $_ => 1 } @$arrayref;
    my $not_in   = $arrayref->[0];
    $not_in++ while exists $element{$not_in};
    return $not_in;
}

sub get_dbh {
    my $build = shift;
    foreach my $db_name (qw/template1 kinetic/) {
        $build->db_name($db_name);

        my $dsn = $build->_dsn;
        my ($user, $pass) = ($build->db_user, $build->db_pass);
        my $dbh;
        eval {$dbh = DBI->connect($dsn, $user, $pass, {RaiseError => 1})};
        return $dbh if $dbh;
        Diag "First connection attempt failed: $@" unless $dbh;
        
        ($user, $pass) = ($build->db_root_user, $build->db_root_pass);
        $user ||= 'postgres';
        eval {$dbh = DBI->connect($dsn, $user, $pass, {RaiseError => 1})};
        return $dbh if $dbh;
        Diag "Second connection attempt failed: $@" unless $dbh;
            
        unless ('postgres' ne $user) {
            $user = 'postgres';
            $pass = ''; # frequently not required when connecting locally;
            eval {$dbh = DBI->connect($dsn, $user, $pass, {RaiseError => 1})};
            return $dbh if $dbh;
            Diag "Third connection attempt failed: $@" unless $dbh;
        }
    }
    return $dbh;
}

sub Diag {
    diag @_ if $ENV{DEBUG};
}
