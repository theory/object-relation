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
use File::Spec::Functions;

=head1 Name

Kinetic::Build::Store::DB::SQLite - Kinetic SQLite data store builder

=head1 Synopsis

See L<Kinetic::Build::Store|Kinetic::Build::Store>.

=head1 Description

This module inherits from Kinetic::Build::Store::DB to build a SQLite data
store. Its interface is defined entirely by Kinetic::Build::Store.

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 info_class

  my $info_class = Kinetic::Build::Store::DB::SQLite->info_class

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
                $self->{actions} = []; # must never return to start
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
                $self->{db_file} = $builder->args('db_file')
                  || $builder->get_reply(
                      message => 'Please enter a filename for the SQLite database',
                      default => 'kinetic.db'
                );
            },
            rules => [
                file_name => {
                    rule    => sub { ! $self->db_file },
                    message => 'No filename for database',
                },
                Done => {
                    rule    => 1,
                    message => 'We have a filename',
                }
            ],
        },
        Done => {
            do => sub {
                push @{$self->{actions}} => ['build_db'];
            }
        },
        fail => {
            do => sub {
                my $state = shift;
                $self->builder->_fatal_error(
                    $state->prev_state->message
                      || "no message supplied"
                );
            },
        },
    );
}

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Instance Accessors

=head3 db_file

  my $db_file = $kbs->db_file;

Returns the name of the file to be used for the SQLite database. This is a
read-only attribute set by the call to the C<validate()> method.

=cut

sub db_file { shift->{db_file} }

##############################################################################

=head3 dsn

  my $dsn = $kbs->dsn;

Returns the DSN to be used to connect to the SQLite database when building
it.

=cut

sub dsn {
    my $self = shift;
    return sprintf 'dbi:%s:dbname=%s', $self->dsn_dbd, $self->_path;
}

##############################################################################

=head3 test_dsn

  my $test_dsn = $kbs->test_dsn;

Returns the DSN to be used to connect to SQLite database to build for testing.

=cut

sub test_dsn {
    my $self = shift;
    return sprintf 'dbi:%s:dbname=%s', $self->dsn_dbd, $self->_test_path;
}

##############################################################################

=head3 config

  my @config = $kbs->config;

Returns a list of lines to include in the configuration file's "sqlite" block.
Called during the build to set up the SQLite store configuration directives to
be used by the Kinetic store at run time.

=cut

sub config { "    file => '" . shift->_path . "',\n" }

##############################################################################

=head3 test_config

  my @test_config = $kbs->test_config;

Returns a list of lines to include in the test configuration file's "sqlite"
block. Called during the build to set up the SQLite store configuration
directives to be used during testing.

=cut

sub test_config { "    file => '" . shift->_test_path . "',\n" }

##############################################################################

=head3 build

  $kbs->build;

Builds data store. This implementation overrides the parent version to set up
a database handle for use during the build.

=cut

sub build {
    my $self = shift;
    $self->_dbh(my $dbh = DBI->connect($self->dsn, '', ''));
    $self->SUPER::build(@_);
    $dbh->disconnect;
    return $self;
}

##############################################################################

=head3 test_build

  $kbs->test_build;

Builds a test data store. This implementation overrides the parent version to
set up a database handle for use during the build.

=cut

sub test_build {
    my $self = shift;
    $self->_dbh(my $dbh = DBI->connect($self->test_dsn, '', ''));
    $self->SUPER::test_build(@_);
    $dbh->disconnect;
    return $self;
}

##############################################################################

=begin private

=head1 Private Interface

=head2 Private Instance Methods

=head3 _path

  my $path = $kbs->_path;

Returns the full path to the file to be used for the SQLite database file. It
is based on the value of the C<install_base> Kinetic::Build property, with a
subdirectory named "store", and then the nave of the file as set C<db_file()>
method.

=cut

sub _path {
    my $self = shift;
    return catfile $self->builder->install_base, 'store', $self->db_file;
}

##############################################################################

=head3 _test_path

  my $test_path = $kbs->_test_path;

Returns the path to the file to be used for the SQLite database file used by
developer tests. It file is named by the C<db_file()> method and is in the
directory named by the the C<test_data_dir> Kinetic::Build property.

=cut

sub _test_path {
    my $self = shift;
    return catfile $self->builder->test_data_dir, $self->db_file;
}

##############################################################################

1;
__END__

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
