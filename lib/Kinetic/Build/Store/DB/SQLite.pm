package Kinetic::Build::Store::DB::SQLite;

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
use DBI;
use Kinetic::Build;
use App::Info::RDBMS::SQLite;

=head1 Name

Kinetic::Build::Store::DB::SQLite - Kinetic SQLite data store builder

=head1 Synopsis

See L<Kinetic::Build::Store|Kinetic::Build::Store>.

=head1 Description

This module inherits from Kinetic::Build::Store::DB to build a SQLite data
store. Its interface is defined entirely by Kinetic::Build::Store.

=cut

##############################################################################

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 info_class

  my $info_class = Kinetic::Build::Store::DB->info_class

This abstract class method returns the name of the C<App::Info> class for the
data store. Must be overridden in subclasses.

=cut

sub info_class { 'App::Info::RDBMS::SQLite' }

##############################################################################

=head3 min_version

  my $version = Kinetic::Build::Store::DB::SQLite->min_version

This abstract class method returns the minimum required version number of the
data store application. Must be overridden in subclasses.

=cut

sub min_version { '3.0.8' }

=head3 dbd_class

  my $dbd_class = Kinetic::Build::Store::DB::SQLite->dbd_class;

This abstract class method returns the name of the DBI database driver class,
such as "DBD::Pg" or "DBD::SQLite". Must be overridden in subclasses.

=cut

sub dbd_class { 'DBD::SQLite' }

##############################################################################

=head3 rules

  my @rules = Kinetic::Build::Store::DB::SQLite->rules;

This is an abstract method that must be overridden in a subclass. By default
it must return arguments that the C<FSA::Rules> constructor requires.

=cut

sub rules {
    my $self = shift;

    my $fail    = sub {! shift->result };
    my $succeed = sub {  shift->result };

    return (
        start => {
            do => sub {
                my $state = shift;
                $state->machine->{actions} = []; # must never return to start
                $state->result($self->info->installed);
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
            do => sub { shift->result($self->is_required_version) },
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
                my $builder = $self->builder;
                my $filename = $builder->db_file
                  || $builder->prompt('Please enter a filename for the SQLite database');
                $builder->db_file($filename);
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
                my $builder   = $self->builder;
                my $machine = $state->machine;
                push @{$machine->{actions}} => ['build_db'];
                foreach my $attribute (qw/db_file actions user pass/) {
                    $builder->notes($attribute => $machine->{$attribute})
                      if $machine->{$attribute};
                }
#                $self->_dbh->disconnect if $self->_dbh;
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
}

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Instance Methods


=cut

1;
__END__

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
