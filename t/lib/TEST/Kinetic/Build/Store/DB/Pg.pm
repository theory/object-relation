package TEST::Kinetic::Build::Store::DB::Pg;

# $Id$

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Store::DB';
use Test::More;
use aliased 'Test::MockModule';
use aliased 'Kinetic::Build';
use Test::Exception;
use File::Spec::Functions;
use Test::File;

__PACKAGE__->runtests;

sub test_class_methods : Test(7) {
    my $test = shift;
    my $class = $test->test_class;
    is $class->info_class, 'App::Info::RDBMS::PostgreSQL',
      'We should have the correct App::Info class';
    is $class->min_version, '7.4.5',
      'We should have the correct minimum version number';
    is $class->max_version, 0,
      'We should have the correct maximum version number';
    is $class->schema_class, 'Kinetic::Build::Schema::DB::Pg',
      'We should have the correct schema class';
    is $class->store_class, 'Kinetic::Store::DB::Pg',
      'We should have the correct store class';
    is $class->dbd_class, 'DBD::Pg',
      'We should have the correct DBD class';
    is $class->dsn_dbd, 'Pg',
      'We should have the correct DSN DBD string';
}

sub test_rules : Test(159) {
    my $self = shift;
    my $class = $self->test_class;

    # Override builder methods to keep things quiet.
    my $mb = MockModule->new(Build);
    $mb->mock(check_manifest => sub { return });
    my $builder = $self->new_builder;
    $mb->mock(resume => $builder);
    $mb->mock(_app_info_params => sub { } );
    my (@replies, @args);
    $mb->mock(get_reply => sub { shift @replies });
    $mb->mock(args => sub { shift @args });

    # Construct the object.
    ok my $kbs = $class->new, "Create new $class object";
    isa_ok $kbs, $class;

    # Construct a rules object.
    ok my $fsa = FSA::Rules->new($kbs->rules), "Create FSA::Rules machine";

    ##########################################################################
    # Test "Start"
    ok $fsa->start, "Start machine";

    # Test behavior if PostgreSQL is not installed
    my $info = MockModule->new($class->info_class);
    $info->mock(installed => 0);
    throws_ok { $fsa->switch } qr/Cannot find PostgreSQL/,
      'It should die if PostgreSQL is not installed';

    ##########################################################################
    # Test "Check version"
    # Now successfully find PostgreSQL.
    $info->mock(installed => 1);
    ok $fsa->reset->start, 'Reset the machine';
    ok $fsa->switch, "We should now be able to switch";
    is $fsa->curr_state->name, 'Check version',
      'Now we should be in the "Check version" state';

    # Test behavior of it's the wrong version of PostgreSQL.
    $info->mock(version => '2.0');
    throws_ok { $fsa->switch } qr'PostgreSQL is the wrong version',
      'It should die with the wrong version';

    # Set up the proper version number.
    $info->mock(version => '7.4.5');
    ok $fsa->reset->curr_state('Check version'), 'Set up check version again';
    # Set up replies for the server info state, to which we'll be switching.
    #           db_host      db_port db_name    db_user    db_pass
    @replies = ('localhost', '5432', 'fooness', 'kinetic', '');
    ok $fsa->switch, "We should now be able to switch";

    ##########################################################################
    # Test "Server info"
    is $fsa->curr_state->name, 'Server info',
      'And now we should be in the "Server info" state';

    # Check that data collection attributes have been filled in.
    is $kbs->db_host, undef, 'DB host should be undef';
    is $kbs->db_port, undef, 'DB port should be undef';
    is $kbs->db_name, 'fooness', 'DB name should be "fooness"';
    is $kbs->db_user, 'kinetic', 'DB user should be "kinetic"';
    is $kbs->db_pass, '', 'DB password should be empty';
    is $kbs->db_super_user, undef, 'DB Super user should be undef';
    is $kbs->db_super_pass, undef, 'DB Super user password should be undef';
    is $kbs->template_db_name, undef, 'Template DB name should be undef';
    is $kbs->_dsn('foo'), 'dbi:Pg:dbname=foo', "The _dsn() method should work";

    ok $fsa->switch, 'Now we should be able to switch again';
    is $fsa->curr_state->name, 'Connect user',
      'We should now be in the "Connect user" state';

    # Set up server info with an empty db_name.
    #           db_host      db_port db_name    db_user    db_pass
    @replies = ('pg', '5432', '', 'kinetic', '');
    ok $fsa->reset->curr_state('Server info'), 'Set up Server info again';
    is $kbs->db_name, '', "DB Name should be empty";
    # This switch should fail.
    throws_ok { $fsa->switch }
      qr'I need the database name to configure PostgreSQL',
      "We should get a failure with an empty database name";

    # Set up server info with a different host name.
    #           db_host      db_port db_name    db_user    db_pass
    @replies = ('pg', '5432', 'fooness', 'kinetic', '');
    ok $fsa->reset->curr_state('Server info'), 'Set up Server info again';
    is $kbs->db_host, 'pg', 'DB host should now be "pg"';
    is $kbs->db_port, undef, 'DB port should still be undef';
    is $kbs->_dsn('foo'), 'dbi:Pg:dbname=foo;host=pg',
      "The dsn should include the host name";

    # Set up server info with a different port.
    #           db_host      db_port db_name    db_user    db_pass
    @replies = ('localhost', '5433', 'fooness', 'kinetic', '');
    ok $fsa->reset->curr_state('Server info'), 'Set up Server info again';
    is $kbs->db_host, undef, 'DB host should now be undef';
    is $kbs->db_port, '5433', 'DB port should still be "5433"';
    is $kbs->_dsn('foo'), 'dbi:Pg:dbname=foo;port=5433',
      "The dsn should include the port number";

    # It will attempt to connect next.
    my $pg = MockModule->new($class);
    my @connect;
    $pg->mock(_connect => sub { shift @connect });

    # Okay, now set up with root information (as if it was passed as an option
    # on the command-line.
    #           db_host      db_port db_name    db_user    db_pass template_db_name
    @replies = ('localhost', '5432', 'fooness', 'kinetic', '',     'template1');
    #        db_super_user db_super_pass
    @args = ('postgres',   '');
    ok $fsa->reset->curr_state('Server info'), 'Set up Server info again';
    ok $fsa->switch, 'Switch out of "Server info"';

    ##########################################################################
    # Test "Connect super user"
    is $fsa->curr_state->name, 'Connect super user',
      'We should now be in the "Connect super user" state';

    is $kbs->db_host, undef, 'DB host should be undef';
    is $kbs->db_port, undef, 'DB port should be undef';
    is $kbs->db_name, 'fooness', 'DB name should be "fooness"';
    is $kbs->db_user, 'kinetic', 'DB user should be "kinetic"';
    is $kbs->db_pass, '', 'DB password should be empty';
    is $kbs->db_super_user, 'postgres', 'DB Super user should be "postgres"';
    is $kbs->db_super_pass, '', 'DB Super user password should be empty';
    is $kbs->template_db_name, 'template1',
      'Template DB name should be "template1"';

    throws_ok { $fsa->switch }
      qr'I cannot connect to the PostgreSQL server via "dbi:Pg:dbname=fooness" or "dbi:Pg:dbname=template1"',
      "We should get a failure to connect to the server";

    # Success will trigger the do action for the Check database state, so set
    # it up to succeed.
    my $db_exists = 1;
    $pg->mock(_db_exists => sub { $db_exists });

    # Try again with _connect() returning a database handle for
    # the user database.
    @connect = (1);
    ok $fsa->reset->curr_state('Connect super user'),
      'Set up to connect super user';
    ok $fsa->switch, 'Switch out of "Connect super user"';
    is $fsa->curr_state->name, 'Check database',
      'Should now be in the "Check database" state';
    is $fsa->prev_state->message,
      'Connected to server via "dbi:Pg:dbname=fooness"; checking for database',
      "We should have a descriptive message from the previous state";

    # Try again with _connect() returning a database handle for
    # the template database.
    @connect = (0, 1);
    ok $fsa->reset->curr_state('Connect super user'),
      'Set up to connect super user';
    ok $fsa->switch, 'Switch out of "Connect super user"';
    is $fsa->curr_state->name, 'Check database',
      'Should now be in the "Check database" state';
    is $fsa->prev_state->message,
      'Connected to server via "dbi:Pg:dbname=template1"; checking for database',
      "We should have a descriptive message from the previous state";

    ##########################################################################
    # Test "Check database"
    $kbs->{actions} = [];

    # Success will trigger the do action for the Check plpgsql state, so set
    # it up to succeed.
    my $plpgsql = 1;
    $pg->mock(_plpgsql_available => sub { $plpgsql });
    my $can_create = 1;
    $pg->mock(_can_create_db => sub { $can_create });

    ok $fsa->switch, 'We should be able to switch from "Check database"';
    is $fsa->curr_state->name, 'Check plpgsql',
      'We should now be in the "Check plpgsql" state';
    is $fsa->prev_state->message,
      'Database "fooness" exists; checking for PL/pgSQL',
      'Message should reflect success';
    is_deeply $kbs->{actions},  [], 'Actions should be empty';

    # Now try with database not existing.
    $db_exists = 0;
    ok $fsa->reset->curr_state('Check database'), 'Reset to "Check database"';
    ok $fsa->switch, 'We should be able to switch from "Check database"';
    is $fsa->curr_state->name, 'Check template plpgsql',
      'We should now be in the "Check template plpgsql" state';
    is $fsa->prev_state->message,
      'Database "fooness" does not exist but will be created; checking '
      . 'template database for PL/pgSQL',
      'Message should reflect success';
    is_deeply $kbs->{actions},  [['create_db']],
      'Actions should have create_db';
    $kbs->{actions} = [];

    # Now try with database not existing and not super user.
    $db_exists = 0;
    $kbs->{db_super_user} = undef;
    ok $fsa->reset->curr_state('Check database'), 'Reset to "Check database"';
    ok $fsa->switch, 'We should be able to switch from "Check database"';
    is $fsa->curr_state->name, 'Check create permissions',
      'We should now be in the "Check create permissions" state';
    is $fsa->prev_state->message,
      'Database "fooness" does not exist; checking permissions to create it',
      'Message should reflect success';
    is_deeply $kbs->{actions},  [['create_db']],
      'Actions should have create_db';

    ##########################################################################
    # Test "Check plpgsql"
    my $dsn_db;
    $pg->mock(_dsn => sub { $dsn_db = $_[1]} );
    my $user_exists = 1;
    $pg->mock(_user_exists => sub { $user_exists });
    my $has_schema = 1;
    $pg->mock(_has_schema_permissions => sub { $has_schema });

    # Start with success.
    $kbs->{db_super_user} = 'postgres';
    ok $fsa->reset->curr_state('Check plpgsql'),
      'Go back to "Check plpgsql" state';
    is $dsn_db, 'fooness', 'The rule should have created the "fooness" DSN';
    ok $fsa->switch, "Switch to the next state";
    is $fsa->curr_state->name, 'Check user',
      'We should now be in the "Check user" state';
    is $fsa->prev_state->message,
      'Database "fooness" has PL/pgSQL; checking user',
      'Message should reflect success and moving on to check user';

    # Now try failure.
    $plpgsql = 0;
    ok $fsa->reset->curr_state('Check plpgsql'),
      'Go back to "Check plpgsql" state again';
    ok $fsa->switch, "Switch to the next state";
    is $fsa->curr_state->name, 'Find createlang',
      'We should now be in the "Find createlang" state';
    is $fsa->prev_state->message,
      'Database "fooness" does not have PL/pgSQL; looking for createlang',
      'Message should reflect failure and moving on to check createlang';

    # Now try failure for a non-super user.
    $kbs->{db_super_user} = undef;
    ok $fsa->reset->curr_state('Check plpgsql'),
      'Go back to "Check plpgsql" state yet again';
    ok $fsa->switch, "Switch to the next state";
    is $fsa->curr_state->name, 'Get super user',
      'We should now be in the "Get super user" state';
    is $fsa->prev_state->message,
      'Database "fooness" does not have PL/pgSQL and user "kinetic" cannot '
      . 'add it; prompting for super user',
      'Message should reflect failure and moving on to get super user';

    # Now try success for a non-super user.
    $plpgsql = 1;
    ok $fsa->reset->curr_state('Check plpgsql'),
      'Go back to "Check plpgsql" state one more time';
    ok $fsa->switch, "Switch to the next state";
    is $fsa->curr_state->name, 'Check schema permissions',
      'We should now be in the "Check schema permissions" state';
    is $fsa->prev_state->message,
      'Database "fooness" has PL/pgSQL; checking schema permissions',
      'Message should reflect failure and moving on to get super user';

    ##########################################################################
    # Test "Check template plpgsql"
    # Start with success and super user.
    $kbs->{db_super_user} = 'postgres';
    ok $fsa->reset->curr_state('Check template plpgsql'),
      'Reset to "Check template plpgsql"';
    is $dsn_db, 'template1', 'The rule should have created the "template1" DSN';
    ok $fsa->switch, 'Switch from "Check template plpgsql"';
    is $fsa->curr_state->name, 'Check user', 'We should switch to "Check user"';
    is $fsa->prev_state->message, 'Template database has PL/pgSQL',
      'Message should notice that template database has PL/pgSQL';

    # Try failure with super user.
    $plpgsql = 0;
    ok $fsa->reset->curr_state('Check template plpgsql'),
      'Reset to "Check template plpgsql"';
    ok $fsa->switch, 'Switch from "Check template plpgsql" again';
    is $fsa->curr_state->name, 'Find createlang',
      'We should have switched to "Find createlang"';
    is $fsa->prev_state->message,
      "Template database lacks PL/pgSQL; looking for createlang",
      'Message should notice that template database has no PL/pgSQL';

    # Try failure with non-super user.
    $kbs->{db_super_user} = undef;
    ok $fsa->reset->curr_state('Check template plpgsql'),
      'Reset to "Check template plpgsql"';
    ok $fsa->switch, 'Switch from "Check template plpgsql" yet again';
    is $fsa->curr_state->name, 'Get super user',
      'We should have switched to "Get super user"';
    is $fsa->prev_state->message, "Template database lacks PL/pgSQL and user "
      . '"kinetic" cannot add it; prompting for super user',
      'Message should notice need for super user';

    # Try success with non-super user.
    $plpgsql = 1;
    ok $fsa->reset->curr_state('Check template plpgsql'),
      'Reset to "Check template plpgsql"';
    ok $fsa->switch, 'Switch from "Check template plpgsql" once again';
    is $fsa->curr_state->name, 'Done', "We should be done";
    is $fsa->prev_state->message, 'Template database has PL/pgSQL',
      'Message should notice that template database has PL/pgSQL';

    ##########################################################################
    # Test "Find createlang"
    my $createlang = 1;
    $kbs->{actions} = [];
    $info->mock(createlang => sub { $createlang });
    ok $fsa->reset->curr_state('Find createlang'),
      'Reset to "Find createlang"';

    # Start with success.
    ok $fsa->switch, 'Switch out of "Find createlang"';
    is $fsa->curr_state->name, 'Check user',
      'We should switch to "Check user"';
    is $fsa->prev_state->message, 'Found createlang',
      "Message should note finding of createlang";
    is_deeply $kbs->{actions},  [['add_plpgsql']],
      'Actions should have add_plpgsql';
    $kbs->{actions} = [];

    # Now try failure.
    $createlang = 0;
    ok $fsa->reset->curr_state('Find createlang'),
      'Reset to "Find createlang"';
    throws_ok { $fsa->switch } qr'Cannot find createlang',
      'We should die if we cannot find createlang';
    is_deeply $kbs->{actions},  [], 'Actions should be empty';

    ##########################################################################
    # Test "Check user"
    $kbs->{actions} = [];
    ok $fsa->reset->curr_state('Check user'), 'Reset to "Check user"';

    # Start with success.
    $user_exists = 1;
    ok $fsa->switch, 'Switch out of "Check user"';
    is $fsa->curr_state->name, 'Done', 'We should be done';
    is $fsa->prev_state->message, 'User "kinetic" exists',
      "Message should note that user exists";
    is_deeply $kbs->{actions},  [['build_db']],
      'Actions should have build_db only';

    # Check for no user.
    $user_exists = 0;
    $kbs->{actions} = [];
    ok $fsa->reset->curr_state('Check user'), 'Reset to "Check user"';
    ok $fsa->switch, 'Switch out of "Check user again"';
    is $fsa->curr_state->name, 'Done', 'We should be done again';
    is $fsa->prev_state->message,
      'User "kinetic" does not exist but will be created',
      "Message should note that user will be created";
    is_deeply $kbs->{actions},  [['create_user'], ['build_db']],
      'Actions should have create_user and build_db';
    $kbs->{actions} = [];

    ##########################################################################
    # Test "Connect user"
    $pg->unmock('_dsn');
    $kbs->{db_super_user} = undef;
    @connect = (0, 0);
    ok $fsa->curr_state('Connect user'), 'Reset to "Connect user" state';

    # Start with failure.
    ok $fsa->switch, 'Switch out of "Connect user"';
    is $fsa->curr_state->name, 'Get super user',
      'We should have switched to "Get super user"';
    is $fsa->prev_state->message,
      'I cannot connect to the PostgreSQL server via "dbi:Pg:dbname=fooness" '
      . 'or "dbi:Pg:dbname=template1"; prompting for super user',
        "Message should reflect failure and need for super user";

    # Success will trigger the do action for the Check database state, so set
    # it up to succeed.

    # Try again with _connect() returning a database handle for
    # the user database.
    @connect = (1);
    ok $fsa->reset->curr_state('Connect user'),
      'Set up to connect user';
    ok $fsa->switch, 'Switch out of "Connect user"';
    is $fsa->curr_state->name, 'Check database',
      'Should now be in the "Check database" state';
    is $fsa->prev_state->message,
      'Connected to server via "dbi:Pg:dbname=fooness"; checking for database',
      "We should have a descriptive message from the previous state";

    # Try again with _connect() returning a database handle for
    # the template database.
    @connect = (0, 1);
    ok $fsa->reset->curr_state('Connect user'),
      'Set up to connect user';
    ok $fsa->switch, 'Switch out of "Connect user"';
    is $fsa->curr_state->name, 'Check database',
      'Should now be in the "Check database" state';
    is $fsa->prev_state->message,
      'Connected to server via "dbi:Pg:dbname=template1"; checking for database',
      "We should have a descriptive message from the previous state";

    ##########################################################################
    # Test "Check create permissions"
    $can_create = 1;
    ok $fsa->reset->curr_state('Check create permissions'),
      'Reset to "Check create permissions"';
    ok $fsa->switch, 'Switch out of "Check create permissions"';
    is $fsa->curr_state->name, 'Check template plpgsql',
      'Should now be in the "Get super user" state';
    is $fsa->prev_state->message,
      'User "kinetic" can create database "fooness"; checking template for PL/pgSQL',
      'Message should note create permission';

    # Now try failure.
    $can_create = 0;
    ok $fsa->reset->curr_state('Check create permissions'),
      'Reset to "Check create permissions"';
    ok $fsa->switch, 'Switch out of "Check create permissions"';
    is $fsa->curr_state->name, 'Get super user',
      'Should now be in the "Check template plpgsql" state';
    is $fsa->prev_state->message,
      'User "kinetic" cannot create database "fooness"; '
      . 'prompting for super user',
      'Message should note lack of create permission';

    ##########################################################################
    # Test "Check schema permissions"
    $has_schema = 1;
    ok $fsa->reset->curr_state('Check schema permissions'),
      'Reset to "Check schema permissions"';
    ok $fsa->switch, 'Switch out of "Check schema permissions"';
    is $fsa->curr_state->name, 'Done', 'We should be done';
    is $fsa->prev_state->message,
      'User "kinetic" has CREATE permission to the schema for database '
      . '"fooness"',
      'Message should note schema permission';

    # Now try failure.
    $has_schema = 0;
    ok $fsa->reset->curr_state('Check schema permissions'),
      'Reset to "Check schema permissions"';
    ok $fsa->switch, 'Switch out of "Check schema permissions"';
    is $fsa->curr_state->name, 'Get super user',
      'Should now be in the "Get super user" state';
    is $fsa->prev_state->message,
      'User "kinetic" does not have CREATE permission to the schema for '
      . 'database "fooness"; prompting for super user',
      'Message should note lack of schema permission';

    ##########################################################################
    # Test "Get super user"
    @replies = ('pgsql', '');
    ok $fsa->reset->curr_state('Get super user'),
      'Reset to "Get super user"';
    ok $fsa->switch, 'Switch out of "Get super user"';
    is $fsa->curr_state->name, 'Connect super user',
      'We should have switched to "Connect super user"';
    is $fsa->prev_state->message,
      'Attempting to connect to the server as super user "pgsql"',
        'Message should reflect next step';

    # Try failure (probably won't happen).
    $kbs->{db_super_user} = undef;
    ok $fsa->reset->curr_state('Get super user'),
      'Reset to "Get super user"';
    throws_ok { $fsa->switch }
      qr'I need the super user name to configure PostgreSQL',
      'Switch out of "Get super user"';
    is $fsa->curr_state->name, 'Fail',
      'We should have switched to "Connect super user"';

    ##########################################################################
    # Test "Fail"
    $kbs->{db_super_user} = undef;
    my $error;
    $mb->mock(_fatal_error => sub { $error = $_[1] });
    ok $fsa->reset->curr_state('Get super user'),
      'Reset to "Get super user" to test "Fail"';
    eval { $fsa->switch }; # Trigger an error;
    is $error, 'I need the super user name to configure PostgreSQL',
      'Error should have been passed to Build->_fatal_error()';
    $mb->unmock('_fatal_error'); # XXX This doesn't seem to get freed up for some reason...

    ##########################################################################
    # Test "Done"
    $kbs->{actions} = [];
    ok $fsa->reset->curr_state('Done'), 'Reset to "Done"';
    is_deeply $kbs->{actions}, [['build_db']];

}

1;
__END__
