package Kinetic::Store::Setup::DB::Pg;

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
our $VERSION = version->new('0.0.2');

use base 'Kinetic::Store::Setup::DB';
use Class::BuildMethods qw(
    super_user
    super_pass
    template_dsn
    createlang
);

use Kinetic::Util::Exceptions qw(
    throw_unsupported
    throw_not_found
    throw_io
);

=head1 Name

Kinetic::Store::Setup::DB::Pg - Kinetic Pg data store setup

=head1 Synopsis

See L<Kinetic::Store::Setup|Kinetic::Store::Setup>.

=head1 Description

This module inherits from Kinetic::Store::Setup::DB to build a Pg set up
store.

=head1 Class Interface

=head2 Constructors

=head3 new

  my $pg_setup = Kinetic::Store::Setup::DB::Pg->new(\%params);

The constructor inherits from
L<Kinetic::Store::Setup::DB|Kinetic::Store::Setup:::DB> to set default values
for the following attributes:

=over

=item super_user

Defaults to "postgres".

=item super_pass

Defaults to "".

=item user

Defaults to "kinetic".

=item dsn

Defaults to "dbi:Pg:dbname=kinetic".

=item template_dsn

Defaults to the value of C<dsn> with the value for the C<dbname> changed to
"template1".

=back

=cut

sub new {
    my $self = shift->SUPER::new(@_);
    for my $spec (
        [ super_user       => 'postgres'              ],
        [ super_pass       => ''                      ],
        [ dsn              => 'dbi:Pg:dbname=kinetic' ],
    ) {
        my ($attr, $value) = @{ $spec };
        $self->$attr($value) unless defined $self->$attr;
    }

    # Disallow the null string.
    $self->user('kinetic') unless $self->user;

    unless ($self->template_dsn) {
        (my $dsn = $self->dsn) =~ s/dbname=[^:]+/dbname=template1/;
        $self->template_dsn($dsn);
    }

    return $self;
}

##############################################################################

=head2 Class Methods

=head3 connect_attrs

  DBI->connect(
      $dsn, $user, $pass,
      { Kinetic::Store::Setup::DB::Pg->connect_attrs }
  );

Returns a list of arugments to be used in the attributes hash passed to the
DBI C<connect()> method. Overrides that provided by
L<Kinetic::Store::Setup::DB|Kinetic::Store::Setup::DB> to add
C<< pg_enable_utf8 => 1 >>.

=cut

sub connect_attrs {
    return (
        shift->SUPER::connect_attrs,
        pg_enable_utf8 => 1,
    );
}

##############################################################################

=head1 Instance Interface

=head2 Instance Accessors

In addition to the attribute accessors provided by Kinetic::Store::Setup::DB,
this class provides the following.

=head3 super_user

  my $super_user = $setup->super_user;
  $setup->super_user($super_user);

Gets and sets the C<super_user> attribute.

=head3 super_pass

  my $super_pass = $setup->super_pass;
  $setup->super_pass($super_pass);

Gets and sets the C<super_pass> attribute.

=head3 template_dsn

  my $template_dsn = $setup->template_dsn;
  $setup->template_dsn($template_dsn);

Gets and sets the C<template_dsn> attribute.

=head2 Instance Methods

=head3 setup

  $setup->setup;

Sets up the data store. This implementation simply constructs a database
handle and assigns it to the C<dbh> attribute, and then calls
C<SUPER::setup()> to let Kinetic::Store::Setup::DB handle the bulk of the
work.

=cut

sub setup {
    my $self = shift;
    # Try to connect as super user.

#    $self->check_version;

#    $self->build_db;
    $self->disconnect_all;
}

##############################################################################

=head3 check_version

  $setup->check_version;

Validates that we're using and connecting to PostgreSQL 8.0 or higher.

=cut

sub check_version {
    my $self = shift;
    my $dbh  = $self->dbh;
    my $req  = 80000;

    throw_unsupported [
        '[_1] is compiled with [_2] [_3] but we require version [_4]',
        'DBD::Pg',
        'PostgreSQL',
        $dbh->{pg_lib_version},
        $req,
    ] if $dbh->{pg_lib_version} < $req;

    throw_unsupported [
        'The [_1] server is version [_2] but we require version [_3]',
        'PostgreSQL',
        $dbh->{pg_server_version},
        $req,
    ] if $dbh->{pg_server_version} < $req;

    return $self;
}

##############################################################################

=head3 create_db

  $setup->create_db($db_name);

Attempts to create a database with the supplied name. It uses Unicode
encoding. It will disconnect from the database when done. If the database name
is not supplied, it will use that stored in the C<db_name> attribute.

=cut

sub create_db {
    my ($self, $db_name) = @_;
    my $dbh = $self->connect(
        $self->template_dsn,
        $self->super_user,
        $self->super_pass,
    );

    $dbh->do(qq{CREATE DATABASE "$db_name" WITH ENCODING = 'UNICODE'});
    return $self;
}

##############################################################################

=head3 add_plpgsql

  $setup->add_plpgsql($db_name);

Given a database name, this method will attempt to add C<plpgsql> to the
database using F<createlang>. If the C<createlang> attribute is not specified,
it will attempt to find it using C<find_createlang()>, and if that fails it
will throw an exception. The appropriate host and port, if any, will be pulled
out of the C<dsn>, and the C<super_user>, if set to a true value, will also be
used (recommended).

=cut

sub add_plpgsql {
    my ($self, $db_name) = @_;
    my $createlang = $self->createlang || $self->find_createlang
        or throw_not_found [
            'Cannot find the PostgreSQL createlang executable',
        ];

    # createlang -U postgres plpgsql template1
    my @options;
    for my $token ( split /:/, $self->dsn ) {
        my ($k, $v) = split /=/, $token;
        $v =~ s/;$//;
        push @options, '-h', $v if $k eq 'host';
        push @options, '-p', $v if $k eq 'port';
    }

    if (my $super = $self->super_user) {
        push @options, '-U', $super;
    }

    my @add_plpgsql = ($createlang, @options, 'plpgsql', $db_name);
    system @add_plpgsql
        and throw_io [
            '[_1] failed: [_2]',
            "system(@add_plpgsql)",
            $?,
        ];

    return $self;
}

##############################################################################

=head3 create_user

  $setup->create_user($user, $pass);

Attempts to create a user with the supplied name. It defaults to the user name
returned by C<db_user()> and the password returned by C<db_pass()>.

=cut

sub create_user {
    my ($self, $user, $pass) = @_;
    $user ||= $self->user;
    $pass ||= $self->pass;

    my $dbh = $self->connect(
        $self->template_dsn,
        $self->db_super_user,
        $self->db_super_pass,
    );

    $dbh->do(
        qq{CREATE USER "$user" WITH password '$pass' NOCREATEDB NOCREATEUSER}
    );
    return $self;
}

##############################################################################

=head3 build_db

  $setup->build_db;

Builds the database with all of the tables, sequences, indexes, views,
triggers, etc., required to power the application. Overrides the
implementation in the parent class to set up the database handle and to
silence "NOTICE" output from PostgreSQL.

=cut

sub build_db {
    my $self = shift;

    $self->_connect_user($self->dsn);

    # Ignore PostgreSQL warnings.
    local $SIG{__WARN__} = sub {
        my $message = shift;
        return if $message =~ /NOTICE:/;
        warn $message;
    };

    $self->SUPER::build_db(@_);
}

##############################################################################

=head3 grant_permissions

  $setup->grant_permissions;

Grants the database user permission to access the objects in the database.
Called if the super user creates the database.

=cut

sub grant_permissions {
    my $self = shift;
    my $dbh = $self->connect(
        $self->dsn,
        $self->super_user,
        $self->super_pass,
    );

# relkind:
#   r => 'table (relation)',
#   v => 'view',
#   i => 'index',
#   c => 'composite type',
#   S => 'sequence',
#   s => 'special',
#   t => 'TOAST table',

    my $objects = $dbh->selectcol_arrayref(qq{
        SELECT n.nspname || '."' || c.relname || '"'
        FROM   pg_catalog.pg_class c
               LEFT JOIN pg_catalog.pg_user u ON u.usesysid = c.relowner
               LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE  c.relkind IN ('S', 'v')
               AND n.nspname NOT IN ('pg_catalog', 'pg_toast')
               AND pg_catalog.pg_table_is_visible(c.oid)
    });

    return $self unless @$objects;

    $dbh->do(
        'GRANT SELECT, UPDATE, INSERT, DELETE ON '
        . join(', ', @$objects) . ' TO "'
        . ($self->_build_db_user || $self->db_user) . '"'
    );

    return $self;
}

##############################################################################

=head3 find_createlang

  my $createlang = $setup->find_createlang;

Searches for the F<createlang> executable on the file system. Used internally
by C<add_plpgsql()> when the C<createlang> attribute is not set. It searches
in the following directories:

=over 4

=item $ENV{POSTGRES_HOME}/bin (if $ENV{POSTGRES_HOME} exists)

=item $ENV{POSTGRES_LIB}/../bin (if $ENV{POSTGRES_LIB} exists)

=item The system path (File::Spec->path)

=item /usr/local/pgsql/bin

=item /usr/local/postgres/bin

=item /opt/pgsql/bin

=item /usr/local/bin

=item /usr/local/sbin

=item /usr/bin

=item /usr/sbin

=item /bin

=item C:\Program Files\PostgreSQL\bin

=back

=cut

sub find_createlang {
    my $exe = 'createlang';
    $exe .= '.exe' if $^O eq 'MSWin32';
    my $fs = 'File::Spec';
    for my $dir (
        ( exists $ENV{POSTGRES_HOME}
            ? ($fs->catdir($ENV{POSTGRES_HOME}, 'bin'))
            : ()
        ),
        ( exists $ENV{POSTGRES_LIB}
            ? ($fs->catdir($ENV{POSTGRES_LIB}, $fs->updir, 'bin'))
            : ()
        ),
        $fs->path,
        qw(/usr/local/pgsql/bin
           /usr/local/postgres/bin
           /usr/lib/postgresql/bin
           /opt/pgsql/bin
           /usr/local/bin
           /usr/local/sbin
           /usr/bin
           /usr/sbin
           /bin
        ),
        'C:\Program Files\PostgreSQL\bin',
    ) {
        my $file = $fs->catfile($dir, $exe);
        return $file if -f $file && -x $file;
    }
}

##############################################################################

=head3 _connect_user

  my $dbh = $setup->_connect_user($dsn);

This method attempts to connect to PostgreSQL via a given DSN. It connects as
the super user if the super user has been set; otherwise, it connects as the
database user. It returns a database handle on success and C<undef> on
failure. As a side effect, the C<_dbh()> method will also set to the returned
value.


=cut

sub _connect_user {
    my ($self, $dsn) = @_;
    my @credentials;
    if (my $super = $self->super_user) {
        @credentials = ($super, $self->super_pass);
    } else {
        @credentials = ($self->user, $self->pass);
    }

    $self->connect($dsn, @credentials);
}
##############################################################################


1;
__END__


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

