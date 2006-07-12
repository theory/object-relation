package Kinetic::Store::Setup::DB;

# $Id: DB.pm 3014 2006-07-12 18:47:41Z theory $

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
our $VERSION = version->new('0.0.2');

use base 'Kinetic::Store::Setup';
use Class::BuildMethods qw(
    dsn
    user
    pass
    dbh
);

use DBI;

=head1 Name

Kinetic::Store::Setup::DB - Set up database stores

=head1 Synopsis

See L<Kinetic::Store::Setup|Kinetic::Store::Setup>.

=head1 Description

This module inherits from Kinetic::Store::Setup to function as the base class
for all store setup classes that build a data stores in databases. Its
interface is defined entirely by Kinetic::Store::Setup.

=cut

##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $db_setup = Kinetic::Store::Setup::DB->new(\%params);

The constructor inherits from L<Kinetic::Store::Setup|Kinetic::Store::Setup>,
but adds support for these parameters:

=over

=item dsn

The DSN to use to connect to the database via the DBI.

=item user

The username to use when connecting to the database. Defaults to ''.

=item pass

The password to use when connecting to the database. Defaults to ''.

=back

=cut

sub new {
    my $self = shift->SUPER::new(@_);
    $self->user('') unless defined $self->user;
    $self->pass('') unless defined $self->pass;
    return $self;
}

##############################################################################

=head2 Class Methods

=head3 dbd_class

  my $dbd_class = Kinetic::Store::Setup::DB->dbd_class;

This abstract class method returns the name of the DBI database driver class,
such as "DBD::Pg" or "DBD::SQLite". Defaults to using the last part of the
schema class name (e.g., "Pg" for Kinetic::Store::Setup::DB::Pg) prepended
with "DBD::".

=cut

sub dbd_class {
    (my $dbd = ref $_[0] || $_[0]) =~ s/.*:://;
    return "DBD::$dbd";
}

##############################################################################

=head3 dsn_dbd

  my $dsn_dbd = Kinetic::Store::Setup::DB->dsn_dbd;

Returns the part of the database driver class name suitable for use in a
DBI DSN. By default, this method simply returns the value returned by
C<dbd_class()>, but with the leading "DBD::" stripped off.

=cut

sub dsn_dbd {
    (my $dbd = shift->dbd_class) =~ s/^DBD:://;
    return $dbd;
}

##############################################################################

=head1 Instance Interface

=head2 Instance Accessors

=head3 dsn

  my $dsn = $kbs->dsn;
  $kbs->dsn($dsn);

Gets or sets the DSN to use when connecting to the database via the DBI.

=head3 user

  my $user = $kbs->user;
  $kbs->user($user);

Gets or sets the username used to connect to the database via the DBI.

=head3 pass

  my $pass = $kbs->pass;
  $kbs->pass($pass);

Gets or sets the passname used to connect to the database via the DBI.

=cut

##############################################################################

=head2 Instance Methods

=head3 setup

  $setup->setup;

Sets up the data store by calling C<build_db()>.

=cut

sub setup {
    my $self = shift;
    $self->build_db;
    $self->disconnect_all;
}

##############################################################################

=head3 build_db

Builds the database. Called as an action during C<./Build install>.

=cut

sub build_db {
    my $self = shift;
    my $sg   = $self->load_schema;
    my $dbh  = $self->dbh;

    $dbh->begin_work;
    eval {
        $dbh->do($_) for
            $sg->begin_schema,
            $sg->setup_code,
            (map { $sg->schema_for_class($_) } $sg->classes),
            $sg->end_schema;
        $dbh->commit;
    };

    if (my $err = $@) {
        $dbh->rollback;
        require Carp && Carp::croak $err;
    }

    return $self;
}

##############################################################################

=head3 switch_to_db

This action switches the database connection for building a database to a
different database. Used when switching between a template database for
creating a new database, and the database to be built.

=cut

sub switch_to_db {
    my ($self, $db_name) = @_;
    $self->builder->db_name($db_name);
    $self->builder->notes(db_name => $db_name);
    $self->dbh->disconnect if $self->dbh;
    $self->dbh(undef); # clear wherever we were
    return $self;
}

##############################################################################

=head3 disconnect_all

  $kbs->disconnect_all;

Disconnects all cached connections to the database server (that is, created by
calls to C<< DBI->connect_cached >> for the driver returned by C<dbd_class()>.
Used by C<test_cleanup()> methods and in other contexts.

=cut

sub disconnect_all {
    my $self = shift;
    my %drhs = DBI->installed_drivers;
    $_->disconnect for grep { defined }
        values %{ $drhs{$self->dsn_dbd}->{CachedKids} };
    return $self;
}

1;
__END__

##############################################################################

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
