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

    my $fail    = sub {! shift->result };
    my $succeed = sub {  shift->result };

    my @state_machine = (
        start => {
            do => sub {
                my $state = shift;
                $state->machine->{actions} = []; # must never return to start
                $state->result($self->_is_installed);
             },
            rules => [
                fail => {
                    rule    => $fail,
                    message => 'SQLite does not appear to be installed',
                },
                check_version => {
                    rule    => $succeed,
                    message => 'SQLite is installed',
                },
            ],
        },
        check_version => {
            do => sub { shift->result($self->_is_required_version) },
            rules  => [
                fail => {
                    rule    => $fail,
                    message => 'SQLite is not the minimum required version',
                },
                file_name => {
                    rule    => $succeed,
                    message => 'SQLite is the minimum required version',
                },
            ],
        },
        file_name => {
            do => sub {
                my $state = shift;
                my $build = $self->build;
                my $filename = $build->db_file
                  || $build->prompt('Please enter a filename for the SQLite database');
                $self->build->db_file($filename);
                $state->result($filename);
            },
            rules => [
                file_name => {
                    rule    => $fail,
                    message => 'No filename for database',
                },
                Done => {
                    rule    => $succeed,
                    message => 'We have a filename',
                }
            ],
        },
        Done => {
            do => sub {
                my $state   = shift;
                my $build   = $self->build;
                my $machine = $state->machine;
                push @{$machine->{actions}} => ['build_db'];
                foreach my $attribute (qw/db_file actions user pass/) {
                    $build->notes($attribute => $machine->{$attribute})
                      if $machine->{$attribute};
                }
                $self->_dbh->disconnect if $self->_dbh;
            }
        },
        fail => {
            do => sub {
                my $state = shift;
                # XXX Use $build->_fatal_error()?
                die $state->prev_state->message
                  || "no message supplied";
            },
        },
    );
    return (\@state_machine);
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
