package Kinetic::Build::Setup::Store::DB::SQLite;

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
use DBI;
use Kinetic::Build;
use App::Info::RDBMS::SQLite;
use File::Spec::Functions;

=head1 Name

Kinetic::Build::Setup::Store::DB::SQLite - Kinetic SQLite data store builder

=head1 Synopsis

See L<Kinetic::Build::Setup::Store|Kinetic::Build::Setup::Store>.

=head1 Description

This module inherits from Kinetic::Build::Setup::Store::DB to build a SQLite data
store. Its interface is defined entirely by Kinetic::Build::Setup::Store. The
command-line options it adds are:

=over 4

=item path-to-sqlite

=item db_filename

=back

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 info_class

  my $info_class = Kinetic::Build::Setup::Store::DB::SQLite->info_class

Returns the name of the C<App::Info> class that detects the presences of
SQLite, L<App::Info::RDBMS::SQLite|App::Info::RDBMS::SQLite>.

=cut

sub info_class { 'App::Info::RDBMS::SQLite' }

##############################################################################

=head3 min_version

  my $version = Kinetic::Build::Setup::Store::DB::SQLite->min_version

Returns the minimum required version number of SQLite that must be installed.

=cut

sub min_version { '3.2.0' }

##############################################################################

=head3 dbd_class

  my $dbd_class = Kinetic::Build::Setup::Store::DB::SQLite->dbd_class;

Returns the name of the DBI database driver class, L<DBD::SQLite|DBD::SQLite>.

=cut

sub dbd_class { 'DBD::SQLite' }

##############################################################################

=head3 rules

  my @rules = Kinetic::Build::Setup::Store::DB::SQLite->rules;

Returns a list of arguments to be passed to an L<FSA::Rules|FSA::Rules>
constructor. These arguments are rules that will be used to validate the
installation of SQLite and to collect information to configure it for use by
TKP.

=cut

sub rules {
    my $self = shift;

    my $fail    = sub {! shift->result };
    my $succeed = sub {  shift->result };

    return (
        start => {
            do => sub {
                my $state = shift;
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
            do => sub {
                my $state = shift;
                return $state->result(1) if $self->is_required_version;
                $state->result(0);
                my $req = version->new($self->min_version);
                my $got = version->new($self->info->version);
                my $exe = $self->info->executable;
                $state->message(
                    "I require SQLite $req but found $exe, which is $got.\n"
                  . 'Use --path-to-sqlite to specify a different SQLite '
                  . 'executable'
                );
            },
            rules  => [
                fail => {
                    rule    => $fail,
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
                $self->{db_file} = $builder->get_reply(
                      name    => 'db-file',
                      message => 'Please enter a filename for the SQLite database',
                      label   => 'SQLite database file name',
                      default => $self->_path,
                      config_keys => [qw( store file )],
                );
            },
            rules => [
                file_name => {
                    rule    => sub { ! $self->db_file },
                    message => 'No filename for database',
                },
                fail => {
                    rule => sub {
                        my $state = shift;
                        return unless $self->builder->isa('Kinetic::AppBuild');
                        my $file = $self->db_file;
                        return if -e $file;
                        $state->message(
                            qq{Database file "$file" does not exist}
                        );
                        return 1;
                    }
                },
                Done => {
                    rule    => 1,
                    message => 'We have a filename',
                }
            ],
        },
        Done => {
            do => sub {
                $self->add_actions('build_db');
                shift->done(1);
            }
        },
        fail => {
            do => sub { $self->builder->fatal_error(shift->prev_state->message) },
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
    return sprintf 'dbi:%s:dbname=%s', $self->dsn_dbd, $self->db_file;
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

=head3 add_to_config

  $kbs->add_to_config(\%conf);

This method adds the SQLite configuration data to the hash reference passed as
its sole argument. This configuration data will be written to the
F<kinetic.conf> file. Called during the build to set up the SQLite store
configuration directives to be used by the Kinetic store at run time.

=cut

sub add_to_config {
    my ($self, $config) = @_;
    return unless $self->builder->store eq 'sqlite';
    $config->{store} = {
        class => $self->store_class,
        dsn     => $self->dsn,
        db_user => '',
        db_pass => '',
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
        dsn     => $self->test_dsn,
        db_user => '',
        db_pass => '',
    };

    return $self;
}

##############################################################################

=head3 setup

  $kbs->setup;

Build data store. This implementation overrides the parent version to set up
a database handle for use during the setup.

=cut

sub setup {
    my $self = shift;
    return $self->_setup($self->dsn, $self->_dir, 'setup', @_);
}

##############################################################################

=head3 test_setup

  $kbs->test_setup;

Builds a test data store. This implementation overrides the parent version to
set up a database handle for use during the setup.

=cut

sub test_setup {
    my $self = shift;
    my @actions = $self->actions;
    $self->del_actions(@actions);
    my @tmp_act = map { s/^build_db$/build_test_db/; $_ } @actions;
    $self->add_actions(@tmp_act);
    $self->_setup( $self->test_dsn, $self->_test_dir, 'test_setup', @_ );
    $self->del_actions(@tmp_act);
    $self->add_actions(@actions);
}

##############################################################################

=head3 test_cleanup

  $kbs->test_cleanup;

Cleans up the tests data store by disconnecting all database connections and
deleting the test data directory, as returned by C<< $build->test_data_dir >>,
which is where the test database gets built.

=cut

sub test_cleanup {
    my $self    = shift;
    my $builder = $self->builder;
    $self->disconnect_all;
    File::Path::rmtree $self->_test_dir, !$builder->quiet;
}

##############################################################################

=begin private

=head1 Private Interface

=head2 Private Instance Methods

=head3 _setup

  $kdb->_setup($dsn, $dir, $method, @args);

Called by C<setup> and C<test_setup>. See those methods to understand its
behavior.

=cut

sub _setup {
    my ($self, $dsn, $dir, $method, @args) = @_;
    my $builder = $self->builder;
    File::Path::mkpath $dir, !$builder->quiet;

    $self->_dbh(my $dbh = DBI->connect($dsn, '', '', {
        RaiseError  => 0,
        PrintError  => 0,
        unicode     => 0,
        HandleError => Kinetic::Util::Exception::DBI->handler,
    }));

    $method = "SUPER::$method";
    $self->$method(@args);

    return $self->disconnect_all;
}

##############################################################################

=head3 _path

  my $path = $kbs->_path;

Returns the full path to the file to be used for the SQLite database file. It
is based on the value of the C<install_base> Kinetic::Build property, with a
subdirectory named "store", and then the nave of the file as set C<db_file()>
method.

=cut

sub _path {
    my $self = shift;
    return catfile $self->_dir, 'kinetic.db';
}

##############################################################################

=head3 _dir

  my $dir = $kbs->_dir;

Returns the full path to the directory used by C<_path()>.

=cut

sub _dir {
    return catdir shift->builder->install_base, 'store';
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
    return catfile $self->_test_dir, 'kinetic.db';
}

##############################################################################

=head3 _test_dir

  my $test_dir = $kbs->_test_dir;

Returns the full path to the directory used by C<_test_path()>.

=cut

sub _test_dir {
    my $build = shift->builder;
    return catdir $build->base_dir, $build->test_data_dir;
}

##############################################################################

1;
__END__

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
