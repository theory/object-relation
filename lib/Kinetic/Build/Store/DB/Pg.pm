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
use App::Info::Handler::Carp;
use App::Info::Handler::Prompt;
use App::Info::Handler::Print;

=head1 Name

Kinetic::Build::Store::DB::Pg - Kinetic PostgreSQL data store builder

=head1 Synopsis

See L<Kinetic::Build::Store|Kinetic::Build::Store>.

=head1 Description

This module inherits from Kinetic::Build::Store::DB to build a PostgreSQL data
store. Its interface is defined entirely by Kinetic::Build::Store.

=cut

##############################################################################

=head3 _schema_class

  $class->_schema_class;

Returns a string representing the class that will define the schema in question;

=cut

sub _schema_class { 'Kinetic::Build::Schema::DB::Pg' }

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
    my $metadata = $self->metadata;
    my $dsn   = $metadata->_dsn;
    my $user  = $metadata->notes->{user};
    my $pass  = $metadata->notes->{pass};
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
