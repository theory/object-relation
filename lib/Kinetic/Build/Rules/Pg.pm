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

=head1 Private Methods

=head2 Private Instance Methods

=cut

=head3 _state_machine

  my ($state_machine, $start_state, $end_func) = $rules->_state_machine;

This method returns arguments that the C<DFA::Rules> constructor
requires.

=cut

sub _state_machine {
    my $self = shift;
    my $template = 'template1'; # default postgresql template
    my $done;
    my $fail    = sub {! shift->result };
    my $succeed = sub {  shift->result } ;
    my @state_machine = (
        installed => {
            on_enter => sub { 
                my $machine = shift;
                $machine->set_result($self->_is_installed);
                $machine->set_message($self->app_name ." does not appear to be installed" )
                  unless $machine->result;
            },
            rules  => [
                fail    => $fail,
                version => $succeed,
            ],
        },
        version => {
            on_enter => sub { 
                my $machine = shift;
                $machine->set_result($self->_is_required_version);
                unless ($machine->result) {
                    my $required = $self->build->_required_version;
                    my $actual   = $self->info->version;
                    $machine->set_message($self->app_name 
                        . " required version $required but you have $actual");
                }
            },
            rules  => [
                fail       => $fail,
                createlang => $succeed,
            ],
        },
        createlang => {
            on_enter => sub {
                my $machine = shift;
                $machine->set_result($self->info->createlang);
                $machine->set_message("createlang is required for plpgsql support")
                  unless $machine->result;
            },
            rules => [
                fail     => $fail,
                metadata => $succeed,
            ],
        },
        $self->_dummy_state('metadata', 'user'),
        user => {
            on_enter => sub {
                my $machine = shift;
                my $dbh = $self->_connect_as_user($template);
                $machine->set_result($dbh);
                $machine->set_message("Could not connect as normal user")
                  unless $dbh;
                $self->_dbh($dbh);
            },
            rules => [
                root_user       => $fail,
                database_exists => $succeed
            ],
        },
        root_user => {
            on_enter => sub {
                my $machine = shift;
                my $root = $self->build->db_root_user || 'postgres';
                $machine->set_result($root);
                $self->build->db_root_user($root);
            },
            rules => [
                #fail               => $fail,
                validate_root_user => $succeed,
            ],
        },
        validate_root_user => {
            on_enter => sub {
                my $machine = shift;
                my $root = $self->build->db_root_user;
                my $dbh  = $self->_connect_as_root($template);
                $machine->set_result($dbh);
                $self->_dbh($dbh);
                $machine->set_message("User ($root) is not a root user or does not exist.")
                  unless $machine->result;
            },
            rules => [
                fail => $fail,
                done => $succeed,
            ],
        },
        database_exists => {
            on_enter => sub {
                my $machine = shift;
                $machine->set_result($self->_db_exists($self->build->db_name));
                $machine->set_message("The default database does not exist")
                  unless $machine->result;
            },
            rules => [
                can_create_database => $fail,
                plsql               => $succeed,
            ],
        },
        can_create_database => {
            on_enter => sub {
                my $machine = shift;
                $machine->set_result($self->_can_create_db($self->build->db_user));
                $machine->set_message("Normal user does not have the right to create the database")
                  unless $machine->result;
            },
            rules => [
                root_user => $fail,
                done      => $succeed,
            ],
        },
        $self->_dummy_state('plsql',         'check_permissions', 'fail should goto can_add_plsql'),
        $self->_dummy_state('can_add_plsql', 'check_permissions', 'this state currently cannot be reached'),
        $self->_dummy_state('check_permissions', 'done', 'fail should goto root_user'),
        fail => {
            on_enter => sub { 
                my $machine = shift;
                die $machine->message($machine->prev_state) || 'no message supplied';
            },
        },
        done => { do => sub { $done = 1 } }
    );
    return (\@state_machine, sub {$done});
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

=head3 _pg_says_true

  $build->_pg_says_true($dbh, $sql, @bind_params);

This slightly misnamed method executes the given sql with the bind params. It
expects that the SQL will return one and only one value.

=cut

sub _pg_says_true {
    my ($self, $sql, @bind_params) = @_;
    return ($self->_dbh->selectrow_array($sql, undef, @bind_params));
}

##############################################################################

=head3 _connect_as_user

  $build->_connect_as_user($db_name);

This method attempts to connect to the database as a normal user. It returns a
database handle on success and undef on failure.

=cut

sub _connect_as_user {
    my ($self, $db_name) = @_;
    $self->_connect_to_pg($db_name, $self->build->db_user, $self->build->db_pass);
}

##############################################################################

=head3 _connect_as_root

  $build->_connect_as_root($db_name);

This method attempts to connect to the database as a root user. It returns a
database handle on success and undef on failure.

=cut

sub _connect_as_root {
    my ($self, $db_name) = @_;
    $self->_connect_to_pg($db_name, $self->build->db_root_user, $self->build->db_root_pass);
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
    eval { $dbh = DBI->connect($self->_dsn, $user, $pass) };
    return $dbh;
}

1;
