#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 83;
#use Test::More 'no_plan';
use Test::MockModule;
use Test::Exception;

use lib 't/lib', '../../lib';
use Kinetic::Build;
use File::Spec;
use Cwd;
use FSA::Rules;
use Clone;

my ($TEST_LIB, $CLASS, $BUILD, $BUILD_CLASS);

BEGIN {
    $CLASS = 'Kinetic::Build::Rules::Pg';
    $BUILD_CLASS = 'Kinetic::Build::Store::DB::Pg';
    chdir 't';
    chdir 'build_sample';
    $TEST_LIB = File::Spec->catfile(qw/.. lib/);

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
    use_ok $CLASS       or die;
    use_ok $BUILD_CLASS or die;
}

can_ok $CLASS, 'new';
ok my $rules = $CLASS->new($BUILD), '... and calling it should succeed';
isa_ok $rules, $CLASS, => "... and the object it returns";

can_ok $rules, '_state_machine';
my $machine = $rules->_state_machine;
is ref $machine, 'ARRAY', '... and it should return an array ref';
is @$machine %2, 0, '... with an even number of elements';

if (0) {
    my $machine2 = Clone::clone($machine);
    my $temp = FSA::Rules->new(@$machine2);
    $temp->graph(
        {
            wrap_labels => 1,
        }, 
        concentrate => 1,
        bgcolor     => 'Wheat',
    )->as_png('new_pg_rules.png');
}

my %state_tests = (
    Start                                         => \&start,
    "Determine user"                              => \&determine_user,
    "Check for user db and is root"               => \&check_for_user_db,
    "Check user db for plpgsql"                   => \&check_user_db_for_plpgsql,
    "Check template1 for plpgsql and is root"     => \&check_template1_for_plpgsql_and_is_root,
    "Check user create permissions"               => \&check_user_create_permissions,
    "Check template1 for plpgsql and is not root" => \&check_template1_for_plpgsql,
    "Check for user db and is not root"           => \&check_if_user_db_exists,
    "Check for createlang"                        => \&check_for_createlang,
    Fail                                          => \&Fail, 
    Done                                          => \&Done,
);

while (my ($state, $definition) = splice @$machine => 0, 2) {
    my $test = $state_tests{$state};
    die "unknown state $state" unless defined $test;
    $test->($state, $definition);
}

sub start {
    my ($state, $definition) = @_;
    my $machine = FSA::Rules->new(
        $state    => $definition,
        Fail      => {},
        "Determine user" => {},
    );
    my $module = Test::MockModule->new($CLASS);
    $module->mock(_is_installed => 0);
    $machine->start;
    $machine->switch until $machine->at('Fail');
    is ref $machine->{actions}, 'ARRAY',
      qq'"$state" should create an actions array';
    is @{$machine->{actions}}, 0, '... and it should be empty';

    is $machine->{db_name}, 'template1',
      '... and the default template name should be set';
    is $BUILD->notes('kinetic_db_name'), 'kinetic',
      '... and the notes should tell us the user\'s db_name';
    my $stacktrace = $machine->raw_stacktrace;
    is @$stacktrace, 2,
      '... and the should only have two states in the trace';
    is_deeply [map {$_->[0]} @$stacktrace], [qw/Start Fail/],
      '... and they should be the correct states';

    $module->mock(_is_installed => 1);
    $machine->reset->curr_state('Start');
    $machine->switch until $machine->at('Determine user');
    is ref $machine->{actions}, 'ARRAY', '... and we should have an actions array';
    is @{$machine->{actions}}, 0, '... and it should be empty';

    is $machine->{db_name}, 'template1',
      '... and the default template name should be set';
    is $BUILD->notes('kinetic_db_name'), 'kinetic',
      '... and the notes should tell us the user\'s db_name';
    $stacktrace = $machine->raw_stacktrace;
    is @$stacktrace, 2,
      '... and the should only have two states in the trace';
    is_deeply [map {$_->[0]} @$stacktrace], ["Start", "Determine user"],
      '... and they should be the correct states';
}

sub determine_user {
    my ($state, $definition) = @_;
    my $is_root_state  = "Check for user db and is root";
    my $not_root_state = "Check for user db and is not root";
    my $machine = FSA::Rules->new(
        $state    => $definition,
        Fail      => { do => sub { die shift->prev_state->message } },
        $is_root_state  => {},
        $not_root_state => {},
    );
    my $module = Test::MockModule->new($CLASS);
    $module->mock(_connect_to_pg => 0);
    $machine->start;
    throws_ok { $machine->switch }
      qr/Need root user or db user to build database/,
      qq/"$state" should fail if it cannot connect to the databse/;

    my ($self, $template, $user, $pass);
    $module->mock(_connect_to_pg => sub {
        ($self, $template, $user, $pass) = @_;
        return $user eq 'postgres'; # true for root user
    });
    $machine->reset->curr_state($state);
    $machine->switch until $machine->at($is_root_state);
    is $machine->states($state)->result, 'can_use_root',
      '... but it should succeed if we can connect with the root user';
    is $machine->{user}, $user,
      '... and set the machine user correctly';
    is $machine->{pass}, $pass,
      '... and set the machine pass correctly';
    ok $machine->{is_root},
      '... and add a note that it is operating as the root user';
    
    $module->mock(_connect_to_pg => sub {
        ($self, $template, $user, $pass) = @_;
        return $user eq 'kinetic';
    });
    $machine->reset->curr_state($state);
    $machine->switch until $machine->at($not_root_state);
    is $machine->states($state)->result, 'can_use_db_user',
      '... but it should succeed if we can connect with the normal user';
    is $machine->{user}, $user,
      '... and set the machine user correctly';
    is $machine->{pass}, $pass,
      '... and set the machine pass correctly';
    ok ! $machine->{is_root},
      '... and add a note that it is not operating as the root user';
}

sub check_template1_for_plpgsql {
    my ($state, $definition) = @_;
    my $machine = FSA::Rules->new(
        $state => $definition,
        Fail   => { do => sub { die shift->prev_state->message } },
        Done   => {},
    );
    my $module = Test::MockModule->new($CLASS);
    $module->mock(_plpgsql_available => 0);
    $machine->{db_name} = 'no such db';
    $machine->start;
    throws_ok { $machine->switch }
      qr/Panic state.  Cannot check template1 for plpgsql if we're not connected to it./,
      qq/"$state" should fail if we are not connected to it/;

    $machine->reset;
    $machine->curr_state($state);
    $machine->{db_name} = 'template1';
    throws_ok { $machine->switch }
      qr/Template1 does not have plpgsql/,
      '... and it should fail if we do not have plpgsql available';
    
    $module->mock(_plpgsql_available => 1);
    $machine->reset;
    $machine->{db_name} = 'template1';
    $machine->curr_state($state);
    $machine->switch until $machine->at('Done');
    ok $machine->states($state)->result,
      '... but we should not fail if plpgsql is available';
}

sub check_if_user_db_exists {
    my ($state, $definition) = @_;
    my $db_exists_state     = "Check user db for plpgsql";
    my $not_db_exists_state = "Check template1 for plpgsql and is not root";
    my $machine = FSA::Rules->new(
        $state    => $definition,
        Fail      => { do => sub { die shift->prev_state->message } },
        $db_exists_state  => {},
        $not_db_exists_state => {},
    );
    my $module = Test::MockModule->new($CLASS);
    $module->mock(_db_exists     => 0);
    $module->mock(_can_create_db => 0);
    $machine->start;
    throws_ok { $machine->switch }
      qr/No database, and user has no permission to create it/,
      qq/"$state" should fail if we cannot find or create the use database/;

    $module->mock(_can_create_db => 1);
    $machine->reset->curr_state($state);
    $machine->switch until $machine->at($not_db_exists_state); 
    is $machine->states($state)->result, 'user can create database',
      '... but it should not fail if the database does not exist and the user can create it';
    my $actions = $machine->{actions};
    is @$actions, 1, '... and there should be one action cached';
    is_deeply $actions->[0], ['create_db', 'kinetic'],
      '... telling us to create the user database';
    
    $module->mock(_db_exists => 1);
    $machine->reset->curr_state($state);
    $machine->switch until $machine->at($db_exists_state); 
    is $machine->states($state)->result, 'database exists',
      '... but it should not fail if the database exists';
    $actions = $machine->{actions};
    is @$actions, 0, '... and no actions should need to be performed';
}

sub check_for_user_db {
    my ($state, $definition) = @_;
    my $db_exists_state     = "Check user db for plpgsql";
    my $not_db_exists_state = "Check template1 for plpgsql and is root";
    my $machine = FSA::Rules->new(
        $state    => $definition,
        Fail      => { do => sub { die shift->prev_state->message } },
        $db_exists_state  => {},
        $not_db_exists_state => {},
    );
    my $module = Test::MockModule->new($CLASS);
    $module->mock(_db_exists     => 0);
    $machine->start;
    $machine->switch until $machine->at($not_db_exists_state);
    ok ! $machine->states($state)->result,
      qq'"$state" result should be false if the user db does not exist';
    ok exists $machine->{database_exists},
      '... and the scratchpad should have a note about the db existence';
    ok ! $machine->{database_exists},
      '... and it should have a false value';
    my $actions = $machine->{actions};
    is @$actions, 2, '... and we should have two actions';
    is_deeply $actions, [
        ['create_db',    'kinetic'],
        ['switch_to_db', 'kinetic'],
    ], '... telling us to create the user db and then connect to it.';
    foreach my $action (map {$_->[0]} @$actions) {
        can_ok $BUILD_CLASS, $action;
    }

    $module->mock(_db_exists => 1);
    $machine->reset->curr_state($state);
    $machine->switch until $machine->at($db_exists_state);
    ok $machine->states($state)->result,
      qq'"$state" result should be true if the user db exists';
    ok exists $machine->{database_exists},
      '... and the scratchpad should have a note about the db existence';
    ok $machine->{database_exists},
      '... and it should have a true value';
    $actions = $machine->{actions};
    is @$actions, 1, '... and we should have one action';
    is_deeply $actions, [
        ['switch_to_db', 'kinetic'],
    ], '... telling us to connect to the user db.';
    foreach my $action (map {$_->[0]} @$actions) {
        can_ok $BUILD_CLASS, $action;
    }
}

sub check_user_db_for_plpgsql {
    my ($state, $definition) = @_;
use Clone;
    my $def2 = Clone::clone($definition);
    my $createlang_state = "Check for createlang";
    my $permissive_state = "Check user create permissions";
    my $machine = FSA::Rules->new(
        $state            => $definition,
        Fail              => { do => sub { die shift->prev_state->message } },
        Done              => {},
        $createlang_state => {},
        $permissive_state => {},
    );
    my $module = Test::MockModule->new($CLASS);
    $module->mock(_connect_to_db     => 1);
    $module->mock(_plpgsql_available => 0);
    $machine->{is_root} = 0;
    $machine->start;
    throws_ok {$machine->switch}
      qr/Database does not have plpgsql and not root/,
      qq/"$state" cannot add plpgsql unless using the root user/;

    $machine->reset;
    $machine->{is_root} = 1;
    $machine->curr_state($state);
    until ($machine->at($createlang_state)) {
        $machine->switch; # until $machine->at($createlang_state);
    }
    ok ! $machine->states($state)->result,
      qq/"$state" result should be false if plpgsql is not installed/;;
    my $actions = $machine->{actions};
    is @$actions, 1, '... and there should be one action';
    is_deeply $actions->[0], ['add_plpgsql_to_db', 'kinetic'],
      '... telling us to add plpgsql to the user db';
    foreach my $action (map {$_->[0]} @$actions) {
        can_ok $BUILD_CLASS, $action;
    }
}

sub Done {
    my ($state, $definition) = @_;
    my $machine = FSA::Rules->new(
        faux_state => { 
            rules => [ Done => 1 ]
        },
        $state     => $definition,
    );

    my $disconnect = 0;
    my $dbi   = Test::MockModule->new('DBI');
    $dbi->mock(disconnect => sub { $disconnect = 1 } );
    my $rules = Test::MockModule->new($CLASS);
    $rules->mock(_dbh => sub { bless {} => 'DBI' });
    
    @{$machine}{qw/user pass db_name/} = qw/ovid divo rome/;
    $machine->start;
    $machine->switch;
    my $actions = $machine->{actions};
    is @$actions, 1,
      qq/"$state" should set an action if the user database does not exist/;
    is $actions->[0][0], 'build_db',
      '... telling us to build the user database';
    foreach my $action (map {$_->[0]} @$actions) {
        can_ok $BUILD_CLASS, $action;
    }
    is $BUILD->notes('stacktrace'), $machine->stacktrace,
      '... and the stacktrace should be copied to the build object';
    foreach my $attribute (qw/actions user pass db_name/) {
        is_deeply $BUILD->notes($attribute), $machine->{$attribute},
          "... and '$attribute' should be copied from the machine to the build notes";
    }
    ok $disconnect, '... and we should disconnect from the db if connected';

    $machine->reset;
    $machine->{database_exists} = 1;
    $machine->curr_state('faux_state');
    $machine->switch;
    $actions = $machine->{actions};
    ok ! $actions, '... but we should not be told to build the user db if it exists';
}

sub Fail {
    my ($state, $definition) = @_;
    my $def2 = Clone::clone($definition);
    my $machine = FSA::Rules->new(
        faux_state => { rules => [ Fail => 1 ] },
        $state     => $definition,
    );
    $machine->start;
    throws_ok { $machine->switch }
      qr/no message supplied/,
      qq'"$state" should die with an appropriate message';

    $machine = FSA::Rules->new(
        faux_state => {
            do    => sub { shift->message('foo bar baz') },
            rules => [ Fail => 1 ] 
        },
        $state     => $def2,
    );
    $machine->start;
    throws_ok { $machine->switch }
      qr/foo bar baz/,
      qq'... and it should capture the previous state message, if available';
}

sub check_user_create_permissions {
    my ($state, $definition) = @_;
    my $machine = FSA::Rules->new(
        $state => $definition,
        Fail   => { do => sub { die shift->prev_state->message } },
        Done   => {},
    );
    my $module = Test::MockModule->new($CLASS);
    $module->mock(_has_create_permissions => 0);
    $machine->start;
    throws_ok {$machine->switch}
      qr/User does not have permission to add objects to database/,
      qq'"$state"should fail if the user cannot add objects to the database';
    $module->mock(_has_create_permissions => 1);
    $machine->reset->curr_state($state);
    $machine->switch until $machine->at('Done');
    ok $machine->states($state)->result,
      '... but it should get to "Done" if the user can add objects';
}

sub check_template1_for_plpgsql_and_is_root {
    my ($state, $definition) = @_;
    my $machine = FSA::Rules->new(
        $state => $definition,
        Fail   => { do => sub { die shift->prev_state->message } },
        Done   => {},
    );
    $machine->{db_name} = 'kinetic';
    my $info = Test::MockModule->new('App::Info::RDBMS::PostgreSQL');
    $info->mock(createlang => 0);
    my $module = Test::MockModule->new($CLASS);
    $module->mock(_plpgsql_available => 0);
    $machine->start;
    throws_ok {$machine->switch}
      qr/Panic state.  Cannot check template1 for plpgsql if we're not connected to it/,
      qq/"$state" should panic if we're not connected to template1/;

    $machine->reset;
    $machine->{db_name} = 'template1';
    $machine->curr_state($state);
    throws_ok {$machine->switch}
      qr/Template1 does not have plpgsql and we do not have createlang/,
      qq/... and it should fail if we don't have either plpgsql or createlang/;

    $info->mock(createlang => 1);
    $machine->reset;
    $machine->{db_name} = 'template1';
    $machine->curr_state($state);
    $machine->switch;
    is $machine->states($state)->result, 'No plpgsql but we have createlang',
      '... and we should not die if we have no plpgsql but we do have createlang';
    my $actions = $machine->{actions};
    is @$actions, 1, '... and we should have one action';
    is_deeply $actions->[0], ['add_plpgsql_to_db', 'template1'],
      '... tellling us to add plpgsql to template1';
    foreach my $action (map {$_->[0]} @$actions) {
        can_ok $BUILD_CLASS, $action;
    }
    $module->mock(_plpgsql_available => 1);
    $machine->reset;
    $machine->{db_name} = 'template1';
    $machine->curr_state($state);
    $machine->switch;
    is $machine->states($state)->result, 'template1 has plpgsql',
      qq/"$state" should succeed if template1 has plpgsql/;
    ok ! $machine->{actions}, '... and we should have no actions to perform';
}

sub check_for_createlang {
    my ($state, $definition) = @_;
    my $machine = FSA::Rules->new(
        $state => $definition,
        Fail   => { do => sub { die shift->prev_state->message } },
        Done   => {},
    );
    $BUILD->db_name('kinetic'); # gets set by the state before this
    my $module = Test::MockModule->new('App::Info::RDBMS::PostgreSQL');
    $module->mock(createlang => 0);
    $machine->start;
    throws_ok {$machine->switch}
      qr/Must have createlang to add plpgsql/,
      "\"$state\" should fail if createlang cannot be found";
    
    $module->mock(createlang => 1);
    $machine->reset->curr_state($state);
    $machine->switch until $machine->at('Done');
    ok $machine->states($state)->result,
      '... but if we have createlang it should succeed';
    my $actions = $machine->{actions};
    is @$actions, 1, '... and we should have a new action added';
    is_deeply $actions->[0], [qw/add_plpgsql_to_db kinetic/],
      '... telling us to add plpgsql to the user db';
    foreach my $action (map {$_->[0]} @$actions) {
        can_ok $BUILD_CLASS, $action;
    }
}
