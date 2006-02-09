package Kinetic::Build::Setup::Store::DB;

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

use base 'Kinetic::Build::Setup::Store';
use DBI;
my %private;

=head1 Name

Kinetic::Build::Setup::Store::DB - Kinetic database store builder

=head1 Synopsis

See L<Kinetic::Build::Setup::Store|Kinetic::Build::Setup::Store>.

=head1 Description

This module inherits from Kinetic::Build::Setup::Store to function as the base class
for all store builder classes that builds a data store in a database. Its
interface is defined entirely by Kinetic::Build::Setup::Store.

=cut

##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 dbd_class

  my $dbd_class = Kinetic::Build::Setup::Store::DB->dbd_class;

This abstract class method returns the name of the DBI database driver class,
such as "DBD::Pg" or "DBD::SQLite". Must be overridden in subclasses.

=cut

sub dbd_class {
    require Carp
        && Carp::croak "dbd_class() must be overridden in the subclass";
}

##############################################################################

=head3 dsn_dbd

  my $dsn_dbd = Kinetic::Build::Setup::Store::DB->dsn_dbd;

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

=head2 Instance Methods

=head3 dsn

  my $dsn = $kbs->dsn;

This abstract method returns the DSN to be used by the Kinetic::Store::DB
subclass to connec to the database. Must be overridden in a subclass.

=cut

sub dsn { require Carp && Carp::croak "dsn() must be overridden in the subclass" }

##############################################################################

=head3 test_dsn

  my $test_dsn = $kbs->test_dsn;

This abstract method returns the DSN to be used by the Kinetic::Store::DB
subclass to connect to a test database while C<./Build test> is running. Must
be overridden in a subclass.

=cut

sub test_dsn { require Carp && Carp::croak "test_dsn() must be overridden in the subclass" }

##############################################################################

=head3 create_dsn

  my $create_dsn = $kbs->create_dsn;

Returns the DSN to be used to create the production database. By default, this
is the same as the value returned by C<dsn()>; override C<create_dsn()> to
change this behavior.

=cut

sub create_dsn { shift->dsn }

##############################################################################

=head3 build_db

Builds the database. Called as an action during C<./Build install>.

=cut

sub build_db {
    my $self = shift;

    my $schema_class = $self->schema_class;
    eval "use $schema_class";
    require Carp && Carp::croak $@ if $@;

    my $sg      = $schema_class->new;
    my $builder = $self->builder;
    my $regexen = $builder->schema_skipper;
    $regexen    = [$regexen] unless ref $regexen eq 'ARRAY';
    $sg->load_classes($builder->source_dir, @$regexen);

    my $dbh = $self->_dbh;
    $dbh->begin_work;

    eval {
        $dbh->do($_) foreach
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
    $self->_dbh->disconnect if $self->_dbh;
    $self->_dbh(undef); # clear wherever we were
    return $self;
}

##############################################################################

=begin private

=head1 Private Interface

=head2 Private Instance Methods

=head3 _dbh

  $kbs->_dbh;

Returns the database handle to connect to the data store.

=cut

sub _dbh {
    my $self = shift;
    return $private{$self}->{dbh} unless @_;
    return $private{$self}->{dbh} = shift;
}

1;
__END__

##############################################################################

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
