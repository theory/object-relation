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

# Try it with one error.
my $flag = 0;
$mocker->mock(connect => sub {
    return 1 if $flag++;
    throw_exlib 'This is an error';
});

my $fetch_args;
my $fetch_val = 1;
$mocker->mock(_fetch_value => sub {
    shift;
    $fetch_args = \@_;
    return $fetch_val;
});

ok $fsa->reset->curr_state('Start'), 'Reset to "Start" state';
ok $fsa->switch, 'Switch to the next state';
$prev = $fsa->prev_state;
ok !(@errs = $prev->errors), '... There should be no errors';
is $prev->message, 'Yes', '... And the message should be "Yes"';
ok $fsa->notes('super'), '.. And the super note should be true';
is $fsa->notes('dsn'), $setup->template_dsn,
    '.. And the dsn note should be set to the template DSN';

my $curr = $fsa->curr_state;
is $curr->name, 'Superuser Connects',
    'We should be in the "Superuser Connects" state';
ok $curr->result, '... And its result should be true';
is_deeply $fetch_args, [
    'SELECT datname FROM pg_catalog.pg_database WHERE datname = ?',
    'kinetic',
], '... And the correct arguments should have been passed to _fetch_value()';
$fetch_args = undef;

# Try it with no errors.
$mocker->mock( connect => 1 );

ok $fsa->reset->curr_state('Start'), 'Reset to "Start" state';
ok $fsa->switch, 'Switch to the next state';
$prev = $fsa->prev_state;
ok !(@errs = $prev->errors), '... There should be no errors';
is $prev->message, 'Yes', '... And the message should be "Yes"';
ok $fsa->notes('super'), '.. And the super note should be true';
is $fsa->notes('dsn'), $setup->dsn,
    '.. And the dsn note should be set to the DSN';

$curr = $fsa->curr_state;
is $curr->name, 'Superuser Connects',
    '... And we should be in the "Superuser Connects" state';
ok $curr->result, '... And its result should be true';
is $fetch_args, undef, '... And _fetch_value() should not have been called';

##############################################################################
# Test "Superuser Connects".
ok $fsa->switch, 'Switch out of "Superuser Connects"';
is $fsa->prev_state->message, 'Yes', 'The message should be "Yes"';
ok $curr = $fsa->curr_state, 'Get the new current state';
is $curr->name, 'Database Exists', '... It should be "Database Exists"';

# Now make it switch to "Can Create Database".
$fsa->notes(dsn => 'bwahaha');
$fetch_val = 0;
ok $fsa->curr_state('Superuser Connects'), 'Reset to "Superuser Connects"';
is $fsa->curr_state->label, 'Does the database exist?',
    '... It should have the proper label';
ok $fsa->switch, 'Switch out of it';
is $fsa->prev_state->message, 'No', 'The message should be "No"';
is $fsa->curr_state->name, 'Can Create Database',
    '... And now we should be in "Can Create Database"';

# Now make it switch to "No Database".
$fsa->notes( super => undef );
ok $fsa->curr_state('Superuser Connects'), 'Reset to "Superuser Connects"';
ok $fsa->switch, 'Switch out of it';
is $fsa->prev_state->message, 'No', 'The message should be "No"';
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
is $curr->name, 'No Superuser', 'We should still be in "No Superuser"';
ok @errs = $curr->errors, '... There should be some errors';
is scalar @errs, 2, '... There should be two errors';
isa_ok $errs[0], 'Kinetic::Store::Exception::ExternalLib', '... The first';
isa_ok $errs[0], 'Kinetic::Store::Exception::ExternalLib', '... The second';
is $curr->message, 'No', '... And the message should be "No"';
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

# Try it with no errors.
$mocker->mock( connect => 1 );
ok $fsa->reset->curr_state('No Superuser'), 'Reset state to "No Superuser"';

