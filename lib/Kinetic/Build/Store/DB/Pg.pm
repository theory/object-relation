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


1;
__END__

##############################################################################

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
