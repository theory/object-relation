#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
#use Test::More tests => 17;
use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.
use Test::Exception;
use aliased 'Test::MockModule';
use Kinetic::Store::Exceptions qw(throw_exlib);
use Test::File;
use utf8;

BEGIN {
    use_ok 'Kinetic::Store::Setup::DB::Pg' or die;
}

##############################################################################
# Test PostgreSQL implementation.
ok my $setup = Kinetic::Store::Setup::DB::Pg->new,
    'Create PostgreSQL setup object';

is $setup->user, 'kinetic', 'The username should be "kinetic"';
is $setup->pass, '', 'The password should be ""';
is $setup->dsn,  'dbi:Pg:dbname=kinetic',
    'The dsn should be "dbi:Pg:dbname=kinetic"';

is $setup->super_user,   'postgres', 'The superuser should be "postgres"';
is $setup->super_pass,   '', 'The superuser password should be ""';
is $setup->template_dsn, 'dbi:Pg:dbname=template1',
    'The template dsn should be "dbi:Pg:dbname=template1"';

ok $setup = Kinetic::Store::Setup::DB::Pg->new({
    user         => 'foo',
    pass         => 'bar',
    super_user   => 'hoo',
    super_pass   => 'yoo',
    dsn          => 'dbi:Pg:dbname=foo',
    template_dsn => 'dbi:Pg:dbname=template0',
}), 'Create PostgreSQL setup object with parameters';

is $setup->user, 'foo', 'The username should be "foo"';
is $setup->pass, 'bar', 'The password should be "bar"';
is $setup->dsn,  'dbi:Pg:dbname=foo',
    'The dsn should be "dbi:Pg:dbname=foo"';

is $setup->super_user,       'hoo', 'The superuser should be "hoo"';
is $setup->super_pass,       'yoo', 'The superuser password should be "yoo"';
is $setup->template_dsn, 'dbi:Pg:dbname=template0',
    'The template dsnshould be "dbi:Pg:dbname=template0"';

##############################################################################
# Test the setup rules.
ok $setup = Kinetic::Store::Setup::DB::Pg->new, 'Go back to the defaults';

#ok $setup = Kinetic::Store::Setup::DB::Pg->new({
#    user         => $ENV{KS_USER},
#    pass         => $ENV{KS_PASS},
#    super_user   => $ENV{KS_SUPER_USER},
#    super_pass   => $ENV{KS_SUPER_PASS},
#    dsn          => $ENV{KS_DSN},
#    template_dsn => $ENV{KS_TEMPLATE_DSN},
#}), 'Create PostgreSQL setup object with possible live parameters';

ok my $fsa = FSA::Rules->new($setup->rules), 'Create FSA::Rules machine';

# Mock the class.
my $mocker = MockModule->new('Kinetic::Store::Setup::DB::Pg');

##############################################################################
# Test "Start" and "Superuser Connects"
$mocker->mock(connect => sub {
    throw_exlib 'This is an error';
});

ok $fsa->start, 'Start machine';
is $fsa->curr_state->name, 'Start',
    'We should now be in the "Start" state';
is $fsa->curr_state->label, 'Can we connect as super user?',
    '... And it should have the proper label';

ok $fsa->switch, 'Switch to the next state';
my $prev = $fsa->prev_state;
ok my @errs = $prev->errors, '... There should be some errors';
is scalar @errs, 2, '... There should be two errors';
isa_ok $errs[0], 'Kinetic::Store::Exception::ExternalLib', '... The first';
isa_ok $errs[0], 'Kinetic::Store::Exception::ExternalLib', '... The second';
is $prev->message, 'No', '... And the message should be "No"';
ok !$fsa->notes('super'), '.. And the super note should be false';
ok !$fsa->notes('dsn'), '.. And the dsn note should be false';
is $fsa->curr_state->name, 'No Superuser',
    '... And we should be in the "No Superuser" state';

my $flag = 0;
$mocker->mock(connect => sub {
    return 1 if $flag++;
    throw_exlib 'This is an error';
});

# Try it with one error.
my $db_exists = 1;
$mocker->mock( _db_exists => sub { $db_exists });
my $plpgsql = 1;
$mocker->mock( _plpgsql_available => sub { $plpgsql });
my $can_create = 1;
$mocker->mock( _can_create_db => sub { $can_create });
my $user_exists = 1;
$mocker->mock( _user_exists => sub { $user_exists });
my $createlang = '/usr/local/pgsql/bin/createlang';
$mocker->mock( find_createlang => sub { $createlang });

ok $fsa->reset->curr_state('Start'), 'Reset to "Start" state';
ok $fsa->switch, 'Switch to the next state';
$prev = $fsa->prev_state;
ok !(@errs = $prev->errors), '... There should be no errors';
is $prev->message, 'Yes', '... And the message should be "Yes"';
ok $fsa->notes('super'), '.. And the super note should be true';
ok $fsa->notes('db_exists'), '... And the db_exists note should be true';
is $fsa->notes('dsn'), $setup->template_dsn,
    '.. And the dsn note should be set to the template DSN';

my $curr = $fsa->curr_state;
is $curr->name, 'Superuser Connects',
    'We should be in the "Superuser Connects" state';
ok $curr->result, '... And its result should be true';

# Try it with no errors.
my $connect_args;
my $connect_code = sub {
    shift;
    $connect_args = \@_;
    return 1;
};
$mocker->mock( connect => $connect_code );

ok $fsa->reset->curr_state('Start'), 'Reset to "Start" state';
ok $fsa->switch, 'Switch to the next state';
$prev = $fsa->prev_state;
ok !(@errs = $prev->errors), '... There should be no errors';
is $prev->message, 'Yes', '... And the message should be "Yes"';
ok $fsa->notes('super'), '.. And the super note should be true';
ok $fsa->notes('db_exists'), '... And the db_exists note should be true';
is $fsa->notes('dsn'), $setup->dsn,
    '.. And the dsn note should be set to the DSN';

$curr = $fsa->curr_state;
is $curr->name, 'Superuser Connects',
    '... And we should be in the "Superuser Connects" state';
ok $curr->result, '... And its result should be true';

##############################################################################
# Test "Superuser Connects".
my $create_db_args;
my $create_db_code = sub {
    shift;
    $create_db_args = \@_;
    return $setup;
};
$mocker->mock( create_db => $create_db_code);

ok $fsa->switch, 'Switch out of "Superuser Connects"';
is $fsa->prev_state->message, 'Yes', 'The message should be "Yes"';
ok $curr = $fsa->curr_state, 'Get the new current state';
is $curr->name, 'Database Exists', '... It should be "Database Exists"';

# Now make it switch to "Can Create Database".
$fsa->reset;
$fsa->notes( dsn => 'bwahaha' );
$fsa->notes( super => 1 );
$db_exists = 0;
ok $fsa->curr_state('Superuser Connects'), 'Reset to "Superuser Connects"';
is $fsa->curr_state->label, 'Does the database exist?',
    '... It should have the proper label';
ok $fsa->switch, 'Switch out of it';
is $fsa->prev_state->message, 'No', 'The message should be "No"';
ok !$fsa->notes('db_exists'), '... And the db_exists note should be false';
is $fsa->curr_state->name, 'Can Create Database',
    '... And now we should be in "Can Create Database"';

# Now make it switch to "No Database".
$fsa->notes( super => undef );
ok $fsa->curr_state('Superuser Connects'), 'Reset to "Superuser Connects"';
ok $fsa->switch, 'Switch out of it';
is $fsa->prev_state->message, 'No', 'The message should be "No"';
ok !$fsa->notes('db_exists'), '... And the db_exists note should be false';
is $fsa->curr_state->name, 'No Database',
    '... And now we should be in "No Database"';

##############################################################################
# Test "No Superuser"
$fsa->notes( super => undef );
$fsa->notes( dsn   => undef );
$mocker->mock(connect => sub {
    throw_exlib 'This is an error';
});

ok $fsa->curr_state('No Superuser'), 'Set state to "No Superuser"';
is $fsa->curr_state->label, 'Can we connect as the user?',
    '... It should have the proper label';
throws_ok { $fsa->switch } 'Kinetic::Store::Exception::Fatal::Setup',
    'We should get a setup exception when we switch';
is $@->error,
    'User “kinetic” cannot connect to either “dbi:Pg:dbname=kinetic” or '
    . '“dbi:Pg:dbname=template1”',
    '... And it should have the proper error message';

$curr = $fsa->curr_state;
is $curr->name, 'Fail', '... And we should now be in the "Fail" state';
$prev = $fsa->prev_state;
ok @errs = $prev->errors, '... There should be some errors';
is scalar @errs, 2, '... There should be two errors';
isa_ok $errs[0], 'Kinetic::Store::Exception::ExternalLib', '... The first';
isa_ok $errs[0], 'Kinetic::Store::Exception::ExternalLib', '... The second';
ok !$prev->result, '... And its result should be false';
is $prev->message, 'No', '... And the message should be "No"';
ok !$fsa->notes('super'), '.. And the super note should be false';
ok !$fsa->notes('dsn'), '.. And the dsn note should be false';

$flag = 0;
$mocker->mock(connect => sub {
    return 1 if $flag++;
    throw_exlib 'This is an error';
});

ok $fsa->reset->curr_state('No Superuser'), 'Reset state to "No Superuser"';
ok $fsa->switch, 'Switch states';
$curr = $fsa->curr_state;
is $curr->name, 'User Connects', 'We should now be in "User Connects"';
$prev = $fsa->prev_state;
ok !(@errs = $prev->errors), '... There should be no errors';
is $prev->message, 'Yes', '... And the message should be "Yes"';
ok !$fsa->notes('super'), '.. And the super note should be false';
is $fsa->notes('dsn'), $setup->template_dsn,
    '.. And the dsn note should be set to the template DSN';
ok $prev->result, '... And its result should be true';

# Try it with no errors.
$mocker->mock( connect => 1 );

ok $fsa->reset->curr_state('No Superuser'), 'Reset state to "No Superuser"';
ok $fsa->switch, 'Switch to the next state';
$prev = $fsa->prev_state;
$curr = $fsa->curr_state;
is $curr->name, 'User Connects',
    '... And we should be in the "User Connects" state';

ok !(@errs = $prev->errors), '... There should be no errors';
is $prev->message, 'Yes', '... And the message should be "Yes"';
ok !$fsa->notes('super'), '.. And the super note should be false';
is $fsa->notes('dsn'), $setup->dsn,
    '.. And the dsn note should be set to the production DSN';
ok $prev->result, '... And its result should be true';

##############################################################################
# Test Database Exists.
ok $fsa->reset->curr_state('Database Exists'),
    'Set state to "Database Exists"';

# Start with success for superuser.
$fsa->notes( super => 1 );
ok $fsa->switch, 'We should be able to switch to the next state';
is $fsa->curr_state->name, 'Database Has PL/pgSQL',
    '... And that state should be "Database Has PL/pgSQL"';
$prev = $fsa->prev_state;
is $prev->message, 'Yes', '... The message should be "Yes"';
ok $fsa->notes('plpgsql'), '... And the "plpgsql" note should be true';

# Go for success with the user.
ok $fsa->reset->curr_state('Database Exists'),
    'Reset state to "Database Exists"';
ok $fsa->switch, 'We should be able to switch to the next state';
is $fsa->curr_state->name, 'User Exists',
    '... And that state should be "User Exists"';
$prev = $fsa->prev_state;
is $prev->message, 'Yes', '... The message should be "Yes"';
ok $fsa->notes('plpgsql'), '... And the "plpgsql" note should be true';

# Go for failure with the user.
$plpgsql = 0;
ok $fsa->reset->curr_state('Database Exists'),
    'Reset state to "Database Exists"';
throws_ok { $fsa->switch } 'Kinetic::Store::Exception::Fatal::Setup',
    'We should get a setup exception when we switch';
is $@->error,
    'The “dbi:Pg:dbname=kinetic” database does not have PL/pgSQL and user '
    . '“kinetic” cannot add it',
    '... And it should have the proper error message';
$curr = $fsa->curr_state;
is $curr->name, 'Fail', '... And we should now be in the "Fail" state';
ok !$curr->result, '... And its result should be false';
ok !$fsa->notes('plpgsql'), '... And the "plpgsql" note should be false';
is $fsa->prev_state->message, 'No', '... And the message should be "No"';

# Go for failure with the super user.
ok $fsa->reset->curr_state('Database Exists'),
    'Reset state to "Database Exists"';
$fsa->notes( super => 1 );
ok $fsa->switch, 'We should be able to switch to the next state';
is $fsa->curr_state->name, 'No PL/pgSQL',
    '... And that state should be "No PL/pgSQL"';
$prev = $fsa->prev_state;
ok !$fsa->notes('plpgsql'), '... And the "plpgsql" note should be false';
is $prev->message, 'No', '... The message should be "Yes"';

##############################################################################
# Test No Database.
$mocker->mock( connect => $connect_code );
$fsa->reset;
$fsa->notes( super   => 1 );
$fsa->notes( plpgsql => 1 );
ok $fsa->curr_state('No Database'), 'Set state to "No Database"';
is $fsa->curr_state->label, 'So create the database.',
    '... The label should be correct';
ok $fsa->curr_state->result, '... The result should be true';
#is_deeply $connect_args, [
#    $setup->template_dsn,
#    $setup->super_user,
#    $setup->super_pass,
#], '... And the super user should have conncted to the template database';
is_deeply $create_db_args, [
    'kinetic'
], '... And the correct databse named should be passed to create_db()';

# Try with super user and plpgsql first.
ok $fsa->switch, 'We should be able to switch to the next state';
$curr = $fsa->curr_state;
is $curr->name, 'Database Has PL/pgSQL',
    '... And that state should be "Database Has PL/pgSQL"';

# Try with super user and no plpgsql.
ok $fsa->reset->curr_state('No Database'),
    'Reet state to "No Database"';
$fsa->notes( super   => 1 );
ok $fsa->switch, 'We should be able to switch to the next state';
$curr = $fsa->curr_state;
is $curr->name, 'Add PL/pgSQL',
    '... And that state should be "Add PL/pgSQL"';

# Try with production user and plpgsql.
ok $fsa->reset->curr_state('No Database'),
    'Reet state to "No Database"';
ok $fsa->switch, 'We should be able to switch to the next state';
$curr = $fsa->curr_state;
is $curr->name, 'User Exists',
    '... And that state should be "Add User Exists"';

# Try a fail.
$mocker->mock(create_db => sub {
    throw_exlib 'Whoops!';
});

throws_ok { $fsa->reset->curr_state('No Database') }
    'Kinetic::Store::Exception::ExternalLib',
    'We should get an error when appropriate';

##############################################################################
# Test User Connects.
$db_exists = 1;
ok $fsa->reset->curr_state('User Connects'), 'Set state to "User Connects"';
is $fsa->curr_state->label, 'Does the database exist?',
    '... The label should be correct';
ok $fsa->curr_state->result, '... The result should be true';

# Try switching with result true.
ok $fsa->switch, 'Switch states';
is $fsa->curr_state->name, 'Database Exists',
    '... And now the state should be "Database Exists"';

# Try switching with false result.
$db_exists = 0;
ok $fsa->reset->curr_state('User Connects'), 'Reset state to "User Connects"';
ok !$fsa->curr_state->result, '... The result should be false';
ok $fsa->switch, 'Switch states';
is $fsa->curr_state->name, 'No Database for User',
    '... And now the state should be "No Database for User"';

##############################################################################
# Test No Database for User
ok $fsa->reset->curr_state('No Database for User'),
    'Set state to "No Database for User"';
is $fsa->curr_state->label, 'Can we create a database?',
    '... The label should be correct';
ok $fsa->curr_state->result, '... The result should be true';
#is_deeply $connect_args, [
#    $setup->template_dsn,
#    $setup->user,
#    $setup->pass,
#], '... And the user should have conncted to the template database';

# Try switching with result true.
ok $fsa->switch, 'Switch states';
is $fsa->curr_state->name, 'Can Create Database',
    '... And now the state should be "Can Create Database"';

# Try switching with false result.
$can_create = 0;
ok $fsa->reset->curr_state('No Database for User'),
    'Reset state to "No Database for User"';
ok !$fsa->curr_state->result, '... The result should be false';
throws_ok { $fsa->switch } 'Kinetic::Store::Exception::Fatal::Setup',
    'We should get a setup exception when we switch';
is $@->error, 'User “kinetic” cannot create a database',
    '... And it should have the proper error message';
$curr = $fsa->curr_state;
is $curr->name, 'Fail', '... And we should now be in the "Fail" state';
$prev = $fsa->prev_state;
ok !$prev->result, q{... And the failed state's result should be false};
is $prev->message, 'No', '... And the message should be "No"';

##############################################################################
# Test Can Create Database.
$plpgsql = 1;
$mocker->mock( create_db => $create_db_code);

ok $fsa->reset->curr_state('Can Create Database'),
    'Set state to "Can Create Database"';
is $fsa->curr_state->label, 'Does the template database have PL/pgSQL?',
    '... The label should be correct';
ok $fsa->curr_state->result, '... The result should be true';

# Try switching with result true.
ok $fsa->switch, 'Switch states';
is $fsa->prev_state->message, 'Yes', '... And the message should be "Yes"';
is $fsa->curr_state->name, 'No Database',
    '... And now the state should be "No Database"';

# Try switching with super and result false.
$plpgsql = 0;
ok $fsa->reset->curr_state('Can Create Database'),
    'Reset state to "Can Create Database"';
$fsa->notes( super => 1 );
ok $fsa->switch, 'Switch states';
is $fsa->prev_state->message, 'No', '... And the message should be "No"';
is $fsa->curr_state->name, 'No PL/pgSQL',
    '... And now the state should be "No PL/pgSQL"';

# Try switching without super and result false.
ok $fsa->reset->curr_state('Can Create Database'),
    'Reset state to "Can Create Database"';
throws_ok { $fsa->switch } 'Kinetic::Store::Exception::Fatal::Setup',
    'We should get a setup exception when we switch';
is $@->error,
    'The “dbi:Pg:dbname=template1” database does not have PL/pgSQL and user '
    . '“kinetic” cannot add it',
    '... And it should have the proper error message';

$curr = $fsa->curr_state;
is $curr->name, 'Fail', '.. And we should now be in the "Fail" state';
$prev = $fsa->prev_state;
ok !$prev->result, q{... And the failed state's result should be false};
is $prev->message, 'No', '... And the message should be "No"';

##############################################################################
# Test Database Has PL/pgSQL
ok $fsa->reset->curr_state('Database Has PL/pgSQL'),
    'Set state to "Database Has PL/pgSQL"';
is $fsa->curr_state->label, 'Does the user exist?',
    '... The label should be correct';
ok $fsa->curr_state->result, '... The result should be true';

# Try switching with result true.
ok $fsa->switch, 'Switch states';
is $fsa->curr_state->name, 'User Exists',
    '... And now the state should be "User Exists"';
is $fsa->prev_state->message, 'Yes',
    '... And the previous state message should be "Yes"';

# Try switching with false result.
$user_exists = 0;
ok $fsa->reset->curr_state('Database Has PL/pgSQL'),
    'Reset state to "Database Has PL/pgSQL"';
ok !$fsa->curr_state->result, '... The result should be false';
ok $fsa->switch, 'Switch states';
is $fsa->curr_state->name, 'No User',
    '... And now the state should be "No User"';
is $fsa->prev_state->message, 'No',
    '... And the previous state message should be "No"';

##############################################################################
# Test No PL/pgSQL
ok $fsa->reset->curr_state('No PL/pgSQL'), 'Set state to "No PL/pgSQL"';
is $fsa->curr_state->label, 'So find createlang.',
    '... The label should be correct';
ok $fsa->curr_state->result, '... The result should be true';
is $fsa->notes('createlang'), $createlang,
    '... And the createlang note should be set';

# Try switching with result true and db_exists.
$fsa->notes( db_exists => 1 );
ok $fsa->switch, 'Switch states';
is $fsa->curr_state->name, 'Add PL/pgSQL',
    '... And now the state should be "Add PL/pgSQL"';
is $fsa->prev_state->message, 'Okay',
    '... And the previous state message should be "Okay"';

# Try switching with result true and no db_exists.
ok $fsa->reset->curr_state('No PL/pgSQL'), 'Reset state to "No PL/pgSQL"';
ok $fsa->switch, 'Switch states';
is $fsa->curr_state->name, 'No Database',
    '... And now the state should be "No Database"';
is $fsa->prev_state->message, 'Okay',
    '... And the previous state message should be "Okay"';

# Try switching without result false.
$createlang = undef;
ok $fsa->reset->curr_state('No PL/pgSQL'), 'Reset state to "No PL/pgSQL"';
throws_ok { $fsa->switch } 'Kinetic::Store::Exception::Fatal::Setup',
    'We should get a setup exception when we switch';
is $@->error, 'Cannot find createlang; is it in the PATH?',
    '... And it should have the proper error message';

$curr = $fsa->curr_state;
is $curr->name, 'Fail', '.. And we should now be in the "Fail" state';
$prev = $fsa->prev_state;
ok !$prev->result, q{... And the failed state's result should be false};
is $prev->message, 'Failed', '... And the message should be "Failed"';

