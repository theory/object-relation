#!/usr/bin/perl -w

# $Id$

use strict;
use Kinetic::Build;
use Test::More tests => 16;
#use Test::More 'no_plan';
use Test::MockModule;
use Test::Exception;
use DBI;

my $CLASS;
BEGIN { 
    $CLASS = 'Kinetic::Build::Rules::SQLite';
    use_ok $CLASS or die;
    chdir 't';
    chdir 'build_sample';
};

my $build = Kinetic::Build->new( 
    accept_defaults => 1,
    store           => 'sqlite',
    module_name     => 'KineticBuildOne',
);
my $dbh   = get_dbh($build);
$build->_dbh($dbh);

my $info = Test::MockModule->new($CLASS->info_class);
my @info_messages;
$info->mock('info', sub {push @info_messages => $_[1]} );

can_ok $CLASS, 'new';
my $rules = $CLASS->new($build);
isa_ok $rules, $CLASS => '... and the object returned';

cmp_ok @info_messages, '==', 1,
  '... and App::Info should generate one informational message';
like $info_messages[0], qr/Looking for SQLite/,
  '... telling us it is looking for SQLite';

can_ok $rules, 'build';
is $rules->build, $build,
  '... and it should return our build object';

can_ok $rules, 'info_class';
is $rules->info_class, 'App::Info::RDBMS::SQLite',
  '... and it should return the App::Info class';

can_ok $rules, 'info';
isa_ok $rules->info, 'App::Info::RDBMS::SQLite',
  '... and the object it returns';

my $mock_rules = Test::MockModule->new($CLASS);

@info_messages = ();
can_ok $rules, 'validate';

# test behavior if sqlite is not installed
$mock_rules->mock('_is_installed', sub {0});
throws_ok {$rules->validate}
    qr/SQLite does not appear to be installed/,
    '... and it should die if SQLite is not installed';

$mock_rules->mock('_is_installed', sub {1});
$mock_rules->mock('_is_required_version', sub {0});
throws_ok {$rules->validate}
    qr/SQLite is not the minimum required version/,
    '... or if SQLite is not the minumum supported version';

$mock_rules->mock('_is_required_version', sub {1});
my $mock_build = Test::MockModule->new('Kinetic::Build');
$mock_build->mock('prompt', sub {'fooness'});
$build->db_name('');

ok $rules->validate, 
  '... and it should return a true value if everything is ok';
is $build->db_name, 'fooness',
  '... and set the db_name correctly';

sub get_dbh {
    my $build = shift;
    foreach my $db_name (qw/kinetic/) {
        $build->db_name($db_name);

        my $dsn = $build->_dsn;
        my ($user, $pass) = ($build->db_user, $build->db_pass);
        my $dbh;
        eval {$dbh = DBI->connect($dsn, $user, $pass, {RaiseError => 1})};
        return $dbh;
    }
}
