package Kinetic::Build::Store::DB::Pg;

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
use base 'Kinetic::Build::Store::DB';
use Kinetic::Build;
use App::Info::RDBMS::PostgreSQL;

=head1 Name

Kinetic::Build::Store::DB::Pg - Kinetic PostgreSQL data store builder

=head1 Synopsis

See L<Kinetic::Build::Store|Kinetic::Build::Store>.

=head1 Description

This module inherits from Kinetic::Build::Store::DB to build a PostgreSQL data
store. Its interface is defined entirely by Kinetic::Build::Store.

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 info_class

  my $info_class = Kinetic::Build::Store::DB::Pg->info_class

This abstract class method returns the name of the C<App::Info> class for the
data store. Must be overridden in subclasses.

=cut

sub info_class { 'App::Info::RDBMS::PostgreSQL' }

##############################################################################

=head3 min_version

  my $version = Kinetic::Build::Store::DB::Pg->min_version

This abstract class method returns the minimum required version number of the
data store application. Must be overridden in subclasses.

=cut

sub min_version { '7.4.5' }

=head3 dbd_class

  my $dbd_class = Kinetic::Build::Store::DB::Pg->dbd_class;

This abstract class method returns the name of the DBI database driver class,
such as "DBD::Pg" or "DBD::Pg". Must be overridden in subclasses.

=cut

sub dbd_class { 'DBD::Pg' }

##############################################################################

=head3 rules

  my @rules = Kinetic::Build::Store::DB::SQLite->rules;

This is an abstract method that must be overridden in a subclass. By default
it must return arguments that the C<FSA::Rules> constructor requires.

=cut

sub rules {
    my $self     = shift;
    my $template = 'template1'; # default postgresql template
    my $fail     = sub {! shift->result };
    my $succeed  = sub {  shift->result };
    return (
        Start => {
            do => sub {
                my $state = shift;
                $state->machine->{actions} = []; # must never return to start
                $state->result($self->info->installed);
            },
            rules => [
                Fail => {
                    rule    => $fail,
                    message => 'PostgreSQL does not appear to be installed',
                },
                "Server info" => {
                    rule    => $succeed,
                    message => 'PostgreSQL does appear to be installed',
                },
            ],
        },

        "Server info" => {
            do => sub {
                my $state = shift;
                my $build = $self->build;

                # Get the host name.
                $self->{db_host} = $build->prompt(
                    "PostgreSQL server hostname [localhost]? ",
                    $ENV{PGHOST} || undef,
                );

                # Get the port number.
                if ($ENV{PGPORT}) {
                    $self->{db_port} = $ENV{PGPORT};
                } else {
                    my ($def_port, $def_label) = defined $self->{db_host}
                      ? ('5432', '5432')
                        : (undef, 'local domain socket');
                    $self->{db_port} = $ENV{PGHOST} || $build->prompt(
                        "PostgreSQL server port [$def_label]? ",
                        $def_port,
                    );
                }

                # Get the database name.
                $self->{db_name} = $ENV{DBDATABASE} || $build->prompt(
                    "Database name to use for the application [kinetic]? ",
                    'kinetic',
                );

                # Get the database user.
                $self->{db_user} = $ENV{PGUSER} || $build->prompt(
                    "Database user the application will use [kinetic]? ",
                    'kinetic',
                );

                # Get the database user's password.
                $self->{db_user} = $ENV{PGUSER} || $build->prompt(
                    "Database user's password (can be blank) []? ",
                    '',
                );
            },
            rules => [
                Fail => {
                    rule    => sub { !$self->db_name },
                    message => 'You must provide a database name',
                },
                "Server info" => {
                    rule    => sub { $self->db_name },
                    message => 'PostgreSQL does appear to be installed',
                },
            ],
        },

        "Determine user" => {
            do => sub {
                my $state   = shift;
                my $build   = $self->builder;
                my $machine = $state->machine;
                my $root    = $build->args('db_super_user') || 'postgres';

                # Try connecting as root user.
                my $dbh = $self->_connect_to_pg(
                    $template,
                    $build->db_root_user,
                    $build->db_root_pass
                );
                if ($dbh) {
                    $self->_dbh($dbh);
                    $state->result('can_use_root');
                    $machine->{user}    = $build->db_root_user;
                    $machine->{pass}    = $build->db_root_pass;
                    $machine->{is_root} = 1;
                    return;
                }

                # If we get here, try connecting as app user.
                $dbh = $self->_connect_to_pg(
                    $template,
                    $build->db_user,
                    $build->db_pass,
                );
                if ($dbh) {
                    $self->_dbh($dbh);
                    $state->result('can_use_db_user');
                    $machine->{user}    = $build->db_user;
                    $machine->{pass}    = $build->db_pass;
                    $machine->{is_root} = 0;
                    return;
                }
            },
            rules => [
                Fail => {
                    rule => $fail,
                    message => 'Need root user or db user to build database',
                },
                "Check for user db and is root" => {
                    rule    => sub { shift->result eq 'can_use_root' },
                    message => "Root user available and usable",
                },
                "Check for user db and is not root" => {
                    rule    => sub { shift->result eq 'can_use_db_user' },
                    message => "Root user not available, but can use db_user",
                },
            ]
        },
        "Check for user db and is root" => {
            do => sub {
                my $state = shift;
                my $db_name = $self->build->notes('kinetic_db_name');
                $state->result($self->_db_exists($db_name));
                $state->machine->{database_exists} = $state->result;
                if ($state->result) {
                    $self->build->db_name($db_name);
                    $self->build->notes(db_name => $db_name);
                } else {
                    # Set template1 as the db name so we start out by
                    # connecting to it when it comes time to create
                    # the database.
                    $self->build->db_name($template);
                    push @{$state->machine->{actions}} => ['create_db', $db_name];
                }
                push @{$state->machine->{actions}} => ['switch_to_db', $db_name];
            },
            rules => [
                "Check user db for plpgsql" => {
                    rule    => $succeed,
                    # XXX Yes, please do.
                    message => "Database kinetic exists",  # XXX fix this
                },
                "Check template1 for plpgsql and is root" => {
                    rule    => $fail,
                    message => "Database kinetic does not exist", # XXX fix this
                }
            ],
        },
        "Check template1 for plpgsql and is root" => {
            do => sub {
                my $state = shift;
                if ($self->_plpgsql_available) {
                    $state->result('template1 has plpgsql');
                } elsif ($self->info->createlang) {
                    $state->result('No plpgsql but we have createlang');
                    push @{$state->machine->{actions}} => [
                        'add_plpgsql_to_db',
                        # XXX Are you sure that this is template1?
                        $self->build->notes('kinetic_db_name')
                    ];
                }
            },
            rules => [
                Fail => {
                    rule    => sub { shift->machine->{db_name} ne $template },
                    message => "Panic state. Cannot check template1 for plpgsql if we're not connected to it.",
                },
                Fail => {
                    rule    => $fail,
                    message => 'Template1 does not have plpgsql and we do not have createlang',
                },
                Done => {
                    rule    => sub { shift->result eq 'template1 has plpgsql' },
                    message => 'Template1 has plgsql',
                },
                Done => {
                    rule    => sub { shift->result eq 'No plpgsql but we have createlang' },
                    message => 'Template1 does not have plpgsql, but we have createlang',
                },
            ],
        },
        "Check for createlang" => {
            do => sub {
                my $state   = shift;
                $state->result($self->info->createlang);
                push @{$state->machine->{actions}} => ['add_plpgsql_to_db', $self->build->db_name];
            },
            rules => [
                Done => {
                    rule    => $succeed,
                    message => 'We have createlang',
                },
                Fail => {
                    rule    => $fail,
                    message => "Must have createlang to add plpgsql",
                }
            ],
        },
        "Check for user db and is not root" => {
            do => sub {
                my $state = shift;
                my $db_name = $self->build->notes('kinetic_db_name');
                if ($self->_db_exists($db_name)) {
                    $state->result('database exists');
                }
                elsif ($self->_can_create_db($state->machine->{user})) {
                    $state->result('user can create database');
                    push @{$state->machine->{actions}} => ['create_db', $db_name];
                }
                push @{$state->machine->{actions}} => ['switch_to_db', $db_name];
            },
            rules => [
                Fail => {
                    rule => $fail,
                    message => "No database, and user has no permission to create it",
                },
                "Check user db for plpgsql" => {
                    rule => sub { shift->result eq 'database exists' },
                    message => 'Database exists',
                },
                "Check template1 for plpgsql and is not root" => {
                    rule => sub { shift->result eq 'user can create database' },
                    message => "User can create database",
                },
            ],
        },
        "Check user create permissions" => {
            do => sub {
                my $state = shift;
                my $user  = $state->machine->{user};
                $state->result($self->_has_create_permissions($user));
            },
            rules => [
                Fail => {
                    rule    => $fail,
                    message => 'User does not have permission to add objects to database',
                },
                Done => {
                    rule    => $succeed,
                    message => 'User can add objects to database',
                },
            ],
        },
        "Check template1 for plpgsql and is not root" => {
            do => sub {
                shift->result($self->_plpgsql_available);
            },
            rules => [
                Fail => {
                    rule    => sub { shift->machine->{db_name} ne $template },
                    message => "Panic state.  Cannot check template1 for plpgsql if we're not connected to it.",
                },
                Fail => {
                    rule    => $fail,
                    message => 'Template1 does not have plpgsql',
                },
                Done => {
                    rule    => $succeed,
                    message => 'Template1 has plpgsql',
                }
            ]
        },
        "Check user db for plpgsql" => {
            do => sub {
                my $state   = shift;
                my $machine = $state->machine;
                my $db_name = $self->build->notes('kinetic_db_name');
                $machine->{db_name} = $db_name; # force the connection to the actual database
               my $dbh = $self->_connect_to_pg(
                    $db_name,
                    $machine->{user},
                    $machine->{pass},
                );
                $self->_dbh($dbh); # force a new dbh
                $state->result($self->_plpgsql_available);
            },
            rules => [
                Done => {
                    rule => sub {
                        my $state = shift;
                        return $state->result && $state->machine->{is_root};
                    },
                    # XXX Love to see the database name in these messages. Are
                    # messages printed out as we go along?
                    # XXX They should be! Use a package-scoped scalar to set the
                    # DB name for these messages, eh? You'll want to modify them
                    # to be appropriate for output during installation, too.
                    message => "Database has plpgsql",
                },
                "Check for createlang" => {
                    rule    => sub {
                        my $state = shift;
                        return ! $state->result && $state->machine->{is_root};
                    },
                    message => 'Database does not have plpgsql',
                    action  => [sub {
                        my $machine = shift->machine;
                        push @{$machine->{actions}} => ['add_plpgsql_to_db', $machine->{db_name}];
                    }],
                },
                "Check user create permissions" => {
                    rule    => sub {
                        my $state = shift;
                        return $state->result && ! $state->machine->{is_root};
                    },
                    message => 'Database has plpgsql but not root',
                },
                Fail => {
                    rule    => sub {
                        my $state = shift;
                        return ! $state->result && ! $state->machine->{is_root};
                    },
                    message => 'Database does not have plpgsql and not root',
                }
            ]
        },
        Fail => {
            do => sub { die shift->prev_state->message || 'no message supplied' },
        },
        Done => {
            do => sub {
                my $state   = shift;
                my $build   = $self->build;
                my $machine = $state->machine;
                push @{$machine->{actions}} => ['build_db']
                  unless $machine->{database_exists};
                foreach my $attribute (qw/actions user pass db_name/) {
                    $build->notes($attribute => $machine->{$attribute})
                      if $machine->{$attribute};
                }
                $self->_dbh->disconnect if $self->_dbh;
                $build->notes(stacktrace => $machine->stacktrace);
            }
        },
    );
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
"kinetic". Not used by the SQLite data store.

=cut

sub db_user { shift->{db_user} }

##############################################################################

=head3 db_pass

  my $db_pass = $kbs->db_pass;
  $kbs->db_pass($db_pass);

The password for the database user specified by the C<db_user> attribute.
Defaults to "kinetic". Not used by the SQLite data store.

=cut

sub db_pass { shift->{db_pass} }

##############################################################################

=head3 db_super_user

  my $db_super_user = $kbs->db_super_user;
  $kbs->db_super_user($db_super_user);

The super or admin database user, which will be used to create the Kinetic
database and user if they don't already exist. The default is the typical super
user name for the seleted data store. Not used by the SQLite data store.

Defaults to postgres.

=cut

sub db_super_user { shift->{db_super_user} }

##############################################################################

=head3 db_super_pass

  my $db_super_pass = $kbs->db_super_pass;
  $kbs->db_super_pass($db_super_pass);

The password for the super or admin database user. An empty string by
default. Not used by the SQLite data store.

=cut

sub db_super_pass { shift->{db_super_pass} }

##############################################################################

=head3 db_host

  my $db_host = $kbs->db_host;
  $kbs->db_host($db_host);

The host name of the Kinetic database server. Undefind by default, which
generally means that the connection will be made to localhost via Unix
sockets. Not used by the SQLite data store.

=cut

sub db_host { shift->{db_host} }

##############################################################################

=head3 db_port

  my $db_port = $kbs->db_port;
  $kbs->db_port($db_port);

The port number of the Kinetic database server. Undefind by default, which
generally means that the connection will be made to the default port for the
database. Not used by the SQLite data store.

=cut

sub db_port { shift->{db_port} }

##############################################################################

=head3 _dbh

  $kbs->_dbh;

Returns the database handle to connect to the data store.

=cut

sub _dbh {
    my $self = shift;
    if (@_) {
        $self->{dbh} = shift;
        return $self;
    }
    return $self->{dbh} if $self->{dbh};
    my $builder = $self->builder;
    my $dsn   = $builder->_dsn;
    my $user  = $builder->notes->{user};
    my $pass  = $builder->notes->{pass};
    my $dbh = DBI->connect($dsn, $user, $pass, {RaiseError => 1})
      or require Carp && Carp::croak $DBI::errstr;
    $self->{dbh} = $dbh;
    return $dbh;
}

##############################################################################

=head1 ACTIONS

=head2 PostgreSQL specific actions

The following actions are all specific to PostgreSQL.  They may be
reimplemented in other classes.

=cut

=head3 create_db

  $kbs->create_db($db_name);

Attempts to create a database with the supplied named.  It uses Unicode encoding.
It will disconnect from the database when done.

=cut

sub create_db {
    my ($self, $db_name) = @_;
    my $dbh = $self->_dbh;
    $dbh->do(qq{CREATE DATABASE "$db_name" WITH ENCODING = 'UNICODE'});
    $dbh->disconnect;
    return $self;
}

##############################################################################

=head3 add_plpgsql_to_db

  $kbs->add_plpgsql_to_db($db_name);

Given a database name, this method will attemt to add C<plpgsql> to the
database.

=cut

sub add_plpgsql_to_db {
    my ($self, $db_name) = @_;
    # createlang -U postgres plpgsql template1
    my $builder    = $self->builder;
    my $info        = App::Info::RDBMS::PostgreSQL->new;
    my $createlang  = $info->createlang or die "Cannot find createlang";
    my $root_user   = $builder->db_root_user;
    my @options;
    my %options = (
        db_host      => '-h',
        db_port      => '-p',
        db_root_user => '-U',
    );
    while (my ($method, $switch) = each %options) {
        push @options => ($switch, $builder->$method) if defined $builder->$method;
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

=head3 config

This method is called by C<process_conf_files()> to populate the PostgreSQL
section of the configuration files. It returns a list of lines to be included
in the section, configuring the "db_name", "db_user", "db_pass", "host", and
"port" directives.

=cut

sub config {
    my $self = shift;
    return unless $self->store eq 'pg';
    return (
        "    db_name => '" . $self->db_name . "',\n",
        "    db_user => '" . $self->db_user . "',\n",
        "    db_pass => '" . $self->db_pass . "',\n",
        "    host    => " . (defined $self->db_host ? "'" . $self->db_host . "'" : 'undef'), ",\n",
        "    port    => " . (defined $self->db_port ? "'" . $self->db_port . "'" : 'undef'), ",\n",
    );
}

##############################################################################

=head3 test_config

This method is called by C<process_conf_files()> to populate the PostgreSQL
section of the configuration file used during testing. It returns a list of
lines to be included in the section, configuring the "db_name", "db_user", and
"db_pass" directives, which are each set to the temporary value
"__kinetic_test__"; and "host", and "port" directives as specified via the
"db_host" and "db_port" properties.

=cut

sub test_config {
    my $self = shift;
    return unless $self->store eq 'pg';
    return (
        "    db_name => '__kinetic_test__',\n",
        "    db_user => '__kinetic_test__',\n",
        "    db_pass => '__kinetic_test__',\n",
        "    host    => " . (defined $self->db_host ? "'" . $self->db_host . "'" : 'undef'), ",\n",
        "    port    => " . (defined $self->db_port ? "'" . $self->db_port . "'" : 'undef'), ",\n",
    );
}

=begin private

##############################################################################

=head1 Private Interface

=head2 Private Instance Methods

=head3 _connect_to_pg

  my $dbh = $kbs->_connect_to_pg($db_name, $user, $pass);

This method attempts to connect to the database as a given user. It returns a
database handle on success and C<undef> on failure.

=cut

sub _connect_to_pg {
    my ($self, $db_name, $user, $pass) = @_;
    my $dbh;
    eval {
        $dbh = DBI->connect(
            "dbi:Pg:dbname=$db_name",
            $user,
            $pass,
            { RaiseError => 1, AutoCommit => 0 }
        )
    };
    return $dbh;
}

1;
__END__

##############################################################################

=end private

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. <info@kineticode.com>

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
