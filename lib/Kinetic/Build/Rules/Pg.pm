package Kinetic::Build::Rules::Pg;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or derivatives to
# this work, or any other work intended for use with the Kinetic framework, to
# Kineticode, Inc., you confirm that you are the copyright holder for those
# contributions and you grant Kineticode, Inc.  a nonexclusive, worldwide,
# irrevocable, royalty-free, perpetual license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute those
# contributions and any derivatives thereof.

use strict;
use warnings;

use base 'Kinetic::Build::Rules';
use App::Info::RDBMS::PostgreSQL;

=head1 Name

Kinetic::Build::Rules::Pg - Validate Pg installation

=head1 Synopsis

  use strict;
  use Kinetic::Build::Rules::Pg;

  my $rules = Kinetic::Build::Rules::Pg->new($build);
  $rules->validate;

=head1 Description

Merely provides the C<App::Info> class and the state machine necessary to
validate the Pg install.

This is a subclass of C<Kinetic::Build::Rules>.  See that module for more
information.

=cut

##############################################################################

=head1 Class Methods

=head2 Public Class Methods

=cut

=head2 info_class

 Kinetic::Build::Rules::Pg->info_class;

Returns the class of the C<App::Info> object necessary for gather Pg
metadata.

=cut

sub info_class { 'App::Info::RDBMS::PostgreSQL' }

##############################################################################

=begin private

=head1 Private Methods

=head2 Private Instance Methods

=cut

=head3 _state_machine

  my $state_machine = $rules->_state_machine;

This method returns arguments that the C<FSA::Rules> constructor requires.

=cut

sub _state_machine {
    my $self = shift;
    # XXX There might be a place where we need template0. I'll have to check
    # into that...
    my $template = 'template1'; # default postgresql template
    my $done;
    my $fail    = sub {! shift->result };
    my $succeed = sub {  shift->result };
    my @state_machine = (
        start => {
            do => sub {
                my $state = shift;
                $state->machine->{actions} = []; # must never return to start
                $state->machine->{db_name} = $template;
                $state->result($self->_is_installed);
            },
            rules => [
                fail => {
                    rule    => $fail,
                    message => 'PostgreSQL does not appear to be installed',
                },
                installed => {
                    rule => $succeed,
                    message => 'PostgreSQL does appear to be installed',
                },
            ],
        },
        installed => {
            do => sub {
                my $state   = shift;
                my $build   = $self->build;
                my $machine = $state->machine;

                my $root = $build->db_root_user || 'postgres';
                $build->db_root_user($root);
                # note that we're caching the db name and altering it!
                $self->build->notes(kinetic_db_name => $build->db_name);
                my $dbh = $self->_connect_to_pg(
                    $template,
                    $build->db_root_user,
                    $build->db_root_pass
                ) ;
                $self->build->notes(db_name => $template);
                if ($dbh) {
                    $self->_dbh($dbh);
                    $state->result('can_use_root');
                    $machine->{user}    = $build->db_root_user;
                    $machine->{pass}    = $build->db_root_pass;
                    $machine->{is_root} = 1;
                    return;
                }
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
                can_use_root => {
                    rule    => sub { shift->result eq 'can_use_root' },
                    message => "Root user available and usable",
                },
                can_use_db_user => {
                    rule    => sub { shift->result eq 'can_use_db_user' },
                    message => "Root user not available, but can use db_user",
                },
                fail => {
                    rule => $fail,
                    message => 'Need root user or db user to build database',
                },
            ]
        },
        can_use_root => {
            do => sub { 
                my $state = shift;
                my $db_name = $self->build->notes('kinetic_db_name');
                $state->result($self->_db_exists($db_name));
                if ($state->result) {
                    $self->build->db_name($db_name);
                    $self->build->notes(db_name => $db_name);
                }
                else {
                    push @{$state->machine->{actions}} => ['create_db', $db_name];
                }
                push @{$state->machine->{actions}} => ['switch_to_db', $db_name];
            },
            rules => [
                database_exists => {
                    rule    => $succeed,
                    message => "Database exists",
                },
                no_database => {
                    rule    => $fail,
                    message => 'Database does not exist',
                }
            ],
        },
        no_database => {
            do => sub {
                warn "I don't know how to tie plpgsql to a particular database,\n"
                    ."so I am skipping this for now.\n\n"
                    ."We must also handle the 'createlang' part";
                shift->result('template1 has plpgsql');
            },
            rules => [
                done => {
                    rule    => sub { shift->result eq 'template1 has plpgsql' },
                    message => 'Template1 has plgsql',
                },
                done => {
                    rule    => sub { shift->result eq 'No plpgsql but we have createlang' },
                    message => 'Template1 does not have plpgsql, but we have createlang',
                },
                fail => {
                    rule    => $fail,
                    message => 'Template1 does not have plpgsql and we do  not have createlang',
                }
            ],
        },
        no_plpgsql => {
            do => sub {
                warn "no_plpgsql not yet implemented";
                shift->result('have createlang');
            },
            rules => [
                done => {
                    rule    => sub { shift->result eq 'have createlang' },
                    message => 'have createlang', # note need to add plpgsql
                },
                fail => {
                    rule    => $fail,
                    message => "Must have createlang to add plpgsql",
                }
            ],
        },
        can_use_db_user => {
            do => sub {
                warn "can use db user implementation being deferred";
                shift->result(0); # should not get here; 
            },
            rules => [
                database_exists => {
                    rule => sub { shift->result eq 'database exists' },
                    message => 'Database exists',
                },
                can_create_database => {
                    rule => sub { shift->result eq 'user can create database' },
                    message => "User can create database",
                },
                fail => {
                    rule => $fail,
                    message => "No database, and user has no permission to create it",
                }
            ],
        },
        has_plpgsql => {
            rules => [
                fail => {
                    rule => $fail,
                    message => 'User does not have permission to add objects to database',
                },
                done => {
                    rule => $succeed,
                    message => 'User can add objects to database',
                },
            ],
        },
        can_create_database => {
            do => sub {
                warn "Deferring implementation of can_create_database";
                # we should not get to here
            },
            rules => [
                fail => {
                    rule => $fail,
                    message => 'Template1 does not have plpgsql',
                },
                done => {
                    rule => $succeed,
                    message => 'Template1 has plpgsql',
                }
            ]
        },
        database_exists => {
            do => sub {
                my $state   = shift;
                my $machine = $state->machine;
                unless ($self->_dbh) {
                    my $dbh = $self->_connect_to_pg($template, $machine->{user}, $machine->{pass});
                    $self->_dbh($dbh);
                }
                $state->result($self->_plpgsql_available);
                # but we should not get to here at first
            },
            rules => [
                done => {
                    rule    => sub { 
                        my $state = shift;
                        return $state->result && $state->machine->{is_root};
                    },
                    message => "Database has plpgsql",
                },
                no_plpgsql => {
                    rule    => sub { 
                        my $state = shift;
                        return ! $state->result && $state->machine->{is_root};
                    },
                    message => 'Database does not have plpgsql',
                },
                has_plpgsql => {
                    rule    => sub { 
                        my $state = shift;
                        return $state->result && ! $state->machine->{is_root};
                    },
                    message => 'Database has plpgsql but not root',
                },
                fail => {
                    rule    => sub { 
                        my $state = shift;
                        return ! $state->result && ! $state->machine->{is_root};
                    },
                    message => 'Database does not have plpgsql and not root',
                }
            ]
        },
        fail => {
            do => sub { die shift->prev_state->message || 'no message supplied' },
        },
        done => { 
            do => sub {
                my $state   = shift;
                my $build   = $self->build;
                my $machine = $state->machine;
                foreach my $attribute (qw/db_name actions user pass db_name/) {
                    $build->notes($attribute => $machine->{$attribute});
                }
                $self->_dbh->disconnect;
            }
        },
    );
    return (\@state_machine);
}

sub _dummy_state {
    my ($self, $state, $next, $note) = @_;
    #warn "# dummy state transition from $state to $next";
    #warn "# In state $state:  $note" if $note;
    return $state => { rules => [ $next => sub { 1 } ] };
}

##############################################################################

=head3 _user_exists

  $build->_user_exists($user);

This method tells whether a particular user exists for a given database
handle.

=cut

sub _user_exists {
    my ($self, $user) = @_;
    $self->_pg_says_true(
        "select usename from pg_catalog.pg_user where usename = ?",
        $user
    );
}

##############################################################################

=head3 _is_root_user

  $build->_is_root_user($user);

This method tells whether a particular user is the "root" user for a given
database handle.

=cut

sub _is_root_user {
    my ($self, $user) = @_;
    $self->_pg_says_true(
        "select usesuper from pg_catalog.pg_user where usename = ?",
        $user
    );
}

##############################################################################

=head3 _can_create_db

  $build->_can_create_db($user);

This method tells whether a particular user has permissions to create
databases for a given database handle.

=cut

sub _can_create_db {
    my ($self, $user) = @_;
    $self->_pg_says_true(
        "select usecreatedb from pg_catalog.pg_user where usename = ?",
        $user
    );
}

##############################################################################

=head3 _db_exists

  $build->_db_exists;

This method tells whether the default database exists.

=cut

sub _db_exists {
    my ($self, $db_name) = @_;
    $db_name ||= $self->build->db_name;
    $self->_pg_says_true(
        "select datname from pg_catalog.pg_database where datname = ?",
        $db_name
    );
}

##############################################################################

=head3 _plpgsql_available

  $rules->_plpgsql_available;

Returns boolean value indicating whether C<plpgsql> is available.  If it's not,
super user must control install.

=cut

sub _plpgsql_available {
    my $self = shift;
    $self->_pg_says_true(
        'select 1 from pg_catalog.pg_language where lanname = ?',
        'plpgsql'
    );
}

##############################################################################

=head3 _has_create_permissions

  $rules->_has_create_permissions($user);

Returns boolean value indicating whether given user has permissions to create
functions, views, triggers, etc.

=cut
sub _has_create_permissions {
    my ($self, $user) = @_;
    $self->_pg_says_true(
        'select has_schema_privilege(?, current_schema(), ?)',
        $user, 'CREATE'
    );
}

##############################################################################

=head3 _pg_says_true

  $build->_pg_says_true($dbh, $sql, @bind_params);

This slightly misnamed method executes the given sql with the bind params. It
expects that the SQL will return one and only one value.

=cut

sub _pg_says_true {
    my ($self, $sql, @bind_params) = @_;
    my $dbh    = $self->_dbh;
    my $result = $dbh->selectrow_array($sql, undef, @bind_params);
    return $result;
}

##############################################################################

=head3 _connect_to_pg

  $build->_connect_to_pg($db_name, $user, $pass);

This method attempts to connect to the database as a given user. It returns a
database handle on success and undef on failure.

=cut

sub _connect_to_pg {
    my ($self, $db_name, $user, $pass) = @_;
    my $dbh;
    eval { $dbh = DBI->connect("dbi:Pg:dbname=$db_name", $user, $pass) };
    return $dbh;
}

1;
__END__

#        version => {
#            do => sub {
#                my $state = shift;
#                $state->result($self->_is_required_version);
#                unless ($state->result) {
#                    my $required = $self->build->_required_version;
#                    my $actual   = $self->info->version;
#                    $state->message($self->app_name 
#                        . " required version $required but you have $actual");
#                }
#            },
#            rules  => [
#                fail => $fail,
#                createlang => {
#                    rule    => $succeed,
#                    message => "Pg is required version",
#                },
#            ],
#        },
#        createlang => {
#            do => sub { shift->result($self->info->createlang) },
#            rules => [
#                fail     => {
#                    rule    => $fail,
#                    message => "createlang is required for plpgsql support",
#                },
#                metadata => {
#                    rule    => $succeed,
#                    message => "createlang is installed",
#                },
#            ],
#        },
#        # XXX Change this?
#        $self->_dummy_state('metadata', 'root_user'),
#        root_user => {
#            do => sub {
#                my $state = shift;
#                my $root = $self->build->db_root_user || 'postgres';
#                $self->build->db_root_user($root);
#                my $dbh  = $self->_connect_as_root($template);
#                $state->result($dbh);
#                $self->_dbh($dbh);
#                $state->message("User ($root) is not a root user or does not exist.")
#                  unless $state->result;
#            },
#            rules => [
#                user => $fail,
#                done => {
#                    rule    => $succeed,
#                    message => "root is available",
#                },
#            ],
#        },
#        user => {
#            do => sub {
#                my $state = shift;
#                my $dbh = $self->_connect_as_user($template);
#                $state->result($dbh);
#                $self->_dbh($dbh);
#            },
#            rules => [
#                fail => {
#                    rule    => $fail,
#                    message => "Could not connect as normal user",
#                },
#                database_exists => {
#                    rule    => $succeed,
#                    message => "user available",
#                },
#            ],
#        },
#        database_exists => {
#            do => sub {
#                my $state = shift;
#                $state->result($self->_db_exists($self->build->db_name));
#            },
#            rules => [
#                can_create_database => {
#                    rule    => $fail,
#                    message => "The default database does not exist",
#                },
#                plpgsql             => {
#                    rule    => $succeed,
#                    message => "The default database does exist",
#                },
#            ],
#        },
#        can_create_database => {
#            do => sub {
#                my $state = shift;
#                $state->result($self->_can_create_db($self->build->db_user));
#            },
#            rules => [
#                fail => {
#                    rule    => $fail,
#                    message => "Normal user does not have the right to create the database",
#                },
#                done => {
#                    rule    => $succeed,
#                    message => "can create database",
#                },
#            ],
#        },
#        plpgsql => {
#            do => sub {
#                my $state = shift;
#                $state->result($self->_plpgsql_available);
#            },
#            rules => [
#                fail              => {
#                    rule    => $fail,
#                    message => "plpgsql not available.  Must be root user to install.",
#                },
#                check_permissions => {
#                    rule    => $succeed,
#                    message => "plpgsql available",
#                },
#            ],
#        },
#        check_permissions => {
#            do => sub {
#                my $state = shift;
#                $state->result($self->_has_create_permissions($self->build->db_user));
#            },
#            rules => [
#                fail => {
#                    rule    => $fail,
#                    message => 'User does not have permission to create objects',
#                },
#                done => {
#                    rule    => $succeed,
#                    message => "user can create objects",
#                },
#            ]
#        },
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
