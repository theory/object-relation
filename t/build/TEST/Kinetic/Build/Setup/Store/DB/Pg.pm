package TEST::Kinetic::Build::Setup::Store::DB::Pg;

# $Id$

use strict;
use warnings;
use base 'TEST::Kinetic::Build::Setup::Store::DB';
use Test::More;
use aliased 'Test::MockModule';
use Test::Exception;
use File::Spec::Functions;
use Test::File;
use Config::Std;
use constant Build => 'Kinetic::Build';

__PACKAGE__->runtests unless caller;

sub get_pg_auth : Test(startup) {
    my $self = shift;
    return unless $self->supported('pg');
    # We need to read in the test configuration file, in t/conf. This is to
    # circumvent the use of the test configuration file in t/sample/conf, just
    # so that we can get the full username and password of the super user and
    # the template database name to test actual connections to the database.
    # These are set up by the main ./Build. We're in t/sample, so we need to
    # get ../conf/kinetic.conf.
    my $conf_file = catfile updir, 'conf', 'kinetic.conf';
    read_config($conf_file => $self->{conf});
}

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

sub test_rules : Test(182) {
    my $self = shift;
    my $class = $self->test_class;
    $self->chdirs('t', 'data');

    # Override builder methods to keep things quiet.
    my $mb = MockModule->new(Build);
    $mb->mock( check_manifest => undef );
    $mb->mock( _check_build_component => 1);
    $mb->mock( dev_tests      => undef );

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
    throws_ok { $fsa->switch } qr/PostgreSQL is the wrong version/,
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
    is $kbs->db_host, '', 'DB host should be the null string';
    is $kbs->db_port, '', 'DB port should be the null string';
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
      qr/I need the database name to configure PostgreSQL/,
      "We should get a failure with an empty database name";

    # Set up server info with a different host name.
    #           db_host      db_port db_name    db_user    db_pass
    @replies = ('pg', '5432', 'fooness', 'kinetic', '');
    ok $fsa->reset->curr_state('Server info'), 'Set up Server info again';
    is $kbs->db_host, 'pg', 'DB host should now be "pg"';
    is $kbs->db_port, '', 'DB port should still be the null string';
    is $kbs->_dsn('foo'), 'dbi:Pg:dbname=foo;host=pg',
      "The dsn should include the host name";

    # Set up server info with a different port.
    #           db_host      db_port db_name    db_user    db_pass
    @replies = ('localhost', '5433', 'fooness', 'kinetic', '');
    ok $fsa->reset->curr_state('Server info'), 'Set up Server info again';
    is $kbs->db_host, '', 'DB host should now be the null string';
    is $kbs->db_port, '5433', 'DB port should still be "5433"';
    is $kbs->_dsn('foo'), 'dbi:Pg:dbname=foo;port=5433',
      "The dsn should include the port number";

    # It will attempt to connect next.
    my $pg = MockModule->new($class);
    my @connect;
    $pg->mock(_connect => sub { shift @connect });
    my $is_super = 1;
    $pg->mock(_is_super_user => sub { $is_super });

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

    is $kbs->db_host, '', 'DB host should be the null string';
    is $kbs->db_port, '', 'DB port should be the null string';
    is $kbs->db_name, 'fooness', 'DB name should be "fooness"';
    is $kbs->db_user, 'kinetic', 'DB user should be "kinetic"';
    is $kbs->db_pass, '', 'DB password should be empty';
    is $kbs->db_super_user, 'postgres', 'DB Super user should be "postgres"';
    is $kbs->db_super_pass, '', 'DB Super user password should be empty';
    is $kbs->template_db_name, 'template1',
      'Template DB name should be "template1"';

    throws_ok { $fsa->switch }
        qr/Cannot connect to the PostgreSQL server via "dbi:Pg:dbname=fooness" or "dbi:Pg:dbname=template1"/,
      "We should get a failure to connect to the server";

    # Success will trigger the do action for the Check database state, so set
    # it up to succeed.
    my $db_exists = 1;
    $pg->mock(_db_exists => sub { $db_exists });

    # Try again with _is_super_user returning false.
    $is_super = 0;
    @connect = (1);
    ok $fsa->reset->curr_state('Connect super user'),
      'Set up to connect super user';
    throws_ok { $fsa->switch }
      qr/Connected to server via "dbi:Pg:dbname=fooness", but "postgres" is not a super user/,
      'An attempt to swtich states should fail if the user is not a super user';

    # Try again with _connect() returning a database handle for
    # the user database.
    $is_super = 1;
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
    $kbs->del_actions($kbs->actions);

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
    is_deeply [$kbs->actions],  [], 'Actions should be empty';

    # Now try with database not existing.
    $db_exists = 0;
    ok $fsa->reset->curr_state('Check database'), 'Reset to "Check database"';
    ok $fsa->switch, 'We should be able to switch from "Check database"';
    is $fsa->curr_state->name, 'Check template plpgsql',
      'We should now be in the "Check template plpgsql" state';
    is $fsa->prev_state->message,
        qq{Database "fooness" does not exist but will be created;\n}
        . 'checking template database for PL/pgSQL',
      'Message should reflect success';
    is_deeply [$kbs->actions],  ['create_db'],
      'Actions should have create_db';
    $kbs->del_actions($kbs->actions);

    # Now try with database not existing and not super user.
    $db_exists = 0;
    $kbs->{db_super_user} = undef;
    ok $fsa->reset->curr_state('Check database'), 'Reset to "Check database"';
    ok $fsa->switch, 'We should be able to switch from "Check database"';
    is $fsa->curr_state->name, 'Check create permissions',
      'We should now be in the "Check create permissions" state';
    is $fsa->prev_state->message,
        qq{Database "fooness" does not exist;\n}
        . 'Checking permissions to create it',
      'Message should reflect success';
    is_deeply [$kbs->actions],  ['create_db'],
      'Actions should have create_db';

    # Now try with database not existing and building with Kinetic::AppBuild.
    $mb->mock(isa => 1 ); # So it thinks it's a Kinetic::AppBuild.
    ok $fsa->reset->curr_state('Check database'), 'Reset to "Check database"';
    throws_ok { $fsa->switch, } qr/Database "fooness" does not exist/,
        'Should die with Kinetic::AppBuild and nonexisttent databse';
    $mb->unmock('isa');

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
    $kbs->del_actions($kbs->actions);
    $info->mock(createlang => sub { $createlang });
    ok $fsa->reset->curr_state('Find createlang'),
      'Reset to "Find createlang"';

    # Start with success.
    ok $fsa->switch, 'Switch out of "Find createlang"';
    is $fsa->curr_state->name, 'Check user',
      'We should switch to "Check user"';
    is $fsa->prev_state->message, 'Found createlang',
      "Message should note finding of createlang";
    is_deeply [$kbs->actions],  ['add_plpgsql'],
      'Actions should have add_plpgsql';
    $kbs->del_actions($kbs->actions);

    # Now try failure.
    $createlang = 0;
    ok $fsa->reset->curr_state('Find createlang'),
      'Reset to "Find createlang"';
    throws_ok { $fsa->switch } qr/Cannot find createlang/,
      'We should die if we cannot find createlang';
    is_deeply [$kbs->actions],  [], 'Actions should be empty';

    ##########################################################################
    # Test "Check user"
    $kbs->del_actions($kbs->actions);
    ok $fsa->reset->curr_state('Check user'), 'Reset to "Check user"';

    # Start with success.
    $user_exists = 1;
    ok $fsa->switch, 'Switch out of "Check user"';
    is $fsa->curr_state->name, 'Done', 'We should be done';
    is $fsa->prev_state->message, 'User "kinetic" exists',
      "Message should note that user exists";
    is_deeply [$kbs->actions],  ['build_db'],
      'Actions should have build_db only';

    # Check for no user.
    $user_exists = 0;
    $kbs->del_actions($kbs->actions);
    ok $fsa->reset->curr_state('Check user'), 'Reset to "Check user"';
    ok $fsa->switch, 'Switch out of "Check user again"';
    is $fsa->curr_state->name, 'Done', 'We should be done again';
    is $fsa->prev_state->message,
      'User "kinetic" does not exist but will be created',
      "Message should note that user will be created";
    is_deeply [$kbs->actions],  ['create_user', 'build_db'],
      'Actions should have create_user and build_db';
    $kbs->del_actions($kbs->actions);

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
    is $fsa->prev_state->message, 'Prompting for super user',
        'Message should reflect need for super user';

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
      qr/I need the super user name to configure PostgreSQL/,
      'Switch out of "Get super user"';
    is $fsa->curr_state->name, 'Fail',
      'We should have switched to "Connect super user"';

    ##########################################################################
    # Test "Fail"
    $kbs->{db_super_user} = undef;
    my $error;
    $mb->mock(fatal_error => sub { $error = $_[1] });
    ok $fsa->reset->curr_state('Get super user'),
      'Reset to "Get super user" to test "Fail"';
    eval { $fsa->switch }; # Trigger an error;
    is $error, 'I need the super user name to configure PostgreSQL',
      'Error should have been passed to Build->fatal_error()';
    # XXX This doesn't seem to get freed up for some reason and it leads to
    # failures elsewhere. Why isn't it freed up when $mb goes out of scope?
    $mb->unmock('fatal_error');

    ##########################################################################
    # Test "Done"
    $kbs->del_actions($kbs->actions);
    ok $fsa->reset->curr_state('Done'), 'Reset to "Done"';
    is_deeply [$kbs->actions], ['build_db'],
      'We should have the "build_db" action set up';

    ##########################################################################
    # Test environment variables.
    $mb->unmock('get_reply');
    ENVTEST: {
        local $ENV{PGHOST}     = 'pghost';
        local $ENV{PGPORT}     = '123456';
        local $ENV{PGDATABASE} = 'pgdata';
        local $ENV{PGUSER}     = 'pguser';
        local $ENV{PGPASS}     = 'pgpass';
        ok $fsa->reset->curr_state('Server info'), 'Set up Server info again';
        is $kbs->db_host, 'pghost', 'Host should now be set from an env var';
        is $kbs->db_port, '123456', 'Port should now be set from an env var';
        is $kbs->db_name, 'pgdata', 'DB should now be set from an env var';
        is $kbs->db_user, 'pguser', 'User should now be set from an env var';
        is $kbs->db_pass, 'pgpass', 'Pass should now be set from an env var';
        is $kbs->_dsn, 'dbi:Pg:dbname=pgdata;host=pghost;port=123456',
            'The DSN should contain all of the environment data';
    }

    ##############################################################################
    # Test config file.
    my %config = (
        db_pass          => 'dbpass',
        db_user          => 'dbuser',
        dsn              => 'dbi:Pg:dbname=dbname;host=dbhost;port=987654',
        class            => 'Kinetic::Store::DB::Pg',
        db_super_user    => 'dbsuper',
        db_super_pass    => 'dbspass',
        template_db_name => 'dbtmplt',
    );

    $builder->notes( _config_ => { store => \%config } );
    ok $fsa->reset->curr_state('Server info'), 'Set up Server info again';
    is $kbs->db_host, 'dbhost', 'Host should now be set from config file';
    is $kbs->db_port, '987654', 'Port should now be set from config file';
    is $kbs->db_name, 'dbname', 'DB should now be set from config file';
    is $kbs->db_user, 'dbuser', 'User should now be set from config file';
    is $kbs->db_pass, 'dbpass', 'Pass should now be set from config file';
    is $kbs->_dsn, 'dbi:Pg:dbname=dbname;host=dbhost;port=987654',
        'The DSN should contain all of the config file data';

    ok $fsa->reset->curr_state('Get super user'), 'Set up Get super user';
    is $kbs->db_super_user, 'dbsuper',
        'Super User should now be set from config file';
    is $kbs->db_super_pass, 'dbspass',
        'Super Pass should now be set from config file';

    delete $kbs->{template_db_name};
    ok $kbs->_get_template_db_name, 'Set template name';
    is $kbs->template_db_name, 'dbtmplt',
        'Template db name should be set from the config file';

    $kbs->_dbh(undef); # Prevent ugly deaths during cleanup.
}

##############################################################################
# User provides own username and password, database already exists with
# PL/pgSQL and they can add objects to it. States we'll visit:
#
# Start
# Check version
# server info
# Connect user
# Check database
# Check plpgsql
# Check schema permissions
# Done

sub test_validate_user_db : Test(35) {
    my $self = shift;
    my $class = $self->test_class;
    # Supply username and password when prompted, database exists and has
    # pl/pgsql.

    # Override builder methods to keep things quiet.
    my $mb = MockModule->new(Build);
    $mb->mock( check_manifest => sub { return } );
    $mb->mock( _check_build_component => 1);
    $mb->mock( dev_tests      => undef );

    my $builder = $self->new_builder( store => 'pg' );
    $builder->source_dir('lib');
    $mb->mock(resume => $builder);
    $mb->mock(_app_info_params => sub { } );
    my @replies = ('localhost', '5432', 'kinetic', 'kinetic', 'asdfasdf');
    $mb->mock(get_reply => sub { shift @replies });
    $mb->mock(args => 0);

    # Override App::Info methods to keep things quiet.
    my $info = MockModule->new($class->info_class);
    $info->mock(installed => 1);
    $info->mock(version => '8.0.0');

    # Override $class methods to keep things quiet.
    my $pg = MockModule->new($class);
    $pg->mock(_connect => 1);
    $pg->mock(_db_exists => 1);
    $pg->mock(_plpgsql_available => 1);
    $pg->mock(_has_schema_permissions => 1);

    # Construct the object.
    ok my $kbs = $class->new, "Create new $class object";
    isa_ok $kbs, $class;
    ok $kbs->validate, "We should be able to validate";
    is_deeply [$kbs->actions], ['build_db'],
      'We should have just the "build_db" action';
    is $kbs->db_host, '', 'Database host is null string';
    is $kbs->db_port, '', 'Port is null string';
    is $kbs->db_name, 'kinetic', 'Database name is "kinetic"';
    is $kbs->db_user, 'kinetic', 'Database user is "kinetic"';
    is $kbs->db_pass, 'asdfasdf', 'Database user is "asdfasdf"';
    is $kbs->db_super_user, undef, "Super user is undefined";
    is $kbs->db_super_pass, undef, "Super user password is undefined";
    is $kbs->template_db_name, undef, "Template name is undefined";
    $kbs->_dbh(undef); # Prevent ugly deaths during cleanup.

    # Test config.
    my %conf;
    ok $kbs->add_to_test_config(\%conf);
    is_deeply \%conf, {
        store => {
            class            => 'Kinetic::Store::DB::Pg',
            db_user          => '__kinetic_test__',
            db_pass          => '__kinetic_test__',
            db_super_user    => '',
            db_super_pass    => '',
            template_db_name => '',
            dsn              => 'dbi:Pg:dbname=__kinetic_test__',
        }
    }, 'The test configuration should be set up properly';

    $mb->mock(store => 'pg');
    %conf = ();
    ok $kbs->add_to_config(\%conf);
    is_deeply \%conf, {
        store => {
            class   => 'Kinetic::Store::DB::Pg',
            db_user => 'kinetic',
            db_pass => 'asdfasdf',
            dsn     => 'dbi:Pg:dbname=kinetic',
        },
    }, 'As should the production configuration.';

    # Test the actions.
    return $self->_run_build_tests($kbs, $pg);
}

##############################################################################
# User provides username and password but user doesn't exist. So we prompt
# them for the super user name and password. Super user set up to create the
# database and add PL/pgSQL. States we'll visit:
#
# Start
# Check version
# server info
# Connect user
# Get super user
# Connect super user
# Check database
# Check template plpgsql
# Find createlang
# Check user
# Done

sub test_validate_super_user : Test(35) {
    my $self = shift;
    my $class = $self->test_class;
    # Supply username and password when prompted, database exists and has
    # pl/pgsql.

    # Override builder methods to keep things quiet.
    my $mb = MockModule->new(Build);
    $mb->mock(check_manifest => sub { return });
    $mb->mock( _check_build_component => 1);
    $mb->mock(engine => 'catalyst');
    $mb->mock(cache => 'memcached');
    $mb->mock(dev_tests => undef );

    my $builder = $self->new_builder;
    $mb->mock(resume => $builder);
    $mb->mock(_app_info_params => sub { } );
    my @replies = ('pgme', '5433', 'kinetic', 'kinetic', 'asdfasdf',
                   'template1', 'postgres', 'postgres');
    $mb->mock(get_reply => sub { shift @replies });
    $mb->mock(args => 0);

    # Override App::Info methods to keep things quiet.
    my $info = MockModule->new($class->info_class);
    $info->mock(installed => 1);
    $info->mock(version => '8.0.0');
    $info->mock(createlang => 1);

    # Override $class methods to keep things quiet.
    my $pg = MockModule->new($class);
    my @connect = (0, 0, 0, 1);
    $pg->mock(_connect => sub { shift @connect });
    $pg->mock(_db_exists => 0);
    $pg->mock(_plpgsql_available => 0);
    $pg->mock(_user_exists => 0);
    $pg->mock(_is_super_user => 1);

    # Construct the object.
    ok my $kbs = $class->new($builder), "Create new $class object";
    isa_ok $kbs, $class;
    ok $kbs->validate, "We should be able to validate";
    is_deeply [$kbs->actions], ['create_db', 'add_plpgsql', 'create_user',
                                'build_db', 'grant_permissions'],
      "We should have the right actions";
    is $kbs->db_host, 'pgme', 'Database host is "pgme"';
    is $kbs->db_port, '5433', 'Port is 5433';
    is $kbs->db_name, 'kinetic', 'Database name is "kinetic"';
    is $kbs->db_user, 'kinetic', 'Database user is "kinetic"';
    is $kbs->db_pass, 'asdfasdf', 'Database user is "asdfasdf"';
    is $kbs->db_super_user, 'postgres', 'Super user is "postgres"';
    is $kbs->db_super_pass, 'postgres', 'Super user password is "postgres"';
    is $kbs->template_db_name, 'template1', 'Template name is "template1"';
    $kbs->_dbh(undef); # Prevent ugly deaths during cleanup.

    # Test config.
    my %conf;
    ok $kbs->add_to_test_config(\%conf);
    is_deeply \%conf, {
        store => {
            class            => 'Kinetic::Store::DB::Pg',
            db_user          => '__kinetic_test__',
            db_pass          => '__kinetic_test__',
            db_super_user    => 'postgres',
            db_super_pass    => 'postgres',
            template_db_name => 'template1',
            dsn => 'dbi:Pg:dbname=__kinetic_test__;host=pgme;port=5433',
        },
    }, 'The test configuration should be set up properly';

    $mb->mock(store => 'pg');
    %conf = ();
    ok $kbs->add_to_config(\%conf);
    is_deeply \%conf, {
        store => {
            class   => 'Kinetic::Store::DB::Pg',
            db_user => 'kinetic',
            db_pass => 'asdfasdf',
            dsn     => 'dbi:Pg:dbname=kinetic;host=pgme;port=5433',
        },
    }, 'As should the production configuration.';

    # Test the actions.
    $info->unmock_all;
    return $self->_run_build_tests($kbs, $pg);
}

##############################################################################
# User provides username and password on the command-line. Database exists,
# so super user set up to add PL/pgSQL. States we'll visit:
#
# Start
# Check version
# server info
# Connect super user
# Check database
# Check plpgsql
# Check user
# Done

sub test_validate_super_user_arg : Test(35) {
    my $self = shift;
    my $class = $self->test_class;
    # Supply username and password when prompted, database exists and has
    # pl/pgsql.

    # Override builder methods to keep things quiet.
    my $mb = MockModule->new(Build);
    $mb->mock(check_manifest => sub { return });
    $mb->mock( _check_build_component => 1);
    my $builder = $self->new_builder;
    $mb->mock(resume => $builder);
    $mb->mock(_app_info_params => sub { } );
    my @replies = ('localhost', '5432', 'howdy', 'howdy', 'asdfasdf',
                   'template1');
    $mb->mock(get_reply => sub { shift @replies });
    my @args = ('postgres', 'postgres');
    $mb->mock(args => sub { shift @args });

    # Override App::Info methods to keep things quiet.
    my $info = MockModule->new($class->info_class);
    $info->mock(installed => 1);
    $info->mock(version => '8.0.0');

    # Override $class methods to keep things quiet.
    my $pg = MockModule->new($class);
    my @connect = (1);
    $pg->mock(_connect => sub { shift @connect });
    $pg->mock(_db_exists => 1);
    $pg->mock(_plpgsql_available => 0);
    $pg->mock(_user_exists => 0);
    $pg->mock(_is_super_user => 1);

    # Construct the object.
    ok my $kbs = $class->new, "Create new $class object";
    isa_ok $kbs, $class;
    ok $kbs->validate, "We should be able to validate";
    is_deeply [$kbs->actions], ['add_plpgsql', 'create_user', 'build_db',
                                'grant_permissions'],
      "We should have the right actions";
    is $kbs->db_host, '', 'Database host is null string';
    is $kbs->db_port, '', 'Port is null string';
    is $kbs->db_name, 'howdy', 'Database name is "howdy"';
    is $kbs->db_user, 'howdy', 'Database user is "howdy"';
    is $kbs->db_pass, 'asdfasdf', 'Database user is "asdfasdf"';
    is $kbs->db_super_user, 'postgres', 'Super user is "postgres"';
    is $kbs->db_super_pass, 'postgres', 'Super user password is "postgres"';
    is $kbs->template_db_name, undef, "Template name is undefined";
    $kbs->_dbh(undef); # Prevent ugly deaths during cleanup.

    # Test config.
    my %conf;
    ok $kbs->add_to_test_config(\%conf);
    is_deeply \%conf, {
        store => {
            class            => 'Kinetic::Store::DB::Pg',
            db_user          => '__kinetic_test__',
            db_pass          => '__kinetic_test__',
            db_super_user    => 'postgres',
            db_super_pass    => 'postgres',
            template_db_name => '',
            dsn              => 'dbi:Pg:dbname=__kinetic_test__',
        },
    }, 'The test configuration should be set up properly';

    $mb->mock(store => 'pg');
    %conf = ();
    ok $kbs->add_to_config(\%conf);
    is_deeply \%conf, {
        store => {
            class   => 'Kinetic::Store::DB::Pg',
            db_user => 'howdy',
            db_pass => 'asdfasdf',
            dsn     => 'dbi:Pg:dbname=howdy',
        },
    }, 'As should the production configuration.';

    # Test the actions.
    $info->unmock_all;
    return $self->_run_build_tests($kbs, $pg);
}

##############################################################################
# Test simple Pg store helpers that don't touch the database.

sub test_helpers : Test(15) {
    my $self = shift;
    my $class = $self->test_class;

    # Override builder methods to keep things quiet.
    my $mb = MockModule->new(Build);
    $mb->mock(check_manifest => sub { return });
    $mb->mock( _check_build_component => 1);
    my $builder = $self->new_builder;
    $mb->mock(resume => $builder);
    $mb->mock(_app_info_params => sub { } );

    # Override $class methods to keep things quiet.
    my $pg = MockModule->new($class);
    my $dsn = 'dbi:Pg:dbname=' . 'template';

    # Construct the object.
    ok my $kbs = $class->new, "Create new $class object";
    isa_ok $kbs, $class;

    # Try _connect_user().
    $pg->mock(db_super_user => 'postgres');
    $pg->mock(db_super_pass => 'password');
    my @args;
    $pg->mock(_connect => sub { shift; @args = @_; } );
    $pg->mock(_dbh => undef);
    $kbs->_connect_user($dsn);
    is_deeply \@args, [$dsn, 'postgres', 'password' ],
      '_connect_user should pass super user to _connect';

    # Try it without the super user.
    $pg->unmock('db_super_user');
    $pg->unmock('db_super_pass');
    $pg->mock(db_user => 'user');
    $pg->mock(db_pass => 'pass');
    $kbs->_connect_user($dsn);
    is_deeply \@args, [$dsn, 'user', 'pass' ],
      '_connect_user should pass database user to _connect';

    $pg->unmock('db_user');
    $pg->unmock('db_pass');
    $pg->unmock('_connect');
    $pg->unmock('_dbh');

    # Test_dsn
    is $kbs->_dsn('foo'), 'dbi:Pg:dbname=foo', 'Try a simple DSN';
    # Set up a database.
    $pg->mock(db_name => 'yow');
    is $kbs->_dsn, 'dbi:Pg:dbname=yow', 'DSN should default to db_name';
    # Set up a host.
    $pg->mock(db_host => 'hello');
    is $kbs->_dsn, 'dbi:Pg:dbname=yow;host=hello',
      'DSN should use a host name';
    # Set up a port.
    $pg->mock(db_port => '1212');
    is $kbs->_dsn, 'dbi:Pg:dbname=yow;host=hello;port=1212',
      'DSN should use a port number';
    # And without the host name.
    $pg->unmock('db_host');
    is $kbs->_dsn, 'dbi:Pg:dbname=yow;port=1212',
      'DSN should use a port number without a host';
    $pg->unmock('db_port');

    # Test _try_connect.
    my @cons = (1, 0, 1);
    @args = ();
    $pg->mock(_connect => sub { shift; push @args, @_; shift @cons });
    $pg->mock(_dbh => sub { shift; shift; });
    $pg->mock(db_name => 'foo');

    my $state = {};
    ok $kbs->_try_connect($state, 'one', 'two'),
      "_try_connect() should return true";
    is_deeply \@args, ['dbi:Pg:dbname=foo', 'one', 'two'],
      "Connection parameters should have been passed to _connect()";
    is_deeply $state->{dsn}, ['dbi:Pg:dbname=foo'],
      "The DSN should have been put in the state object";
    $pg->mock(_get_template_db_name => 'myt');
    $state = {};
    @args = ();
    ok $kbs->_try_connect($state, 'one', 'two'),
      "_try_connect() should return true again";
    is_deeply \@args,
      ['dbi:Pg:dbname=foo', 'one', 'two', 'dbi:Pg:dbname=myt', 'one', 'two'],
      "Two sets of connection parameters should have been passed to _connect()";
    is_deeply $state->{dsn}, ['dbi:Pg:dbname=foo', 'dbi:Pg:dbname=myt'],
      "Both DSNs should have been put in the state object";
}

##############################################################################
# Test Pg store helpers that touch the database.

sub test_db_helpers : Test(21) {
    my $self = shift;
    my $class = $self->test_class;

    # Override builder methods to keep things quiet.
    my $mb = MockModule->new(Build);
    $mb->mock(check_manifest => sub { return });
    $mb->mock( _check_build_component => 1);
    my $builder = $self->new_builder;
    $mb->mock(resume => $builder);
    $mb->mock(_app_info_params => sub { } );

    # Override $class methods to keep things quiet.
    my $pg = MockModule->new($class);

    # Construct the object.
    ok my $kbs = $class->new, "Create new $class object";
    isa_ok $kbs, $class;

    # From here on in we hit the database.
    return "Not testing PostgreSQL" unless $self->supported('pg');
    my $dsn = 'dbi:Pg:dbname=' . $self->{conf}{store}{template_db_name};

    # Test _connect().
    isa_ok my $dbh = $kbs->_connect(
        $dsn,
        $self->{conf}{store}{db_super_user},
        $self->{conf}{store}{db_super_pass}, {
            RaiseError     => 0,
            PrintError     => 0,
            pg_enable_utf8 => 1,
            HandleError    => Kinetic::Util::Exception::DBI->handler,
        }
    ), 'DBI::db';

    $pg->mock(_dbh => $dbh);

    # Test _pg_says_true.
    is $kbs->_pg_says_true('select 1'), 1,
      "_pg_says_true should return the value we select";
    is $kbs->_pg_says_true("select 'yow'"), 'yow',
      "Even if it's not a number";
    is $kbs->_pg_says_true("select 1 where 1 = ?", 1), 1,
      "_pg_says_true should accept parameters";
    is $kbs->_pg_says_true("select 1 where 1 = ?", 12), undef,
      "And make appropriate use of them";

    # Test _db_exists.
    ok $kbs->_db_exists($self->{conf}{store}{template_db_name}),
      "_db_exists should return true for the template db";
    ok !$kbs->_db_exists('__an_impossible_db_name_i_hope__'),
      "_db_exists should return false for a non-existant database";

    is $kbs->_plpgsql_available,
      $kbs->_pg_says_true(
          'select 1 from pg_catalog.pg_language where lanname = ?',
          'plpgsql'
      ), '_plpgsql_available should do the right thing';

    # Test _get_template_db_name.
    $mb->mock(get_reply => 'mytemplate');
    is $kbs->{template_db_name}, undef,
      "Template name should start out undef";
    is $kbs->_get_template_db_name, 'mytemplate',
      '_get_template_db_name should return the name provided by get_reply';
    is $kbs->{template_db_name}, 'mytemplate',
      "And now it should be stored in the object";
    $mb->unmock('get_reply');

    # Test _user_exists.
    ok $kbs->_user_exists($self->{conf}{store}{db_super_user}),
      "_user_exists should find the super user";
    ok !$kbs->_user_exists('__impossible_user_name_i_hope__'),
      "and shouldn't find a non-existant user";

    # Test _can_create_db and _has_schema_permissions.
    $pg->mock(db_user =>$self->{conf}{store}{db_super_user});
    ok $kbs->_can_create_db, "Super user should be able to create db";
    ok $kbs->_has_schema_permissions,
      "Super user should add objects to the db";
    $pg->mock(db_user => '__impossible_user_name_i_hope__');
    ok !$kbs->_can_create_db, "A non-existant user cannot create a database";
    ok ! eval { $kbs->_has_schema_permissions },
      "Nor can he add objects to a database";

    ok $kbs->_is_super_user($self->{conf}{store}{db_super_user}),
      "Super user should be super user";
    ok !$kbs->_is_super_user('__impossible_user_name_i_hope__'),
      "A non-existant user should not be a super user";
}

sub test_build_meths : Test(25) {
    my $self = shift;
    return "Not testing PostgreSQL" unless $self->supported('pg');
    my $class = $self->test_class;

    # Override builder methods to keep things quiet.
    my $mb = MockModule->new(Build);
    $mb->mock(check_manifest => sub { return });
    $mb->mock(_app_info_params => sub { } );
    $mb->mock(store => 'pg');

    # Mock the class to use the admin settings set up during the build.
    my $pg = MockModule->new($class);
    my %mock = (
        db_super_user    => 'db_super_user',
        db_super_pass    => 'db_super_pass',
        db_user          => 'db_user',
        db_pass          => 'db_pass',
        test_db_user     => 'db_user',
        test_db_pass     => 'db_pass',
        template_db_name => 'template_db_name',
    );

    while (my ($meth, $val) = each %mock) {
        $pg->mock($meth => $self->{conf}{store}{$val});
    }
    $pg->mock(db_name => $class->test_db_name);
    $pg->mock(test_db_name => $class->test_db_name);
    $pg->mock(validate => 1);

    $mb->mock( _check_build_component => 1);
    my $builder = $self->new_builder;
    $mb->mock(resume => $builder);
    $builder->source_dir('lib'); # We're in t/sample

    # Construct the object.
    ok my $kbs = $class->new, "Create new $class object";
    isa_ok $kbs, $class;

    $builder->notes(build_store => $kbs);
    $builder->dispatch('code');

    isa_ok $self->{tdbh} = $kbs->_connect(
        $kbs->_dsn($self->{conf}{store}{template_db_name}),
        $self->{conf}{store}{db_super_user},
        $self->{conf}{store}{db_super_pass}, {
            RaiseError     => 0,
            PrintError     => 0,
            pg_enable_utf8 => 1,
            HandleError    => Kinetic::Util::Exception::DBI->handler,
        }
    ), 'DBI::db';

    $pg->mock(_dbh => $self->{tdbh});

    # Test create_db.
    ok !$kbs->_db_exists($kbs->test_db_name),
      "The database should not yet exist";
    ok $kbs->create_db($kbs->test_db_name), "Create the test database";
    ok $kbs->_db_exists($kbs->test_db_name),
      "Now the database should exist";

    # Connect to the new database.
    $self->{dbh} = DBI->connect_cached(
        $self->{conf}{store}{dsn},
        $self->{conf}{store}{db_super_user},
        $self->{conf}{store}{db_super_pass}, {
            RaiseError     => 0,
            PrintError     => 0,
            pg_enable_utf8 => 1,
            HandleError    => Kinetic::Util::Exception::DBI->handler,
        }
    );

    # Test add_plpgsql.
    SKIP : {
        skip "PL/pgSQL already installed", 2 if $kbs->_plpgsql_available;
        $kbs->{createlang} = $kbs->info->createlang;
        ok $kbs->add_plpgsql($kbs->test_db_name), "Add PL/pgSQL";
        $pg->mock(_dbh => $self->{dbh});
        ok $kbs->_plpgsql_available, 'PL/pgSQL should be added';
    }

    # Test create_user.
    ok !$kbs->_user_exists($kbs->test_db_user),
      "The user should not yet exist";
    ok $kbs->create_user($kbs->test_db_user), "Create the test user";
    ok $kbs->_user_exists($kbs->test_db_user),
      "Now the user should exist";

    # Test build_db.
    $pg->mock(_dbh => $self->{dbh}); # Don't use the template!
    ok $kbs->build_db, "Build the database";

    for my $view ( Kinetic::Meta->keys ) {
        my $class = Kinetic::Meta->for_key($view);
        my ($expect, $not) = $class->abstract
            ? ([], ' not')
            : ([[1]], '');
        is_deeply $self->{dbh}->selectall_arrayref("
            SELECT 1
            FROM   pg_catalog.pg_class c
            WHERE  c.relname = ? and c.relkind = 'v'
            ", {}, $view
        ), $expect, "View $view should$not exist";
    }

    # Test granting permissions.
    my @checks;
    my @params;
    for my $view ( Kinetic::Meta->keys ) {
        my $class = Kinetic::Meta->for_key($view);
        next if $class->abstract;
        for my $perm (qw(SELECT UPDATE INSERT DELETE)) {
            push @checks, 'has_table_privilege(?, ?, ?)';
            push @params, $self->{conf}{store}{db_user}, $view, $perm;
        }
    }

    is_deeply $self->{dbh}->selectrow_arrayref(
        "SELECT " . join(', ', @checks), undef, @params
    ), [ ('0') x scalar @params / 3 ], "No permissions should be granted yet";
    ok $kbs->grant_permissions;
    is_deeply $self->{dbh}->selectrow_arrayref(
        "SELECT " . join(', ', @checks), undef, @params
    ), [ ('1') x scalar @params / 3 ], "Permissions should now be granted";

    # Clean up our mess.
    $pg->unmock('_dbh');
    $builder->dispatch('clean');
}

sub teardown_db : Test(teardown) {
    my $self = shift->db_cleanup(@_);
    if (my $dbh = delete $self->{tdbh}) {
        $dbh->disconnect;
    }
}

sub db_cleanup {
    my $self = shift;
    if (my $dbh = delete $self->{dbh}) {
        $dbh->disconnect;
    }
    if (my $dbh = $self->{tdbh}) {
        # Wait until the other connection has been dropped. Throw in an extra
        # query to kill a bit of time, just to make sure that we really are
        # fully disconnted. It seems like it sometimes thinks there are still
        # connections even after the query returns false.
        my ($db_name) = $self->{conf}{store}{dsn} =~ /dbname=([^;]+)/;
        sleep 1 while $dbh->selectrow_array(
            'SELECT 1 FROM pg_stat_activity where datname = ?',
            undef, $db_name
        );
        # XXX We should be able to do it without this!
        sleep 2;

        for (my $i = 0; $i < 5; $i++) {
            # This might fail a couple of times as we wait for the database
            # connection to really drop. It might be sometime *after* the above
            # query returns false!
            eval { $dbh->do(qq{DROP DATABASE "$db_name"}) };
            if (my $err = $@) {
                die $err
                  if $i >= 5 || $err !~ /is being accessed by other users/;
                sleep 1, next;
            }
            last;
        }

        $dbh->do(qq{DROP user "$self->{conf}{store}{db_user}"});
    }
    return $self;
}

sub _run_build_tests {
    my ($self, $kbs, $pg) = @_;
    # From here on in, we'll test actually creating the database.
    return "Not testing PostgreSQL" unless $self->supported('pg');

    $pg->unmock('_connect');
    $pg->unmock('_plpgsql_available');
    $kbs->{createlang} = $kbs->info->createlang;
    # Test the build_db action by building the database. First make sure
    # that everything we need to build the databse is actually in place.
    my %mock = (
        db_super_user    => 'db_super_user',
        db_super_pass    => 'db_super_pass',
        db_user          => 'db_user',
        db_pass          => 'db_pass',
        test_db_user     => 'db_user',
        test_db_pass     => 'db_pass',
        template_db_name => 'template_db_name',
    );

    while (my ($meth, $val) = each %mock) {
        $pg->mock($meth => $self->{conf}{store}{$val});
    }
    $pg->mock(db_name => $pg->get_package->test_db_name);
    $pg->mock(test_db_name => $pg->get_package->test_db_name);

    # Mock the host and port by pulling them from the DSN.
    my ($host) = $self->{conf}{store}{dsn} =~ /host=([^;]+)/;
    $pg->mock(db_host => $host);
    my ($port) = $self->{conf}{store}{dsn} =~ /port=(\d+)/;
    $pg->mock(db_port => $port);

    # Set up the template database handle.
    isa_ok $self->{tdbh} = $kbs->_connect(
        $kbs->_dsn($kbs->template_db_name),
        $kbs->db_super_user,
        $kbs->db_super_pass, {
            RaiseError     => 0,
            PrintError     => 0,
            pg_enable_utf8 => 1,
            HandleError    => Kinetic::Util::Exception::DBI->handler,
        }
    ), 'DBI::db';

    $pg->mock(_dbh => $self->{tdbh});

    # What actions are to be done?
    my %actions = map { $_ => 1 } $kbs->actions;

    # Create the test database and user.
    $kbs->create_db($kbs->db_name) unless $actions{create_db};
    $kbs->create_user($kbs->db_user)
      unless $actions{create_user} || $kbs->_user_exists($kbs->db_user);

    # Add PL/pgSQL or prevent it from being added.
    if (my $got_plpgsql = $kbs->_plpgsql_available) {
        # The test mocked _plpgsl_available, so we need to prevent it from
        # doing something it's not supposed to do.
        $kbs->del_actions('add_plpgsql') if $actions{add_plpgsql};
    } else {
        $kbs->add_plpgsql($kbs->db_name) unless $actions{add_plpgsql};
    }
    $pg->unmock('_dbh');

    # Now test creating the new database.
    ok $kbs->setup, 'Setup the database';

    # Grab the database handle and check it out.
    $self->{dbh} = $kbs->_dbh;
    my $sg = $kbs->schema_class->new;
    $sg->load_classes($kbs->builder->source_dir);
    for my $class ($sg->classes) {
        my $view = $class->key;
        is_deeply $self->{dbh}->selectall_arrayref("
            SELECT 1
            FROM   pg_catalog.pg_class c
            WHERE  c.relname = ? and c.relkind = 'v'
            ", {}, $view
        ), [[1]], "View $view should exist";
    }

    # Now clean up our mess and try building the test database.
    $self->db_cleanup;

    # We might have to add plpgsql.
    $pg->mock(_dbh => $self->{tdbh});
    $kbs->add_actions('add_plpgsql') unless $kbs->_plpgsql_available;
    $pg->unmock('_dbh');

    # Run the test build.
    ok $kbs->test_setup, 'Setup test database';
    $self->{dbh} = $kbs->_dbh;
    for my $class ($sg->classes) {
        my $view = $class->key;
        is_deeply $self->{dbh}->selectall_arrayref("
            SELECT 1
            FROM   pg_catalog.pg_class c
            WHERE  c.relname = ? and c.relkind = 'v'
            ", {}, $view
        ), [[1]], "View $view should exist";
    }
}

1;
__END__
