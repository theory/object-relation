package Kinetic::Build::Rules::SQLite;

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
use App::Info::RDBMS::SQLite;

=head1 Name

Kinetic::Build::Rules::SQLite - Validate SQLite installation

=head1 Synopsis

  use strict;
  use Kinetic::Build::Rules::SQLite;

  my $rules = Kinetic::Build::Rules::SQLite->new($build);
  $rules->validate;

=head1 Description

Merely provides the C<App::Info> class and the state machine necessary to
validate the SQLite install.

This is a subclass of C<Kinetic::Build::Rules>.  See that module for more
information.

=cut

##############################################################################

=head1 Class Methods

=head2 Public Class Methods

=cut

=head2 info_class

 Kinetic::Build::Rules::SQLite->info_class;

Returns the class of the C<App::Info> object necessary for gather SQLite
metadata.

=cut

sub info_class { 'App::Info::RDBMS::SQLite' }

##############################################################################

=head1 Private Methods

=head2 Private Instance Methods

=cut

=head3 _state_machine

  my ($state_machine, $end_func) = $rules->_state_machine;

This method returns arguments that the C<FSA::Rules> constructor
requires.

=cut

sub _state_machine {
    my $self = shift;
    my ($done, $filename);
    my $fail    = sub {! shift->result };
    my $succeed = sub {  shift->result };
    my @state_machine = (
        start => {
            do => sub { 
                my $state = shift;
                $state->result($self->_is_installed);
                $state->message($self->app_name ." does not appear to be installed" )
                  unless $state->result;
            },
            rules => [
                fail          => $fail,
                check_version => $succeed,
            ],
        },
        check_version => {
            do => sub { 
                my $state = shift;
                $state->result($self->_is_required_version);
                $state->message($self->app_name . " is not the minimum required version")
                  unless $state->result;
            },
            rules  => [
                fail             => $fail,
                check_executable => $succeed,
            ],
        },
        check_executable => {
            do => sub {
                my $state = shift;
                $state->result($self->_has_executable);
                $state->message("DBD::SQLite is installed but we require the sqlite3 executable")
                  unless $state->result;
            },
            rules => [
                fail      => $fail,
                file_name => $succeed,
            ],
        },
        file_name => {
            do => sub {
                my $state = shift;
                my $build = $self->build;
                $filename = $build->db_name 
                  || $build->prompt('Please enter a filename for the SQLite database');
                $self->build->db_name($filename);
                $state->result($filename);
            },
            rules => [ file_name => $fail ],
        },
        fail => {
            do => sub { 
                my $state = shift;
                die $state->prev_state->message
                  || "no message supplied";
            },
        },
    );
    return (\@state_machine, sub {$filename});
}

1;
