package Kinetic::Build::Setup::Store::DB::Pg;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with the
# Kinetic framework, to Kineticode, Inc., you confirm that you are the
# copyright holder for those contributions and you grant Kineticode, Inc.
# a nonexclusive, worldwide, irrevocable, royalty-free, perpetual license to
# use, copy, create derivative works based on those contributions, and
# sublicense and distribute those contributions and any derivatives thereof.

use strict;

use version;
our $VERSION = version->new('0.0.1');

use base 'Kinetic::Build::Setup::Store::DB';
use Kinetic::Build;
use App::Info::RDBMS::PostgreSQL;

=head1 Name

Kinetic::Build::Setup::Store::DB::Pg - Kinetic PostgreSQL data store builder

=head1 Synopsis

See L<Kinetic::Build::Setup::Store|Kinetic::Build::Setup::Store>.

=head1 Description

This module inherits from Kinetic::Build::Setup::Store::DB to build a PostgreSQL data
store. Its interface is defined entirely by Kinetic::Build::Setup::Store. Its
interface is defined entirely by Kinetic::Build::Setup::Store. The command-line
options it adds are:

=over

=item path-to-pg_config

=item db-host

=item db-port

=item db-name

=item db-user

=item db-pass

=item db-super-user

=item db-super-pass

=item template-db-name

=back

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 info_class

  my $info_class = Kinetic::Build::Setup::Store::DB::Pg->info_class

Returns the name of the C<App::Info> class that detects the presences of
PostgreSQL, L<App::Info::RDBMS::PostgreSQL|App::Info::RDBMS::PostgreSQL>.

=cut

sub info_class { 'App::Info::RDBMS::PostgreSQL' }

##############################################################################

=head3 min_version

  my $version = Kinetic::Build::Setup::Store::DB::Pg->min_version

Returns the minimum required version number of PostgreSQL that must be
installed.

=cut

sub min_version { '7.4.5' }

##############################################################################

=head3 dbd_class

  my $dbd_class = Kinetic::Build::Setup::Store::DB::Pg->dbd_class;

Returns the name of the DBI database driver class, L<DBD::Pg|DBD::Pg>.

=cut

sub dbd_class { 'DBD::Pg' }

##############################################################################

=head3 rules

  my @rules = Kinetic::Build::Setup::Store::DB::Pg->rules;

Returns a list of arguments to be passed to an L<FSA::Rules|FSA::Rules>
constructor. These arguments are rules that will be used to validate the
installation of PostgreSQL and to collect information to configure it for
use by TKP.

=cut

sub rules {
    my $self     = shift;
    my $builder  = $self->builder;
    my $no_connect = sub {
        return if $self->_dbh;
        my $state = shift;
        $state->message(
            'Cannot connect to the PostgreSQL server via "'
            . join('" or "', @{$state->{dsn}}) . qq{": $@}
          );
    };

    my $connected = sub {
        my $state = shift;
        return unless $self->_dbh;
        $state->message(
            qq{Connected to server via "$state->{dsn}[-1]"; }
            . "checking for database"
          );
        return $state;
    };

    return (
        'Start' => {
            rules => [
                'Check version' => {
                    rule => sub { $self->info->installed },
                    message => "PostgreSQL is installed; checking version number",
                },
                Fail => {
                    rule => 1,
                    message => "Cannot find PostgreSQL",
                }
            ],
    },

        'Check version' => {
            rules => [
                'Server info' => {
                    rule => sub { $self->is_required_version },
                    message => 'PostgreSQL is the appropriate version number; '
                               . 'collecting server info'
                },
                Fail => {
                    rule => 1,
                    message => "PostgreSQL is the wrong version",
                }
            ],
        },

        'Server info' => {
            do => sub {
                # Get the host name.
                $self->{db_host} = $builder->get_reply(
                    name        => 'db-host',
                    label       => 'PostgreSQL server hostname',
                    message     => 'What PostgreSQL server host name should I use?',
                    default     => 'localhost',
                    environ     => 'PGHOST',
                    config_keys => [qw(store dsn)],
                    callback    => sub {
                        # If a DSN from config file, extract the host name.
                        ($_) = /host=([^;]+)/i if /^dbi:/i;
                        return 1;
                    },
                );

                # Just use null string if it's localhost.
                $self->{db_host} = '' if $self->{db_host} eq 'localhost';

                # Get the port number.
                my $def_port = defined $self->{db_host}
                    ? '5432'
                    : 'local domain socket';
                $self->{db_port} = $builder->get_reply(
                    name        => 'db-port',
                    label       => 'PostgreSQL server port',
                    message     => 'What TCP/IP port should I use to '
                                 . 'connect to PostgreSQL?',
                    default     =>  $def_port,
                    environ     => 'PGPORT',
                    config_keys => [qw(store dsn)],
                    callback => sub {
                        ($_) = /port=(\d+)/i if /^dbi:/i;
                        return 1;
                    },
                );

                # Just use null string if it's a local domain socket or 5432.
                $self->{db_port} = ''
                    if $self->{db_port} eq 'local domain socket'
                    || $self->{db_port} eq '5432';

                # Get the database name.
                $self->{db_name} = $builder->get_reply(
                    name        => 'db-name',
                    label       => 'Database name',
                    message     => 'What database should I use?',
                    default     => 'kinetic',
                    environ     => 'PGDATABASE',
                    config_keys => [qw(store dsn)],
                    callback => sub {
                        # If it's a DSN, extract the database name.
                        ($_) = /dbname=([^;]+)/i if /^dbi:/i;
                        # It must be a true value.
                        return $_;
                    },
                );

                # Get the database user.
                $self->{db_user} = $builder->get_reply(
                    name        => 'db-user',
                    label       => 'Database user name',
                    message     => 'What database user name should I use?',
                    default     => 'kinetic',
                    environ     => 'PGUSER',
                    config_keys => [qw(store db_user)],
                    callback    => sub { $_ } # Must be a true value.
                );

                # Get the database user's password.
                $self->{db_pass} = $builder->get_reply(
                    name    => 'db-pass',
                    label   => 'Database user password',
                    message => 'What Database password should I use (can be '
                               . 'blank)?',
                    default => '',
                    environ     => 'PGPASS',
                    config_keys => [qw(store db_pass)],
                );
            },

            rules => [
                Fail => {
                    rule => sub {
                        my $state = shift;
                        # This is proably unnecessary.
                        my %parts = (
                            db_name => 'database name',
                            db_user => 'database user',
                        );
                        my @parts;
                        while (my ($k, $v) = each %parts) {
                            push @parts, $v unless $self->{$k};
                        }
                        return unless @parts;
                        $state->message(
                            'I need the ' . join(' and ', @parts)
                            . ' to configure PostgreSQL'
                         );
                    },
                },

                'Connect super user' => {
                    rule => sub {
                        # See if the super user was specified on the command-
                        # line, but don't prompt!
                        my $super = $self->db_super_user
                          || $builder->args('db_super_user')
                          or return;

                        # We do! Cache them and move on.
                        $self->{db_super_user} = $super;
                        $self->{db_super_pass} = $builder->args('db_super_pass')
                          unless defined $self->{db_super_pass};
                        return 1;
                    },
                    message => 'Got server info and super user credentials; '
                               . 'attempting to connect',
                },

                'Get super user' => {
                    rule => sub { $builder->dev_tests },
                    message => 'Need super user credentials for dev tests',
                },

                'Connect user' => {
                    rule => sub { $self->db_user && $self->db_name },
                    message => 'Got server info; attempting to connect',
                },
            ],
        },

        'Connect super user' => {
            do => sub {
                my $state = shift;
                $self->_try_connect(
                    $state, $self->db_super_user, $self->db_super_pass
                );
                $state->result($self->_is_super_user) if $connected->($state);
            },
            rules => [
                'Check database' => sub { shift->result },
                Fail => $no_connect,
                Fail => sub {
                    my $state = shift;
                    return unless $self->_dbh;
                    return if $state->result;
                    $state->message(
                        sprintf 'Connected to server via "%s", but "%s" is '
                          . 'not a super user',
                          $state->{dsn}[-1], $self->db_super_user
                    );
                },
            ]
        },

        'Check database' => {
            do => sub { shift->result($self->_db_exists) },
            rules => [
                Fail => {
                    rule => sub {
                        my $state = shift;
                        return if $state->result;
                        return unless $builder->isa('Kinetic::AppBuild');
                        $state->message(
                            'Database "' . $self->db_name
                            . '" does not exist',
                        );
                        return 1;
                    },
                },
                'Check plpgsql' => {
                    rule => sub {
                        my $state = shift;
                        return unless $state->result;
                        $state->message(
                            'Database "' . $self->db_name
                            . '" exists; checking for PL/pgSQL'
                          )
                    },
                },

                'Check create permissions' => {
                    rule => sub {
                        my $state = shift;
                        # This is for the non-super user
                        return if $self->db_super_user;
                        # Note need to create database.
                        $self->add_actions('create_db');
                        my $db = $self->db_name;
                        $state->message(
                            qq{Database "$db" does not exist;\n}
                            . 'Checking permissions to create it'
                        );
                    },
                },

                'Check template plpgsql' => {
                    rule => sub {
                        my $state = shift;
                        # This is for the super user
                        return unless $self->db_super_user;
                        # Note need to create database.
                        $self->add_actions('create_db');
                        my $db = $self->db_name;
                        $state->message(
                            qq{Database "$db" does not exist but will be }
                            . "created;\nchecking template database for PL/pgSQL"
                          );
                    },
                }
            ]
        },

        'Check plpgsql' => {
            do => sub {
                $self->_connect_user($self->_dsn($self->db_name));
                shift->result($self->_plpgsql_available);
            },
            rules => [
                'Check user' => {
                    rule => sub {
                        my $state = shift;
                        return unless $state->result && $self->db_super_user;
                        $state->message(
                            'Database "' . $self->db_name . '" has PL/pgSQL; '
                            . 'checking user');
                        return $state;
                    }
                },
                'Find createlang' => {
                    rule => sub {
                        my $state = shift;
                        return unless $self->db_super_user && !$state->result;
                        $state->message(
                            'Database "' . $self->db_name . '" does not have PL/pgSQL; '
                            . 'looking for createlang'
                        );
                    }
                },
                'Get super user' => {
                    rule => sub {
                        my $state = shift;
                        # Non-super user.
                        return if $self->db_super_user || $state->result;
                        $state->message(
                            sprintf 'Database "%s" does not have PL/pgSQL and '
                            . 'user "%s" cannot add it; prompting for super user',
                            $self->db_name, $self->db_user
                        );
                    }
                },
                'Check schema permissions' => {
                    rule => sub {
                        my $state = shift;
                        # Non-super user.
                        return if $self->db_super_user || !$state->result;
                        $state->message(
                            'Database "' . $self->db_name . '" has PL/pgSQL; '
                            . 'checking schema permissions'
                        );
                    }
                },
            ]
        },

        'Check template plpgsql' => {
            do => sub {
                $self->_connect_user($self->_dsn($self->_get_template_db_name));
                shift->result($self->_plpgsql_available);
            },
            rules => [
                'Check user' => {
                    rule => sub {
                        my $state = shift;
                        # Super user.
                        return unless $state->result && $self->db_super_user;
                        $state->message("Template database has PL/pgSQL");
                    },
                },
                'Find createlang' => {
                    rule => sub {
                        my $state = shift;
                        # Super user.
                        return if $state->result || !$self->db_super_user;
                        $state->message(
                            "Template database lacks PL/pgSQL; looking for createlang"
                        );
                    },
                },
                'Get super user' => {
                    rule => sub {
                        my $state = shift;
                        # Non-super user.
                        return if $state->result || $self->db_super_user;
                        $state->message(
                            sprintf "Template database lacks PL/pgSQL and user "
                            . '"%s" cannot add it; prompting for super user',
                            $self->db_user
                        );
                    },
                },

                'Done' => {
                    rule => sub {
                        my $state = shift;
                        # Non-super user.
                        return unless $state->result && !$self->db_super_user;
                        $state->message("Template database has PL/pgSQL");
                    },
                },
            ]
        },

        'Find createlang' => {
            rules => [
                'Check user' => {
                    rule => sub {
                        # Note location of createlang and need to create PL/pgSQL
                        # in the database.
                        $self->{createlang} = $self->info->createlang
                          or return;
                        $self->add_actions('add_plpgsql');
                    },
                    message => "Found createlang",
                },
                Fail => {
                    rule => 1,
                    message => "Cannot find createlang",
                }
            ]
        },

        'Check user' => {
            do => sub { shift->result($self->_user_exists($self->db_user)) },
            rules => [
                Done => {
                    rule => sub {
                        my $state = shift;
                        return unless $state->result;
                        $state->message('User "' . $self->db_user . '" exists');
                    }
                },
                Done => {
                    rule => sub {
                        my $state = shift;
                        return if $state->result;
                        # Note need to create user.
                        $self->add_actions('create_user');
                        $state->message(
                            'User "' . $self->db_user
                            . '" does not exist but will be created'
                          );
                    }
                }
            ]
        },

        'Connect user' => {
            do => sub {
                $self->_try_connect(shift, $self->db_user, $self->db_pass);
            },
            rules => [
                'Check database' => $connected,
                'Get super user' => sub {
                    my $state = shift;
                    $no_connect->($state);
                    $state->message('Prompting for super user');
                },
            ]
        },

        'Check create permissions' => {
            do => sub {
                $self->_connect_user($self->_dsn($self->db_name));
                shift->result($self->_can_create_db);
            },
            rules => [
                'Get super user' => {
                    rule => sub {
                        my $state = shift;
                        return if $state->result;
                        $state->message(
                            sprintf 'User "%s" cannot create database "%s"; '
                            . 'prompting for super user',
                            $self->db_user, $self->db_name
                        );
                    },
                },
                'Check template plpgsql' => {
                    rule => sub {
                        my $state = shift;
                        return unless $state->result;
                        $state->message(
                            sprintf 'User "%s" can create database "%s"; '
                            . 'checking template for PL/pgSQL',
                            $self->db_user, $self->db_name
                        );
                    },
                }
            ]
        },

        'Check schema permissions' => {
            do => sub {
                $self->_connect_user($self->_dsn($self->db_name));
                shift->result($self->_has_schema_permissions);
            },
            rules => [
                'Get super user' => {
                    rule => sub {
                        my $state = shift;
                        return if $state->result;
                        $state->message(
                            sprintf 'User "%s" does not have CREATE permission '
                            . 'to the schema for database "%s"; prompting for '
                            . 'super user', $self->db_user, $self->db_name
                        );
                    },
                },
                'Done' => {
                    rule => sub {
                        my $state = shift;
                        return unless $state->result;
                        $state->message(
                            sprintf 'User "%s" has CREATE permission to the '
                            . 'schema for database "%s"',
                            $self->db_user, $self->db_name
                        );
                    },
                }
            ],
        },

        'Get super user' => {
            do => sub {
                # Get the database user.
                # my $default = scalar getpwuid((stat('/usr/local/pgsql/data'))[4]);
                my $default = 'postgres';
                $self->{db_super_user} ||= $builder->get_reply(
                    name    => 'db-super-user',
                    label   => 'PostgreSQL super user name',
                    message => q{What's the username for the PostgreSQL super }
                               . 'user?',
                    default => $default,
                    config_keys => [qw(store db_super_user)],
                    callback => sub { $_ } # Must be a true value.
                );

                # Get the database user's password.
                $self->{db_super_pass} ||= $builder->get_reply(
                    name    => 'db-super-pass',
                    label   => 'PostgreSQL super user password',
                    message => q{What's the password for the PostgreSQL super}
                               . ' user (can be blank)?',
                    default => '',
                    config_keys => [qw(store db_super_pass)],
                );
            },
            rules => [
                'Connect super user' => {
                    rule => sub {
                        return unless $self->db_super_user;
                        shift->message(
                            sprintf 'Attempting to connect to the server as '
                            . 'super user "%s"', $self->db_super_user
                        );
                    },
                },
                Fail => {
                    rule => sub {
                        my $state = shift;
                        # This is proably unnecessary.
                        return if $self->db_super_user;
                        $state->message(
                            'I need the super user name to configure PostgreSQL'
                        );
                    },
                }
            ]
        },

        Fail => {
            do => sub { $builder->fatal_error(shift->prev_state->message) },
        },

        Done => {
            do => sub {
                my $state = shift;
                $self->add_actions('build_db');
                # The super user must grant permissions to the database user
                # to access the objects in the database.
                $self->add_actions('grant_permissions')
                  if $self->db_super_user;
                $state->done(1);
            }
        },
    );
}

DESTROY {
    my $self = shift;
    $self->_dbh->disconnect if $self->_dbh;
}

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Instance Accessors

=head3 db_name

  my $db_name = $kbs->db_name;

Returns the name to be used for the PostgreSQL database. This is a read-only
attribute set by the call to the C<validate()> method.

=cut

sub db_name { shift->{db_name} }

##############################################################################

=head3 test_db_name

  my $test_db_name = $kbs->test_db_name;

Returns the name to be used for the test PostgreSQL database. This is a
read-only attribute set by the call to the C<validate()> method.

=cut

# XXX To be paranoid, we should probably make sure that no username or
# database exist with the name "__kinetic_test__".

sub test_db_name { '__kinetic_test__' }

##############################################################################

=head3 template_db_name

  my $template_db_name = $kbs->template_db_name;

Returns the name of the template database which will be used to create a new
database. Usually "template1". This is a read-only attribute set by the call
to the C<validate()> method.

=cut

sub template_db_name { shift->{template_db_name} }

##############################################################################

=head3 db_user

  my $db_user = $kbs->db_user;
  $kbs->db_user($db_user);

The database user to use to connect to the Kinetic database. Defaults to
"kinetic".

=cut

sub db_user { shift->{db_user} }

##############################################################################

=head3 test_db_user

  my $test_db_user = $kbs->test_db_user;
  $kbs->test_db_user($test_db_user);

The database user to use to connect to the Kinetic test database. Defaults to
"__kinetic_test__".

=cut

# XXX To be paranoid, we should probably make sure that no username or
# database exist with the name "__kinetic_test__".

sub test_db_user { '__kinetic_test__' }

##############################################################################

=head3 db_pass

  my $db_pass = $kbs->db_pass;
  $kbs->db_pass($db_pass);

The password for the database user specified by the C<db_user> attribute.
Defaults to "kinetic".

=cut

sub db_pass { shift->{db_pass} }

##############################################################################

=head3 test_db_pass

  my $test_db_pass = $kbs->test_db_pass;
  $kbs->test_db_pass($test_db_pass);

The password for the database user specified by the C<test_db_user> attribute.
Defaults to "__kinetic_test__".

=cut

sub test_db_pass { '__kinetic_test__' }

##############################################################################

=head3 db_super_user

  my $db_super_user = $kbs->db_super_user;
  $kbs->db_super_user($db_super_user);

The super or admin database user, which will be used to create the Kinetic
database and user if they don't already exist. The default is the typical super
user name for the selected data store.

Defaults to postgres.

=cut

sub db_super_user { shift->{db_super_user} }

##############################################################################

=head3 db_super_pass

  my $db_super_pass = $kbs->db_super_pass;
  $kbs->db_super_pass($db_super_pass);

The password for the super or admin database user. An empty string by
default.

=cut

sub db_super_pass { shift->{db_super_pass} }

##############################################################################

=head3 db_host

  my $db_host = $kbs->db_host;
  $kbs->db_host($db_host);

The host name of the Kinetic database server. Null string by default, which
generally means that the connection will be made to localhost via Unix
sockets.

=cut

sub db_host { shift->{db_host} }

##############################################################################

=head3 db_port

  my $db_port = $kbs->db_port;
  $kbs->db_port($db_port);

The port number of the Kinetic database server. Null string by default, which
generally means that the connection will be made to the default port for the
database.

=cut

sub db_port { shift->{db_port} }

##############################################################################

=head1 ACTIONS

=head2 PostgreSQL specific actions

The following actions are all specific to PostgreSQL.  They may be
reimplemented in other classes.

=cut

=head3 create_db

  $kbs->create_db($db_name);

Attempts to create a database with the supplied name. It uses Unicode
encoding. It will disconnect from the database when done.

=cut

sub create_db {
    my ($self, $db_name) = @_;
    $db_name ||= $self->_build_db_name || $self->db_name;
    my $dbh = $self->_connect(
        $self->_dsn($self->template_db_name),
        $self->db_super_user,
        $self->db_super_pass,
    );

    $dbh->do(qq{CREATE DATABASE "$db_name" WITH ENCODING = 'UNICODE'});
    return $self;
}

##############################################################################

=head3 add_plpgsql

  $kbs->add_plpgsql($db_name);

Given a database name, this method will attempt to add C<plpgsql> to the
database. The database name defaults to the value returned by C<db_name>.

=cut

sub add_plpgsql {
    my ($self, $db_name) = @_;
    $db_name ||= $self->_build_db_name || $self->db_name;
    # createlang -U postgres plpgsql template1
    my $createlang = $self->{createlang} or die "Cannot find createlang";
    my @options;
    my %options = (
        db_host       => '-h',
        db_port       => '-p',
        db_super_user => '-U',
    );
    while (my ($method, $switch) = each %options) {
        push @options => ($switch, $self->$method)
          if defined $self->$method;
    }

    my $language = 'plpgsql';
    my @add_plpgsql = ($createlang, @options, $language, $db_name);
    system(@add_plpgsql) && die "system(@add_plpgsql) failed: $?";
    return $self;
}

=begin comment

This is the SQL involved.  We may switch to this if the dependency
on createlang causes a problem.

my %createlang = (
  '7.4' => [
      q{CREATE FUNCTION "plpgsql_call_handler" () RETURNS language_handler AS '$libdir/plpgsql' LANGUAGE C},
      q{CREATE TRUSTED LANGUAGE "plpgsql" HANDLER "plpgsql_call_handler"},
  ],

  '8.0' => [
      q{CREATE FUNCTION "plpgsql_call_handler" () RETURNS language_handler AS '$libdir/plpgsql' LANGUAGE C},
      q{CREATE FUNCTION "plpgsql_validator" (oid) RETURNS void AS '$libdir/plpgsql' LANGUAGE C},
      q{CREATE TRUSTED LANGUAGE "plpgsql" HANDLER "plpgsql_call_handler" VALIDATOR "plpgsql_validator"},
  ],
);

=end comment

##############################################################################

=head3 create_user

  $kbs->create_user($user, $pass);

Attempts to create a user with the supplied name. It defaults to the user name
returned by C<db_user()> and the password returned by C<db_pass()>.

=cut

sub create_user {
    my ($self, $user, $pass) = @_;
    $user ||= $self->_build_db_user || $self->db_user;
    $pass ||= $self->_build_db_pass || $self->db_pass;
    my $dbh = $self->_connect(
        $self->_dsn($self->template_db_name),
        $self->db_super_user,
        $self->db_super_pass,
    );

    $dbh->do(qq{CREATE USER "$user" WITH password '$pass' NOCREATEDB NOCREATEUSER});
    return $self;
}

##############################################################################

=head3 build_db

  $kbs->build_db;

Builds the database with all of the tables, sequences, indexes, views,
triggers, etc., required to power the application. Overrides the
implementation in the parent class to set up the database handle and to
silence "NOTICE" output from PostgreSQL.

=cut

sub build_db { shift->_build_connect('build_db') }

##############################################################################

=head3 build_test_db

  $kbs->build_test_db;

Builds the test database with all of the tables, sequences, indexes, views,
triggers, etc., required to power the application. Overrides the
implementation in the parent class to set up the database handle and to
silence "NOTICE" output from PostgreSQL.

=cut

sub build_test_db { shift->_build_connect('build_test_db') }

##############################################################################

=head3 grant_permissions

  $kbs->grant_permissions;

Grants the database user permission to access the objects in the database.
Called if the super user creates the database.

=cut

sub grant_permissions {
    my $self = shift;
    my $dbh = $self->_connect(
        $self->_dsn($self->_build_db_name || $self->db_name),
        $self->db_super_user,
        $self->db_super_pass,
    );

# relkind:
#   r => 'table'
#   v => 'view'
#   i => 'index'
#   c => 'composite type'
#   S => 'sequence'
#   s => 'special'
#   t => 'TOAST table'

    my $objects = $dbh->selectcol_arrayref(qq{
        SELECT n.nspname || '."' || c.relname || '"'
        FROM   pg_catalog.pg_class c
               LEFT JOIN pg_catalog.pg_user u ON u.usesysid = c.relowner
               LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE  c.relkind IN ('S', 'v')
               AND n.nspname NOT IN ('pg_catalog', 'pg_toast')
               AND pg_catalog.pg_table_is_visible(c.oid)
    });

    $dbh->do('GRANT SELECT, UPDATE, INSERT, DELETE ON '
             . join(', ', @$objects) . ' TO "'
             . ($self->_build_db_user || $self->db_user) . '"');
    return $self;
}

##############################################################################

=head3 add_to_config

  $kbs->add_to_config(\%conf);

This method adds the PostgreSQL configuration data to the hash reference
passed as its sole argument. This configuration data will be written to the
F<kinetic.conf> file. Called during the build to set up the PostgreSQL store
configuration directives to be used by the Kinetic store at run time.

=cut

sub add_to_config {
    my ($self, $config) = @_;
    $config->{store} = {
        class   => $self->store_class,
        db_user => $self->db_user,
        db_pass => $self->db_pass,
        dsn     => $self->_dsn($self->db_name),
    };
    return $self;
}

##############################################################################

=head3 add_to_test_config

  $kbs->add_to_test_config(\%conf);

This method is identical to C<add_to_config()>, except that it adds
configuration data specific to testing to the configuration hash. It expects
to be called by Kinetic::Build to create the F<kinetic.conf> file specifically
for testing.

=cut

sub add_to_test_config {
    my ($self, $config) = @_;
    $config->{store} = {
        class   => $self->store_class,
        db_user => $self->test_db_user,
        db_pass => $self->test_db_pass,
        dsn     => $self->_dsn( $self->test_db_name ),

        # We'll need these during tests.
        db_super_user    => $self->db_super_user    || '',
        db_super_pass    => $self->db_super_pass    || '',
        template_db_name => $self->template_db_name || '',
    };
    return $self;
}

##############################################################################

=head3 setup

  $kbs->setup;

Builds a data store. This implementation overrides the parent version to set
up a database name, username, and password to be used in the action methods.

=cut

sub setup {
    my $self = shift;
    $self->_build_db_name($self->db_name);
    $self->_build_db_user($self->db_user);
    $self->_build_db_user($self->db_pass);
    $self->SUPER::setup(@_);
    return $self;
}

##############################################################################

=head3 test_setup

  $kbs->test_setup;

Builds a test data store. This implementation overrides the parent version to
up a database name, username, and password to be used in the action methods.

=cut

sub test_setup {
    my $self = shift;
    $self->_build_db_name($self->test_db_name);
    $self->_build_db_user($self->test_db_user);
    $self->_build_db_user($self->test_db_pass);
    my %actions = map { $_ => 1 } $self->actions;
    # The test database must do everything, with the possible exception of
    # adding PL/pgSQL.
    $self->create_db;
    $self->add_plpgsql if $actions{add_plpgsql};
    $self->create_user;
    $self->build_test_db;
    $self->grant_permissions;
    return $self;
}

##############################################################################

=head3 test_cleanup

  $kbs->test_cleanup;

Cleans up the tests data store by disconnecting all database handles currently
connected via DBD::Pg, waiting for the connections to be registered by
PostgreSQL, and then dropping the test database and user. If there appear to
be users connected to the database, C<test_cleanup> will sleep for one second
and then try again. If there are still users connected to the database after
five seconds, it will give up and die. But that shouldn't happen unless you
have an I<extremely> slow system, or have connected to the test database
yourself in another process. Either way, you'll then need to drop the test
database and user manually.

=cut

sub test_cleanup {
    my $self = shift;
    my $db_name = $self->test_db_name;
    my $db_user = $self->test_db_user;

    # Disconnect all database handles.
    $self->disconnect_all;
    sleep 1; # Let them disconnect.

    # Connect to the template database.
    my $dbh = $self->_connect(
        $self->_dsn($self->template_db_name),
        $self->db_super_user,
        $self->db_super_pass,
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
    die "# Looks like someone is accessing $db_name, so I can't drop it\n"
        if $check_connections->();

    # Drop the database and user.
    $dbh->do(qq{DROP DATABASE "$db_name"});
    $dbh->do(qq{DROP USER "$db_user"});
    $dbh->disconnect;
    return $self;
}

##############################################################################

=begin private

=head1 Private Interface

=head2 Private Instance Methods

=head3 _connect

  my $dbh = $kbs->_connect($dsn, $user, $pass);

This method attempts to connect to PostgreSQL via a given DSN and as a given
user. It returns a database handle on success and C<undef> on failure.

=cut

sub _connect {
    my ($self, $dsn, $user, $pass) = @_;
    require DBI;
    my $dbh = eval {
        DBI->connect_cached( $dsn, $user, $pass, {
            RaiseError     => 0,
            PrintError     => 0,
            pg_enable_utf8 => 1,
            HandleError    => Kinetic::Util::Exception::DBI->handler,
        });
    };
    return $dbh;
}

##############################################################################

=head3 _connect_user

  my $dbh = $kbs->_connect_user($dsn);

This method attempts to connect to PostgreSQL via a given DSN. It connects as
the super user if the super user has been set; otherwise, it connects as the
database user. It returns a database handle on success and C<undef> on
failure. As a side effect, the C<_dbh()> method will also set to the returned
value.


=cut

sub _connect_user {
    my ($self, $dsn) = @_;
    my @credentials;
    if (my $super = $self->db_super_user) {
        @credentials = ($super, $self->db_super_pass);
    } else {
        @credentials = ($self->db_user, $self->db_pass);
    }
    $self->_dbh($self->_connect($dsn, @credentials));
}
##############################################################################

=head3 _dsn

  my $dsn = $kbs->_dsn($db_name);

Returns a DSN appropriate to connect to a given database on the PostgreSQL
database server. The "host" and "port" parts of the DSN may be filled in based
on the values returned by C<db_host()> and C<db_port()>.

=cut

sub _dsn {
    my ($self, $db_name) = @_;
    $db_name ||= $self->db_name;
    my $dsn = "dbi:Pg:dbname=$db_name";
    if (my $host = $self->db_host) {
        $dsn .= ";host=$host";
    }
    if (my $port = $self->db_port) {
        $dsn .= ";port=$port";
    }
    return $dsn;
}

##############################################################################

=head3 _pg_says_true

  print "PostgreSQL says it's true"
    if $kbs->_pg_says_true($sql, @bind_params);

This slightly misnamed method executes the given SQL with the any params. It
expects that the SQL will return one and only one value, and in turn returns
that value.

=cut

sub _pg_says_true {
    my ($self, $sql, @bind_params) = @_;
    my $dbh    = $self->_dbh
      or die "I need a database handle to execute a query";
    my $result = $dbh->selectrow_array($sql, undef, @bind_params);
    return $result;
}

##############################################################################

=head3 _db_exists

  print "Database '$db_name' exists" if $kbs->_db_exists($db_name);

This method tells whether the given database exists.

=cut

sub _db_exists {
    my ($self, $db_name) = @_;
    $db_name ||= $self->db_name;
    $self->_pg_says_true(
        "SELECT datname FROM pg_catalog.pg_database WHERE datname = ?",
        $db_name
    );
}

##############################################################################

=head3 _plpgsql_available

  print "PL/pgSQL is available" if $kbs->_plpgsql_available;

Returns boolean value indicating whether PL/pgSQL is installed in the database
to which we're currently connected. If it's not, super user must control the
install.

=cut

sub _plpgsql_available {
    shift->_pg_says_true(
        'select 1 from pg_catalog.pg_language where lanname = ?',
        'plpgsql'
    );
}

##############################################################################

=head3 _get_template_db_name

  my $template_db_name = $kbs->_get_template_db_name;

Returns the name of the template database. Prompts the user for the name, if
necessary. The template database name will thereafter also be available from
the C<template_db_name()> accessor.

=cut

sub _get_template_db_name {
    my $self = shift;
    $self->{template_db_name} ||= $self->builder->get_reply(
        name        => 'template-db-name',
        label       => 'Template database name',
        message     => 'What template database should I use?',
        default     => 'template1',
        config_keys => [qw(store template_db_name)],
        callback    => sub { $_ } # Must be a true value.
    );
}

##############################################################################

=head3 _user_exists

  print "User exists" if $kbs->_user_exists($user);

This method tells whether a particular PostgreSQL user exists.

=cut

sub _user_exists {
    my ($self, $user) = @_;
    $self->_pg_says_true(
        "select usename from pg_catalog.pg_user where usename = ?",
        $user
    );
}

##############################################################################

=head3 _try_connect

  print "Can connect" if  $kbs->_try_connect($state, $user, $password);

Used by state rules, this method attempts to connect to the database server,
first using the database name and then the template database name. Each DSN
attemped will be stored in under the C<dsn> key in the state object. Returns
the Kinetic::Build::Setup::Store::DB::Pg object on success and C<undef> on failure.
The database handle created by the connection, if any, may be retreived by the
C<_dbh()> method.

=cut

sub _try_connect {
    my ($self, $state, $user, $pass) = @_;
    # Try connecting to the database first.
    $state->{dsn} = [$self->_dsn($self->db_name)];
    my $dbh = $self->_connect( $state->{dsn}[0], $user, $pass);
    if (!$dbh || $self->builder->dev_tests) {
        my $tdb = $self->_get_template_db_name; # Try the template database.
        push @{$state->{dsn}}, $self->_dsn($tdb);
        $dbh = $self->_connect( $state->{dsn}[-1], $user, $pass);
    }
    $self->_dbh($dbh);
}

##############################################################################

=head3 _can_create_db

  print "Iser can create database" if $kbs->_can_create_db;

This method tells whether a particular user has permissions to create
databases.

=cut

sub _can_create_db {
    my $self = shift;
    $self->_pg_says_true(
        "select usecreatedb from pg_catalog.pg_user where usename = ?",
        $self->db_user
    );
}

##############################################################################

=head3 _has_schema_permissions

  print "User has schema permissions"
    if $kbs->_has_schema_permissions;

Returns boolean value indicating whether the database user has the permissions
necessary to create functions, views, triggers, etc. in the database to which
we're currently connected (set by C<_dsn()>).

=cut

sub _has_schema_permissions {
    my $self = shift;
    $self->_pg_says_true(
        'select has_schema_privilege(?, current_schema(), ?)',
        $self->db_user, 'CREATE'
    );
}

##############################################################################

=head3 _is_super_user

  print "User is super user" if $kbs->_is_super_user($user);

Returns boolean value indicating whether the super user is, in fact, the
super user.

=cut

sub _is_super_user {
    my ($self, $user) = @_;
    $self->_pg_says_true(
        "select usesuper from pg_catalog.pg_user where usename = ?",
        $user || $self->db_super_user
    );
}

##############################################################################

=head3 _build_db_name

  my $db_name = $kbs->_build_db_name;
  $kbs->_build_db_name($db_name);

This attribute is set by the C<build()> and C<test_build()> methods to the
name of the database to be built. Used by the action methods to build the
correct database.

=cut

sub _build_db_name {
    my $self = shift;
    return $self->{build_db_name} unless @_;
    return $self->{build_db_name} = shift;
}

##############################################################################

=head3 _build_db_user

  my $db_user = $kbs->_build_db_user;
  $kbs->_build_db_user($db_user);

This attribute is set by the C<build()> and C<test_build()> methods to the
user to be created and granted permissions.

=cut

sub _build_db_user {
    my $self = shift;
    return $self->{build_db_user} unless @_;
    return $self->{build_db_user} = shift;
}

##############################################################################

=head3 _build_db_pass

  my $db_pass = $kbs->_build_db_pass;
  $kbs->_build_db_pass($db_pass);

This attribute is set by the C<build()> and C<test_build()> methods to the
password to be set for the user specified by the C<_build_db_user> attribute.

=cut

sub _build_db_pass {
    my $self = shift;
    return $self->{build_db_pass} unless @_;
    return $self->{build_db_pass} = shift;
}

##############################################################################

=head3 _build_connect

  $kbs->_build_connect($method);

This method is called by C<build_db> and C<build_test_db()>, each of which
pass their own names as arguments. C_build_connect()> then connects to the
appropriate database, overrides warnings so that PostgreSQL "NOTICE"s will be
silently ignored, and then calls the appropriate parent method to actually
create the database.

=cut

sub _build_connect {
    my $self = shift;
    my $meth = 'SUPER::' . shift;

    $self->_dbh(
        $self->_connect_user(
            $self->_dsn( $self->_build_db_name || $self->db_name)
        )
    );

    # Ignore PostgreSQL warnings.
    local $SIG{__WARN__} = sub {
        my $message = shift;
        return if $message =~ /NOTICE:/;
        warn $message;
    };

    $self->$meth(@_);

}

1;
__END__

##############################################################################

=end private

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This work is made available under the terms of Version 2 of the GNU General
Public License. You should have received a copy of the GNU General Public
License along with this program; if not, download it from
L<http://www.gnu.org/licenses/gpl.txt> or write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

This work is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License Version 2 for more
details.

=cut
