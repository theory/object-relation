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

  my ($state_machine, $start_state, $end_func) = $rules->_state_machine;

This method returns arguments that the C<Kinetic::Util::DFA> constructor
requires.

=cut

sub _state_machine {
    my $self = shift;
    my ($message, $done, $filename);
    my %state_machine = (
        start => {
            enter => sub { 
                $message = $self->app_name ." does not appear to be installed" 
                  unless $self->_is_installed;
            },
            goto  => [
                fail          => [ sub {! $self->_is_installed} ],
                check_version => [ sub {  $self->_is_installed} ],
            ],
        },
        check_version => {
            enter => sub { 
                $message = $self->app_name . " is not the minimum required version"
                  unless $self->_is_required_version;
            },
            goto  => [
                fail           => [ sub { ! $self->_is_required_version } ],
                check_executable => [ sub { $self->_is_required_version } ],
            ],
        },
        check_executable => {
            enter => sub {
                $message = "DBD::SQLite is installed but we require the sqlite3 executable"
                  unless $self->_has_executable;
            },
            leave => sub {
                use Devel::StackTrace;
                #warn Devel::StackTrace->new;
                #warn "leaving the check_executable state";
            },
            goto => [
                fail      => [
                    sub {
                        my $dfa = shift;
                        #use Data::Dumper::Simple;
                        #warn Dumper($dfa, $self->{dfa}{names});
                        return ! $self->_has_executable;
                    },
                ],
                file_name => [ sub { $self->_has_executable } ],
            ],
        },
        file_name => {
            enter => sub {
                my $build = $self->build;
                $filename = $build->db_name 
                  || $build->prompt('Please enter a filename for the SQLite database');
                $self->build->db_name($filename);
            },
            goto => [ file_name => [ sub { ! $filename } ] ],
        },
        fail => {
            enter => sub { $message ||= "no message supplied"; die $message },
        },
    );
    return (\%state_machine, 'start', sub {$filename});
}

1;
