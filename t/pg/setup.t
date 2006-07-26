#!/usr/bin/perl -w

# $Id: setup.t 3046 2006-07-18 05:43:21Z theory $

use strict;
use warnings;
use Test::More tests => 115;
use Test::Exception;
use Test::NoWarnings; # Adds an extra test.
use aliased 'Test::MockModule';
use constant LIVE_PG => $ENV{OBJ_REL_SUPER_USER} && $ENV{OBJ_REL_CLASS} =~ /DB::Pg$/;

BEGIN {
    use_ok 'Object::Relation::Setup::DB::Pg' or die;
    $ENV{OBJ_REL_DSN}  ||= 'dbi:Pg:dbname=obj_rel';
    $ENV{OBJ_REL_USER} ||= 'chip';
}

ok my $setup = Object::Relation::Setup::DB::Pg->new({
    user         => $ENV{OBJ_REL_USER},
    pass         => 'pihc',
    super_user   => 'postgres',
    super_pass   => '',
    dsn          => $ENV{OBJ_REL_DSN},
    template_dsn => 'dbi:Pg:dbname=template1',
}), 'Create PostgreSQL setup object with possible live parameters';

# Set up a database handle for testing.
my $dbh = DBI->connect('dbi:ExampleP:dummy', '', '');
$setup->dbh($dbh);

##############################################################################
# Test check_version()
ok $setup->dbh({
    pg_lib_version    => 80103,
    pg_server_version => 80104,
}), 'Set up a fake database handle to test versions';

ok $setup->check_version, '... The versions should trigger no error';

ok $setup->dbh({
    pg_lib_version    => 70103,
    pg_server_version => 80104,
}), 'Set up a fake database handle with an invalid lib version';

throws_ok { $setup->check_version }
    'Object::Relation::Exception::Fatal::Unsupported',
    '... We should get an "Unsupported" exception';
is $@->error,
    'DBD::Pg is compiled with PostgreSQL 70103 but we require version 80000',
    '... And we should get the proper error message';

ok $setup->dbh({
    pg_lib_version    => 80103,
    pg_server_version => 70104,
}), 'Set up a fake database handle with an invalid server version';

throws_ok { $setup->check_version }
    'Object::Relation::Exception::Fatal::Unsupported',
    '... We should get an "Unsupported" exception';
is $@->error,
    'The PostgreSQL server is version 70104 but we require version 80000',
    '... And we should get the proper error message';

ok $setup->dbh($dbh), 'Restore the database handle';

##############################################################################
# Test create_db()
my $dbi_mock = MockModule->new('DBI::db', no_auto => 1);
my $do_args;
$dbi_mock->mock(do => sub { shift; $do_args = \@_ });

ok $setup->create_db( 'lithium' ), 'Call create_db()';
is_deeply $do_args, [q{CREATE DATABASE "lithium" WITH ENCODING = 'UNICODE'} ],
    '... And the proper argument should have been passed to DBI->do';

##############################################################################
# Test add_plpgsql()
my $pg_mock = MockModule->new(ref $setup);
$pg_mock->mock( createlang => 'createlang' );
my $run_args;
$pg_mock->mock(_run => sub { shift; $run_args = \@_; });

my $dsn = $setup->dsn;
ok $setup->dsn('dbi:Pg:dbname=foo'), 'Set a simple DSN';

my $super = $setup->super_user;
ok $setup->add_plpgsql('larry'), 'Call add_plpgsql()';
is_deeply $run_args, [qw(createlang -U), $super, qw(plpgsql larry)],
    '... And the proper arguments should have been passed to _run()';

# Try a DSN with a hostname.
ok $setup->dsn('dbi:Pg:dbname=foo;host=me'), 'Set a DSN with host';
ok $setup->add_plpgsql('larry'), 'Call add_plpgsql()';
is_deeply $run_args, [qw(createlang -h me -U), $super, qw(plpgsql larry)],
    '... And the proper arguments should have been passed to _run()';

ok $setup->dsn('dbi:Pg:dbname=foo;hostaddr=you'), 'Set a DSN with hostaddr';
ok $setup->add_plpgsql('damian'), 'Call add_plpgsql()';
is_deeply $run_args, [qw(createlang -h you -U), $super, qw(plpgsql damian)],
    '... And the proper arguments should have been passed to _run()';

# Try a DSN with a port.
ok $setup->dsn('dbi:Pg:dbname=foo;port=1234'), 'Set a DSN with port';
ok $setup->add_plpgsql('larry'), 'Call add_plpgsql()';
is_deeply $run_args, [qw(createlang -p 1234 -U), $super, qw(plpgsql larry)],
    '... And the proper arguments should have been passed to _run()';

# Try a DSN with a hostname and port.
ok $setup->dsn('dbi:Pg:dbname=foo;host=me;port=4321'),
    'Set a DSN with host and port';
ok $setup->add_plpgsql('damian'), 'Call add_plpgsql()';
is_deeply $run_args,
    [qw(createlang -h me -p 4321 -U), $super, qw(plpgsql damian)],
    '... And the proper arguments should have been passed to _run()';

ok $setup->dsn('dbi:Pg:dbname=foo;hostaddr=heh;port=2468'),
    'Set a DSN with hostaddr and port';
ok $setup->add_plpgsql('larry'), 'Call add_plpgsql()';
is_deeply $run_args,
    [qw(createlang -h heh -p 2468 -U), $super, qw(plpgsql larry)],
    '... And the proper arguments should have been passed to _run()';

ok $setup->super_user(undef), 'Set superuser to undef';
ok $setup->add_plpgsql('larry'), 'Call add_plpgsql()';
is_deeply $run_args,
    [qw(createlang -h heh -p 2468 plpgsql larry)],
    '... And the proper arguments should have been passed to _run()';

# Restore attributes.
$setup->super_user($super);
$setup->dsn($dsn);

##############################################################################
# Test create_user()
my $connect_args;
$pg_mock->mock(connect => sub { shift; $connect_args = \@_; return $dbh; });
my $user = $setup->user;
my $pass = $setup->pass;

# Try it with default user and pass.
ok $setup->create_user, 'Call create_user() with no args';
is_deeply $connect_args, [ $setup->template_dsn, $super, $setup->super_pass ],
    '... The correct args should have been passed to connect()';
is_deeply $do_args,
    [ qq{CREATE USER "$user" WITH password '$pass' NOCREATEDB NOCREATEUSER} ],
    '... And the correct args should have been passed to DBI->do()';

# Try it with user argument.
ok $setup->create_user('larry'), 'Call create_user(larry)';
is_deeply $connect_args, [ $setup->template_dsn, $super, $setup->super_pass ],
    '... The correct args should have been passed to connect()';
is_deeply $do_args,
    [ qq{CREATE USER "larry" WITH password '$pass' NOCREATEDB NOCREATEUSER} ],
    '... And the correct args should have been passed to DBI->do()';

# Try it with user and password arguments.
ok $setup->create_user('larry', 'p6rulez'), 'Call create_user(larry, p6rulez)';
is_deeply $connect_args, [ $setup->template_dsn, $super, $setup->super_pass ],
    '... The correct args should have been passed to connect()';
is_deeply $do_args,
    [ qq{CREATE USER "larry" WITH password 'p6rulez' NOCREATEDB NOCREATEUSER} ],
    '... And the correct args should have been passed to DBI->do()';

##############################################################################
# Test build_db()
my $db_mock = MockModule->new('Object::Relation::Setup::DB');
my $build_args;
$db_mock->mock(build_db => sub { shift; $build_args = \@_; $setup; });
$pg_mock->mock( grant_permissions => sub { pass 'grant_permissions() called' });

ok $setup->build_db, 'Call build_db()';
is_deeply $connect_args, [ $dsn, $super, $setup->super_pass ],
    '... It should have connected the super user';
is_deeply $build_args, [], '... And it should have called SUPER::build_db()';

# Try it without a super user.
ok $setup->super_user(undef), 'Set super_user to undef';
$build_args = undef;
ok $setup->build_db, 'Call build_db()';
is_deeply $connect_args, [ $dsn, $user, $pass ],
    '... It should have connected the user';
is_deeply $build_args, [], '... And it should have called SUPER::build_db()';

# Restore attributes.
$setup->super_user($super);
$pg_mock->unmock('grant_permissions');

##############################################################################
# Test grant_permissions()
my $select_args;
my $select_ret = [qw(one two three)];
$dbi_mock->mock(selectcol_arrayref => sub {
    shift;
    $select_args = \@_;
    return $select_ret;
});

my $select_obj = qq{
        SELECT n.nspname || '."' || c.relname || '"'
        FROM   pg_catalog.pg_class c
               LEFT JOIN pg_catalog.pg_user u ON u.usesysid = c.relowner
               LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE  c.relkind IN ('S', 'v')
               AND n.nspname NOT IN ('pg_catalog', 'pg_toast')
               AND pg_catalog.pg_table_is_visible(c.oid)
    };

ok $setup->grant_permissions, 'Call grant_permissions()';
is_deeply $connect_args, [ $dsn, $super, $setup->super_pass ],
    '... It should have connected as the super user';
is_deeply $select_args, [ $select_obj ],
    '... It should have passed the proper args to DBI->selectcol_arrayref()';
is_deeply $do_args, [
    qq{GRANT SELECT, UPDATE, INSERT, DELETE ON one, two, three TO "$user"}
], '... And it should have passed the proper args to DBI->do()';

# Try it without any objects.
$select_ret = [];
$do_args = $select_args = undef;
ok $setup->grant_permissions, 'Call grant_permissions() again';
is_deeply $select_args, [ $select_obj ],
    '... It should have passed the proper args to DBI->selectcol_arrayref()';
is $do_args, undef, '... And it should not have called DBI->do()';

##############################################################################
# Test find_createlang()
my $createlang = File::Spec->catfile(qw(t bin createlang));
SKIP: {
    skip 'Skip testing on Win32', 1 if $^O eq 'MSWin32';
    $ENV{POSTGRES_HOME} = 't';
    is $setup->find_createlang, $createlang, 'createlang() should find it';
}

##############################################################################4
# Test _fetch_value()
$select_ret = 'hi';
$dbi_mock->mock(selectrow_array => sub {
    shift;
    $select_args = \@_;
    return $select_ret;
});

is $setup->_fetch_value('some sql', 'param1', 'param2'), 'hi',
    'Call to _fetch_value() should return the proper value';
is_deeply $select_args, ['some sql', undef, 'param1', 'param2'],
    '... And the arguments should have been passed to DBI->selectrow_array()';

##############################################################################
# Test _connect_()
ok $setup->_connect($dsn), 'Call _connect()';
is_deeply $connect_args, [ $dsn, $super, $setup->super_pass ],
    '... The super user should have been passed to connect()';

# Try it without a super user.
ok $setup->super_user(undef), 'Set the super user to undef';
ok $setup->_connect($dsn), 'Call _connect()';
is_deeply $connect_args, [ $dsn, $user, $pass ],
    '... The production user should have been passed to connect()';


##############################################################################
# Try _try_connect()
# Actually pretty well-tested in t/pg/rules.t.
ok my $fsa = FSA::Rules->new($setup->rules), 'Create an FSA::Rules object';
ok my $state = $fsa->states('Start'), 'Grab the Start state';
ok $setup->_try_connect($state, $user, $pass), 'Call _try_connect()';
is_deeply $connect_args, [ $dsn, $user, $pass ],
    'The production DSN and user should have been passed to connect()';

##############################################################################
# Test _db_from_dsn()
is $setup->_db_from_dsn('dbi:Pg:dbname=foo'), 'foo',
    '_db_from_dsn() should work with simple DSN';
is $setup->_db_from_dsn('dbi:Pg:dbname=bar;host=howdy;posrt=124'), 'bar',
    '_db_from_dsn() should work with long DSN';
is $setup->_db_from_dsn('dbi:Pg:host=howdy;dbname=yo;posrt=124'), 'yo',
    '_db_from_dsn() should work when dbname is not first';

##############################################################################
# Test _db_exists()
my $fetch_args;
my $fetch_ret = 1;
$pg_mock->mock(_fetch_value => sub {
    shift;
    $fetch_args = \@_;
    return $fetch_ret;
});

ok $setup->_db_exists('foo'), 'Call to _db_exists() should return true';
is_deeply $fetch_args, [
    'SELECT datname FROM pg_catalog.pg_database WHERE datname = ?',
    'foo',
], '... The proper args should have been passed to _fetch_value()';

# Try it with a false value.
$fetch_ret = 0;
ok !$setup->_db_exists('bar'), 'Call to _db_exists() should return false';
is_deeply $fetch_args, [
    'SELECT datname FROM pg_catalog.pg_database WHERE datname = ?',
    'bar',
], '... The proper args should have been passed to _fetch_value()';

##############################################################################
# Test _plpgsql_available()
$fetch_ret = 1;
ok $setup->_plpgsql_available,
    'Call to _plpgsql_available() should return true';
is_deeply $fetch_args, [
    'SELECT true FROM pg_catalog.pg_language WHERE lanname = ?',
    'plpgsql',
], '... The proper args should have been passed to _fetch_value()';

$fetch_ret = 0;
ok !$setup->_plpgsql_available,
    'Call to _plpgsql_available() should return false';
is_deeply $fetch_args, [
    'SELECT true FROM pg_catalog.pg_language WHERE lanname = ?',
    'plpgsql',
], '... The proper args should have been passed to _fetch_value()';

##############################################################################
# Test _can_create_db()
$fetch_ret = 1;
ok $setup->_can_create_db,
    'Call to _can_create_db() should return true';
is_deeply $fetch_args, [
    'SELECT usecreatedb FROM pg_catalog.pg_user WHERE usename = ?',
    $user,
], '... The proper args should have been passed to _fetch_value()';

$fetch_ret = 0;
ok !$setup->_can_create_db,
    'Call to _can_create_db() should return false';
is_deeply $fetch_args, [
    'SELECT usecreatedb FROM pg_catalog.pg_user WHERE usename = ?',
    $user,
], '... The proper args should have been passed to _fetch_value()';

##############################################################################
# Test _user_exists()
$fetch_ret = 1;
ok $setup->_user_exists($user),
    'Call to _user_exists() should return true';
is_deeply $fetch_args, [
    'SELECT usename FROM pg_catalog.pg_user WHERE usename = ?',
    $user,
], '... The proper args should have been passed to _fetch_value()';

$fetch_ret = 0;
ok !$setup->_user_exists('larry'),
    'Call to _user_exists() should return false';
is_deeply $fetch_args, [
    'SELECT usename FROM pg_catalog.pg_user WHERE usename = ?',
    'larry',
], '... The proper args should have been passed to _fetch_value()';

##############################################################################
# Test _run()
$pg_mock->unmock('_run');
ok $setup->_run($createlang), 'Call to _run() should work properly';

throws_ok { $setup->_run('someprogramthatshouldnotexist') }
    'Object::Relation::Exception::Fatal::IO',
    'Call to _run() should throw an IO exception';
like $@->error, qr/system\('someprogramthatshouldnotexist'\)\s+failed:/,
    '... And the error should be correct';

##############################################################################
# Test connect().
$pg_mock->unmock('connect');
$db_mock->mock( connect => $dbh );

ok $setup->connect, 'Call connect()';
is_deeply $do_args, ['SET client_min_messages = warning'],
    '... It should have set client_min_messages to warning';

# Cleanup.
$pg_mock->unmock_all;
$db_mock->unmock_all;
$dbi_mock->unmock_all;

##############################################################################
# Test live server connection.
##############################################################################
SKIP: {
    skip 'Not testing live PostreSQL server', 19, unless LIVE_PG;

    ok my $setup = Object::Relation::Setup::DB::Pg->new({
        user         => $ENV{OBJ_REL_USER},
        pass         => $ENV{OBJ_REL_PASS},
        super_user   => $ENV{OBJ_REL_SUPER_USER},
        super_pass   => $ENV{OBJ_REL_SUPER_PASS},
        dsn          => $ENV{OBJ_REL_DSN},
        template_dsn => $ENV{OBJ_REL_TEMPLATE_DSN},
    }), 'Create PostgreSQL setup object with possible live parameters';
    ok $setup->class_dirs('t/sample/lib'), 'Set the class_dirs to the sample';

    # Make sure that we can connect to the database.
    my $dbh = eval {
        $setup->connect(
            $setup->template_dsn,
            $setup->super_user,
            $setup->super_pass,
        )
    };

    if (my $err = $@) {
        diag "Looks like we couldn't connect to the template database.\n",
             "Make sure that the OBJ_REL_SUPER_USER, OBJ_REL_DSN, and OBJ_REL_TEMPLATE_DSN\n",
             "environment variables are properly set.\n";
        die $err;
    }

    ok $dbh, 'We should be connected to the template1 database';

    # So build it!
    my $db_name = $setup->_db_from_dsn($setup->dsn);
    ok !$setup->_db_exists($db_name), 'The database should not exist';
    diag 'Building the database; this could take a minute'
        if $ENV{TEST_VERBOSE};
    ok $setup->setup, 'Set up the database';
    ok $setup->_db_exists($db_name), 'The database should now exist';

    # Make sure that everything has been created.
    ok $dbh = $setup->connect(
        $setup->dsn,
        $setup->super_user,
        $setup->super_pass,
    ), 'Connect to the database as the super user';

    END {
        return unless LIVE_PG;
        # Cleanup.
        $setup->disconnect_all;
        sleep 1; # Let them disconnect.
        $dbh = $setup->connect(
            $setup->template_dsn,
            $setup->super_user,
            $setup->super_pass,
        );
        $dbh->do(qq{DROP DATABASE "$db_name"});
        $dbh->do(qq{DROP USER "$ENV{OBJ_REL_USER}"});
        $dbh->disconnect;
    };


    for my $view ( Object::Relation::Meta->keys ) {
        my $class = Object::Relation::Meta->for_key($view);
        my ($expect, $not) = $class->abstract
            ? (undef, ' not')
            : (1, '');
        is $setup->_fetch_value(q{
            SELECT 1
            FROM   pg_catalog.pg_class c
            WHERE  c.relname = ? and c.relkind = 'v'
            }, $view
        ), $expect, "View $view should$not exist";
    }

    # Test permissions.
    my @checks;
    my @params;
    for my $view ( Object::Relation::Meta->keys ) {
        my $class = Object::Relation::Meta->for_key($view);
        next if $class->abstract;
        for my $perm (qw(SELECT UPDATE INSERT DELETE)) {
            push @checks, 'has_table_privilege(?, ?, ?)';
            push @params, $setup->user, $view, $perm;
        }
    }

    is_deeply $dbh->selectrow_arrayref(
        'SELECT ' . join(', ', @checks), undef, @params
    ), [ ('1') x scalar @params / 3 ], 'Permissions should be granted';
}
