package Kinetic::Store::Setup::DB::Pg;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use base 'Kinetic::Store::Setup::DB';
use FSA::Rules;
use Kinetic::Store::Language;
use POSIX qw(WIFEXITED);

use Class::BuildMethods qw(
    super_user
    super_pass
    template_dsn
    createlang
);

use Kinetic::Store::Exceptions qw(
    throw_unsupported
    throw_not_found
    throw_io
    throw_setup
);

=head1 Name

Kinetic::Store::Setup::DB::Pg - Kinetic Pg data store setup

=head1 Synopsis

See L<Kinetic::Store::Setup|Kinetic::Store::Setup>.

=head1 Description

This module inherits from Kinetic::Store::Setup::DB to build a Pg set up
store.

=head1 Class Interface

=head2 Constructors

=head3 new

  my $pg_setup = Kinetic::Store::Setup::DB::Pg->new(\%params);

The constructor inherits from
L<Kinetic::Store::Setup::DB|Kinetic::Store::Setup:::DB> to set default values
for the following attributes:

=over

=item super_user

Defaults to "postgres".

=item super_pass

Defaults to "".

=item user

Defaults to "kinetic".

=item dsn

Defaults to "dbi:Pg:dbname=kinetic".

=item template_dsn

Defaults to the value of C<dsn> with the value for the C<dbname> changed to
"template1".

=back

=cut

sub new {
    my $self = shift->SUPER::new(@_);
    for my $spec (
        [ super_user       => 'postgres'              ],
        [ super_pass       => ''                      ],
        [ dsn              => 'dbi:Pg:dbname=kinetic' ],
    ) {
        my ($attr, $value) = @{ $spec };
        $self->$attr($value) unless defined $self->$attr;
    }

    # Disallow the null string.
    $self->user('kinetic') unless $self->user;

    unless ($self->template_dsn) {
        (my $dsn = $self->dsn) =~ s/dbname=['"]?[^:'"]+['"]?/dbname=template1/;
        $self->template_dsn($dsn);
    }

    return $self;
}

##############################################################################

=head2 Class Methods

=head3 connect_attrs

  DBI->connect(
      $dsn, $user, $pass,
      { Kinetic::Store::Setup::DB::Pg->connect_attrs }
  );

Returns a list of arugments to be used in the attributes hash passed to the
DBI C<connect()> method. Overrides that provided by
L<Kinetic::Store::Setup::DB|Kinetic::Store::Setup::DB> to add
C<< pg_enable_utf8 => 1 >>.

=cut

sub connect_attrs {
    return (
        shift->SUPER::connect_attrs,
        pg_enable_utf8 => 1,
    );
}

##############################################################################

=head1 Instance Interface

=head2 Instance Accessors

In addition to the attribute accessors provided by Kinetic::Store::Setup::DB,
this class provides the following.

=head3 super_user

  my $super_user = $setup->super_user;
  $setup->super_user($super_user);

Gets and sets the C<super_user> attribute.

=head3 super_pass

  my $super_pass = $setup->super_pass;
  $setup->super_pass($super_pass);

Gets and sets the C<super_pass> attribute.

=head3 template_dsn

  my $template_dsn = $setup->template_dsn;
  $setup->template_dsn($template_dsn);

Gets and sets the C<template_dsn> attribute.

=head2 Instance Methods

=head3 setup

  $setup->setup;

Sets up the data store. This implementation simply constructs a database
handle and assigns it to the C<dbh> attribute, and then calls
C<SUPER::setup()> to let Kinetic::Store::Setup::DB handle the bulk of the
work.

=cut

sub setup {
    my $self = shift;
    my $machine = FSA::Rules->new( $self->rules );
    $machine->run;
    return $self;
    $self->disconnect_all;
}

##############################################################################

=head3 teardown

  $kbs->teardown;

Tears down the tests data store by disconnecting all database handles
currently connected via DBD::Pg, waiting for the connections to be registered
by PostgreSQL, and then dropping the test database and user. If there appear
to be users connected to the database, C<test_cleanup> will sleep for one
second and then try again, sleep and try again, etc. If there are still users
connected to the database after five seconds, it will give up and die. But
that shouldn't happen unless you have an I<extremely> slow system, or have
connected to the database yourself in another process. Either way, you'll then
need to drop the database and user manually.

=cut

sub teardown {
    my $self = shift;
    my $dsn = $self->dsn;
    my $db_name = $self->_db_from_dsn($dsn);
    my $db_user = $self->user;

    # Disconnect all database handles.
    $self->disconnect_all;
    sleep 1; # Let them disconnect.

    # Connect to the template database.
    my $dbh = $self->connect(
        $self->template_dsn,
        $self->super_user,
        $self->super_pass,
    );

    # We'll use this to check for connections to the database.
    my $check_connections = sub {
        return ($dbh->selectrow_array(
            'SELECT 1 FROM pg_stat_activity where datname = ?',
            undef, $db_name
        ))[0];
    };

    # Wait for up to five seconds for all connections to close.
    for (1..5) {
        last unless $check_connections->();
        sleep 1;
    }

    # If there are still connections, we can't drop the database. So bail.
    throw_setup [
        'Looks like someone is accessing "[_1]", so I cannot drop that database',
        $dsn,
    ] if $check_connections->();

    # Drop the database and user.
    $dbh->do(qq{DROP DATABASE "$db_name"});
    $dbh->do(qq{DROP USER "$db_user"});
    $dbh->disconnect;
    return $self;
}

##############################################################################

=head3 rules

  my $machine = FSA::Rules->new($setup->rules);
  print $machine->graph->as_png;

This method returns a list of values to be passed to the
L<FSA::Rules|FSA::Rules> constructor. When the C<run()> method is called on
the resulting FSA::Rules object, the rules handle the actual setup of the
PostgreSQL database. Used internally by C<setup()> and therefore not of much
use externally (except for testing and graphing).

=cut

STATE: {
    package # Hide from the CPAN indexer.
        Kinetic::Store::Setup::State;
    use base 'FSA::State';
    sub message {
        my $self = shift;
        return $self->SUPER::message(\@_) if @_;
        my $lang = Kinetic::Store::Language->get_handle;
        my $msg = $self->SUPER::message or return;
        return $lang->maketext(ref $msg ? @{ $msg } : $msg);
    }

    sub label {
        my $self = shift;
        my $lang = Kinetic::Store::Language->get_handle;
        return $lang->maketext($self->SUPER::label);
    }

    sub errors {
        my $self = shift;
        return @{ $self->{errors} ||= [] } unless @_;
        push @{ $self->{errors} }, @_;
        return $self;
    }
}

sub rules {
    my $self = shift;
    return (
        { state_class => 'Kinetic::Store::Setup::State' },

        ######################################################################
        'Start' => {
            label => 'Can we connect as super user?',
            do => sub {
                local *__ANON__ = '__ANON__conect_super_user';
                # Set up the rusult and note if we successfully connect.
                my $state = shift;
                if ($self->_try_connect(
                    $state,
                    $self->super_user,
                    $self->super_pass,
                )) {
                    $state->result(1);
                    $state->notes( super => 1 );
                }
            },
            rules => [
                'Connected' => {
                    rule => sub { shift->result },
                    message => 'Yes',
                },
                'No Superuser' => {
                    rule => 1,
                    message => 'No',
                },
            ],
        }, # Start

        ######################################################################
        'Connected' => {
            label => 'Do we have the proper version of PostgreSQL?',
            do => sub {
                shift->result( $self->check_version );
            },
            rules => [
                'Superuser Connects' => {
                    rule => sub {
                        my $state = shift;
                        $state->result && $state->notes('super')
                    },
                    message => 'Yes',
                },
                'User Connects' => {
                    rule => sub { shift->result },
                    message => 'Yes',
                },
                'Fail' => {
                    rule => 1,
                    message => 'No',
                },
            ],
        }, # Connected

        ######################################################################
        'Superuser Connects' => {
            label => 'Does the database exist?',
            do => sub {
                local *__ANON__ = '__ANON__check_for_database';
                my $state = shift;
                my $dsn = $self->dsn;

                $state->result(
                    # If we're connected to the database, it exists.
                    $state->notes('dsn') eq $dsn
                    # Chances are the database doesn't exist (or we would have
                    # connected to it), but let's just be thorough.
                    # Database handle in dbh should still be good.
                    || $self->_db_exists
                 );
                $state->notes( db_exists => $state->result );
            },
            rules => [
                'Database Exists' => {
                    rule => sub { shift->result },
                    message => 'Yes',
                },
                'Can Create Database' => {
                    rule => sub { shift->notes('super') },
                    message => 'No',
                },
                'No Database' => {
                    rule => 1,
                    message => 'No',
                },
            ],
        }, # Superuser Connects

        ######################################################################
        'No Superuser' => {
            label => 'Can we connect as the user?',
            do => sub {
                local *__ANON__ = '__ANON__connect_as_user';
                # Set up the result and note if we successfully connect.
                my $state = shift;
                $state->result(1) if $self->_try_connect(
                    $state,
                    $self->user,
                    $self->pass,
                );
            },
            rules => [
                'Connected' => {
                    rule => sub { shift->result },
                    message => 'Yes',
                },
                'Fail' => {
                    rule => sub {
                        local *__ANON__ = '__ANON__cannot_connect';
                        # Set the message before we die.
                        my $state = shift;
                        $state->message('No');
                        $state->machine->curr_state('Fail');
                        throw_setup [
                            'User "[_1]" cannot connect to either "[_2]" or "[_3]"',
                            $self->user,
                            $self->dsn,
                            $self->template_dsn
                        ];
                    },
                    # Leave this for graphing.
                    message => 'No',
                },
            ],
        }, # No Superuser

        ######################################################################
        'Database Exists' => {
            label => 'Does it have PL/pgSQL?',
            do => sub {
                local *__ANON__ = '__ANON__check_plpgsql';
                my $state = shift;
                # dbh should be connected to the production database.
                $state->result($self->_plpgsql_available);
                $state->notes( plpgsql => $state->result );
            },
            rules => [
                'Database Has PL/pgSQL' => {
                    rule => sub {
                        # Super user goes to this state.
                        my $state = shift;
                        $state->result && $state->notes('super');
                    },
                    message => 'Yes',
                },
                'User Exists' => {
                    # Regular user goes to this state.
                    rule => sub { shift->result },
                    message => 'Yes',
                },
                'No PL/pgSQL' => {
                    # Super user goes to this state.
                    rule => sub { shift->notes('super') },
                    message => 'No',
                },
                'Fail' => {
                    # Regular user cannot add PL/pgSQL.
                    rule => sub {
                        local *__ANON__ = '__ANON__no_plpgsql';
                        # Set the message before we die.
                        my $state = shift;
                        $state->message('No');
                        $state->machine->curr_state('Fail');
                        throw_setup [
                            'The "[_1]" database does not have PL/pgSQL and user "[_2]" cannot add it',
                            $self->dsn,
                            $self->user,
                        ];
                    },
                    # Leave this for graphing.
                    message => 'No',
                },
            ],
        }, # Database Exists

        ######################################################################
        'No Database' => {
            label => 'So create the database.',
            do => sub {
                local *__ANON__ = '__ANON__create_database';
                my $state = shift;
                # User should be connected to the template database.
                # $self->connect(
                #     $self->template_dsn,
                #     $state->notes('super')
                #         ? ( $self->super_user, $self->super_pass )
                #         : ( $self->user,       $self->pass       )
                # );
                $state->result(
                    $self->create_db($self->_db_from_dsn($self->dsn))
                );
            },
            rules => [
                'Database Has PL/pgSQL' => {
                    # Superuser needs to check for user.
                    rule => sub {
                        my $state = shift;
                        $state->result && $state->notes('super')
                            && $state->notes('plpgsql');
                    },
                    message => 'Okay',
                },
                'Add PL/pgSQL' => {
                    # Superuser can add PL/pgSQL.
                    rule => sub {
                        my $state = shift;
                        $state->result && $state->notes('super');
                    },
                    message => 'Okay',
                },
                'User Exists' => {
                    # User can now create the database.
                    rule => sub { shift->result },
                    message => 'Okay',
                },
                'Fail' => {
                    # This is here mainly for documentation purposes.
                    rule => 1,
                    message => 'Failed',
                },
            ],
        }, # No Database

        ######################################################################
        'User Connects' => {
            label => 'Does the database exist?',
            do => sub {
                local *__ANON__ = '__ANON__check_database_exists';
                my $state = shift;
                # User connected to template db in dsn.
                $state->result( $self->_db_exists );
                $state->notes( db_exists => $state->result );
            },
            rules => [
                'Database Exists' => {
                    rule => sub { shift->result },
                    message => 'Yes',
                },
                'No Database for User' => {
                    rule => 1,
                    message => 'No',
                },
            ],
        }, # User Connects

        ######################################################################
        'No Database for User' => {
            label => 'Can we create a database?',
            do => sub {
                local *__ANON__ = '__ANON__check_create_database';
                my $state = shift;
                # User should still be connected to the template database.
                # $self->connect( $self->template_dsn, $self->user, $self->pass);
                $state->result( $self->_can_create_db );
            },
            rules => [
                'Can Create Database' => {
                    rule => sub { shift->result },
                    message => 'Yes',
                },
                'Fail' => {
                    rule => sub {
                        local *__ANON__ = '__ANON__cannot_create_db';
                        # Set the message before we die.
                        my $state = shift;
                        $state->message('No');
                        $state->machine->curr_state('Fail');
                        throw_setup [
                            'User "[_1]" cannot create a database',
                            $self->user,
                        ];
                    },
                    # Leave this for graphing.
                    message => 'No',
                },
            ],
        }, # No Database for User

        ######################################################################
        'Can Create Database' => {
            label => 'Does the template database have PL/pgSQL?',
            do => sub {
                local *__ANON__ = '__ANON__check_template_plpgsql';
                my $state = shift;
                # User should still be connected to the template database.
                # $self->connect( $self->template_dsn, $self->user, $self->pass);
                $state->result($self->_plpgsql_available);
            },
            rules => [
                'No Database' => {
                    # No problems.
                    rule => sub { shift->result },
                    message => 'Yes',
                },
                'No PL/pgSQL' => {
                    # The super user will have to add PL/pgSQL.
                    rule => sub { shift->notes('super') },
                    message => 'No',
                },
                'Fail' => {
                    rule => sub {
                        # Set the message before we die.
                        local *__ANON__ = '__ANON__no_template_plpgsql';
                        my $state = shift;
                        $state->message('No');
                        $state->machine->curr_state('Fail');
                        throw_setup [
                            'The "[_1]" database does not have PL/pgSQL and user "[_2]" cannot add it',
                            $self->template_dsn,
                            $self->user,
                        ];
                    },
                    # Leave this for graphing.
                    message => 'No',
                },
            ],
        }, # Can Create Database

        ######################################################################
        'Database Has PL/pgSQL' => {
            label => 'Does the user exist?',
            do => sub {
                local *__ANON__ = '__ANON__check_user_exists';
                my $state = shift;
                $state->result(
                    $self->_user_exists( $self->user )
                );
            },
            rules => [
                'User Exists' => {
                    rule => sub { shift->result },
                    message => 'Yes',
                },
                'No User' => {
                    rule => 1,
                    message => 'No',
                },
            ],
        }, # Database Has PL/pgSQL

        ######################################################################
        'No PL/pgSQL' => {
            label => 'So find createlang.',
            do => sub {
                local *__ANON__ = '__ANON__find_createlang';
                my $state = shift;
                $state->result( $self->find_createlang );
                $state->notes( createlang => $state->result );
            },
            rules => [
                'Add PL/pgSQL' => {
                    rule => sub {
                        # If the database exists, we add it.
                        my $state = shift;
                        $state->result && $state->notes('db_exists');
                    },
                    message => 'Okay',
                },
                'No Database' => {
                    # Create the database.
                    rule => sub { shift->result },
                    message => 'Okay',
                },
                'Fail' => {
                    rule => sub {
                        local *__ANON__ = '__ANON__no_createlang';
                        # Set the message before we die.
                        my $state = shift;
                        $state->message('Failed');
                        $state->machine->curr_state('Fail');
                        throw_setup [
                            'Cannot find createlang; is it in the PATH?',
                        ];
                    },
                    # Leave this for graphing.
                    message => 'Failed',
                },
            ],
        }, # No PL/pgSQL

        ######################################################################
        'User Exists' => {
            label => 'So build the database and grant permissions.',
            do => sub {
                local *__ANON__ = '__ANON__build_database';
                my $state = shift;
                $self->build_db;
                $state->result(1);
            },
            rules => [
                'Done' => {
                    rule => sub { shift->result },
                    message => 'Okay',
                },
                'Fail' => {
                    rule => 1,
                    message => 'Failed',
                },
            ],
        }, # User Exists

        ######################################################################
        'No User' => {
            label => 'So create the user.',
            do => sub {
                local *__ANON__ = '__ANON__create_user';
                my $state = shift;
                $state->result( $self->create_user );
            },
            rules => [
                'User Exists' => {
                    rule => sub { shift->result },
                    message => 'Okay',
                },
                'Fail' => {
                    rule => 1,
                    message => 'Failed',
                },
            ],
        }, # No User

        ######################################################################
        'Add PL/pgSQL' => {
            label => 'Add PL/pgSQL to the database.',
            do => sub {
                local *__ANON__ = '__ANON__add_plpgsql';
                my $state = shift;
                $state->result(
                    $self->add_plpgsql(
                        $self->_db_from_dsn($self->dsn)
                    )
                );
            },
            rules => [
                'Database Has PL/pgSQL' => {
                    rule => sub { shift->result },
                    message => 'Okay',
                },
                'Fail' => {
                    rule => 1,
                    message => 'Failed',
                },
            ],
        }, # Add PL/pgSQL

        ######################################################################
        'Done' => {
            label => 'All done!',
            do => sub { shift->done(1) }
        }, # Done.

        ######################################################################
        'Fail' => {
            # Exceptions should be thrown by the rules.
            label => 'Setup failed.',
            do => sub { shift->done(1) }
        }, # Fail
    );
}

##############################################################################

=head3 check_version

  $setup->check_version;

Validates that we're using and connecting to PostgreSQL 8.0 or higher.

=cut

sub check_version {
    my $self = shift;
    my $dbh  = $self->dbh;
    my $req  = 80000;

    throw_unsupported [
        '[_1] is compiled with [_2] [_3] but we require version [_4]',
        'DBD::Pg',
        'PostgreSQL',
        $dbh->{pg_lib_version},
        $req,
    ] if $dbh->{pg_lib_version} < $req;

    throw_unsupported [
        'The [_1] server is version [_2] but we require version [_3]',
        'PostgreSQL',
        $dbh->{pg_server_version},
        $req,
    ] if $dbh->{pg_server_version} < $req;

    return $self;
}

##############################################################################

=head3 create_db

  $setup->create_db($db_name);

Attempts to create a database with the supplied name. It uses Unicode
encoding. It will disconnect from the database when done. If the database name
is not supplied, it will use that stored in the C<db_name> attribute.

=cut

sub create_db {
    my ($self, $db_name) = @_;
    my $dbh = $self->dbh;
    $dbh->do(qq{CREATE DATABASE "$db_name" WITH ENCODING = 'UNICODE'});
    return $self;
}

##############################################################################

=head3 add_plpgsql

  $setup->add_plpgsql($db_name);

Given a database name, this method will attempt to add C<plpgsql> to the
database using F<createlang>. If the C<createlang> attribute is not specified,
it will attempt to find it using C<find_createlang()>, and if that fails it
will throw an exception. The appropriate host and port, if any, will be pulled
out of the C<dsn>, and the C<super_user>, if set to a true value, will also be
used (recommended).

=cut

sub add_plpgsql {
    my ($self, $db_name) = @_;
    my $createlang = $self->createlang || $self->find_createlang
        or throw_not_found [
            'Cannot find the PostgreSQL createlang executable',
        ];

    # createlang -U postgres plpgsql template1
    my @options;
    for my $token ( split /;/, $self->dsn ) {
        my ($k, $v) = split /=/, $token;
        next unless $v;
        $v =~ s/;$//;
        push @options, '-h', $v if $k =~ /^host/; # Includes hostaddr
        push @options, '-p', $v if $k eq 'port';
    }

    if (my $super = $self->super_user) {
        push @options, '-U', $super;
    }

    return $self->_run($createlang, @options, 'plpgsql', $db_name);
}

##############################################################################

=head3 create_user

  $setup->create_user($user, $pass);

Attempts to create a user with the supplied name. It defaults to the user name
returned by C<db_user()> and the password returned by C<db_pass()>.

=cut

sub create_user {
    my ($self, $user, $pass) = @_;
    $user ||= $self->user;
    $pass ||= $self->pass;

    my $dbh = $self->connect(
        $self->template_dsn,
        $self->super_user,
        $self->super_pass,
    );

    $dbh->do(
        qq{CREATE USER "$user" WITH password '$pass' NOCREATEDB NOCREATEUSER}
    );
    return $self;
}

##############################################################################

=head3 build_db

  $setup->build_db;

Builds the database with all of the tables, sequences, indexes, views,
triggers, etc., required to power the application. Overrides the
implementation in the parent class to set up the database handle and to
silence "NOTICE" output from PostgreSQL.

=cut

sub build_db {
    my $self = shift;

    my $dbh = $self->_connect($self->dsn);
    $dbh->do('SET client_min_messages = warning');

    $self->SUPER::build_db(@_);
    $self->grant_permissions;
}

##############################################################################

=head3 grant_permissions

  $setup->grant_permissions;

Grants the database user permission to access the objects in the database.
Called if the super user creates the database.

=cut

sub grant_permissions {
    my $self = shift;
    my $dbh = $self->connect(
        $self->dsn,
        $self->super_user,
        $self->super_pass,
    );

    # relkind:
    #   r => 'table (relation)',
    #   v => 'view',
    #   i => 'index',
    #   c => 'composite type',
    #   S => 'sequence',
    #   s => 'special',
    #   t => 'TOAST table',

    my $objects = $dbh->selectcol_arrayref(qq{
        SELECT n.nspname || '."' || c.relname || '"'
        FROM   pg_catalog.pg_class c
               LEFT JOIN pg_catalog.pg_user u ON u.usesysid = c.relowner
               LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE  c.relkind IN ('S', 'v')
               AND n.nspname NOT IN ('pg_catalog', 'pg_toast')
               AND pg_catalog.pg_table_is_visible(c.oid)
    });

    return $self unless $objects && @$objects;

    $dbh->do(
        'GRANT SELECT, UPDATE, INSERT, DELETE ON '
        . join(', ', @$objects) . ' TO "'
        . $self->user . '"'
    );

    return $self;
}

##############################################################################

=head3 find_createlang

  my $createlang = $setup->find_createlang;

Searches for the F<createlang> executable on the file system. Used internally
by C<add_plpgsql()> when the C<createlang> attribute is not set. It searches
in the following directories:

=over 4

=item $ENV{POSTGRES_HOME}/bin (if $ENV{POSTGRES_HOME} exists)

=item $ENV{POSTGRES_LIB}/../bin (if $ENV{POSTGRES_LIB} exists)

=item The system path (File::Spec->path)

=item /usr/local/pgsql/bin

=item /usr/local/postgres/bin

=item /opt/pgsql/bin

=item /usr/local/bin

=item /usr/local/sbin

=item /usr/bin

=item /usr/sbin

=item /bin

=item C:\Program Files\PostgreSQL\bin

=back

=cut

sub find_createlang {
    my $exe = 'createlang';
    $exe .= '.exe' if $^O eq 'MSWin32';
    my $fs = 'File::Spec';
    for my $dir (
        ( exists $ENV{POSTGRES_HOME}
            ? ($fs->catdir($ENV{POSTGRES_HOME}, 'bin'))
            : ()
        ),
        ( exists $ENV{POSTGRES_LIB}
            ? ($fs->catdir($ENV{POSTGRES_LIB}, $fs->updir, 'bin'))
            : ()
        ),
        $fs->path,
        qw(/usr/local/pgsql/bin
           /usr/local/postgres/bin
           /usr/lib/postgresql/bin
           /opt/pgsql/bin
           /usr/local/bin
           /usr/local/sbin
           /usr/bin
           /usr/sbin
           /bin
        ),
        'C:\Program Files\PostgreSQL\bin',
    ) {
        my $file = $fs->catfile($dir, $exe);
        return $file if -f $file && -x $file;
    }
}

##############################################################################

=begin private

=head1 Private Interface

=head1 Private Instance Interface

=head3 _fetch_value

  my $value = $setup->_fetch_value($sql, @bind_params);

This method executes the given SQL with the params, if any. It expects that
the SQL will return one and only one value, and in turn returns that value.

=cut

sub _fetch_value {
    my ($self, $sql, @bind_params) = @_;
    my $dbh = $self->dbh or die 'I need a database handle to execute a query';
    my $result = $dbh->selectrow_array($sql, undef, @bind_params);
    return $result;
}

##############################################################################

=head3 _connect

  my $dbh = $setup->_connect($dsn);

This method attempts to connect to PostgreSQL via a given DSN. It connects as
the super user if the super user has been set; otherwise, it connects as the
database user. Whoever it tries to connet, the arguments will be passed to
C<connect()>.

=cut

sub _connect {
    my ($self, $dsn) = @_;
    my @credentials;
    if (my $super = $self->super_user) {
        @credentials = ($super, $self->super_pass);
    } else {
        @credentials = ($self->user, $self->pass);
    }

    $self->connect($dsn, @credentials);
}

##############################################################################

=head3 _try_connect

  print "Can connect" if  $setup->_try_connect($state, $user, $password);

Used by state rules, this method attempts to connect to the database server,
first using the production DSN and then the template DSN. The successful DSN
will be stored in under the C<dsn> key in the state object's notes. Any
exceptions thrown by the C<connect()> method will be passed to the C<errors()>
method of the state object. Returns the setup object on success and C<undef>
on failure. The database handle created by the connection, if any, may be
retreived by the C<dbh()> method.

=cut

sub _try_connect {
    my ($self, $state, $user, $pass) = @_;
    my @errs;
    for my $dsn ($self->dsn, $self->template_dsn) {
        eval {
            $self->connect(
                $dsn,
                $user,
                $pass,
            );
        };
        if (my $err = $@) {
            push @errs, $@;
        } else {
            $state->notes( dsn => $dsn );
            return $self;
        }
    }

    $state->errors(@errs);
    return;
}

##############################################################################

=head3 _db_from_dsn

  my $db_name = $setup->_db_from_dsn($dsn);

Extracts the database name from the DSN and returns it.

=cut

sub _db_from_dsn {
    my ($self, $dsn) = @_;
    my ($db_name) = $dsn =~ /dbname=['"]?([^;'"]+)/;
    return $db_name;
}

##############################################################################

=head3 _db_exists

  print "Database '$db_name' exists" if $setup->_db_exists($db_name);

Returns true when the database exists, and false when it does not. If no
database is passed, it will be parsed from the C<dsn> attribute.

=cut

sub _db_exists {
    my ($self, $db_name) = @_;
    $db_name ||= $self->_db_from_dsn($self->dsn);
    $self->_fetch_value(
        'SELECT datname FROM pg_catalog.pg_database WHERE datname = ?',
        $db_name
    );
}

##############################################################################

=head3 _plpgsql_available

  print "PL/pgSQL is available" if $setup->_plpgsql_available;

Returns boolean value indicating whether PL/pgSQL is installed in the database
to which we're currently connected.

=cut

sub _plpgsql_available {
    shift->_fetch_value(
        'SELECT true FROM pg_catalog.pg_language WHERE lanname = ?',
        'plpgsql'
    );
}

##############################################################################

=head3 _can_create_db

  print "User can create database" if $setup->_can_create_db;

This method tells whether a particular user has permissions to create
databases.

=cut

sub _can_create_db {
    my $self = shift;
    $self->_fetch_value(
        'SELECT usecreatedb FROM pg_catalog.pg_user WHERE usename = ?',
        $self->user
    );
}

##############################################################################

=head3 _user_exists

  print "User exists" if $setup->_user_exists($user);

This method tells whether a particular PostgreSQL user exists.

=cut

sub _user_exists {
    my ($self, $user) = @_;
    $self->_fetch_value(
        'SELECT usename FROM pg_catalog.pg_user WHERE usename = ?',
        $user
    );
}

##############################################################################

=head3 _run

  $setup->_run('echo', 'Off and running!');

This method simply passes all of its arguments off to a call to C<system> and
then does appropriate error checking. This is the recommended method for
running system commands.

=cut

sub _run {
    my $self = shift;
    local $SIG{__WARN__} = sub { Kinetic::Store::Exception::ExternalLib->new( shift ) };
    system @_;
    return $self if WIFEXITED $?;
    throw_io [
        '[_1] failed: [_2]',
        q{system('} . join(q{', '}, @_) . q{')},
        $? == -1 ? $! : 'exit value ' . $? >> 8
    ];
}

1;
__END__

=end private

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut

