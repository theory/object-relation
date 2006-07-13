package Kinetic::Store::Setup::DB::SQLite;

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
use Kinetic::Util::Exceptions qw(
    throw_unsupported
);

=head1 Name

Kinetic::Store::Setup::DB::SQLite - Kinetic SQLite data store setup

=head1 Synopsis

See L<Kinetic::Store::Setup|Kinetic::Store::Setup>.

=head1 Description

This module inherits from Kinetic::Store::Setup::DB to build a SQLite set up
store.

=head1 Class Interface

=head2 Constructors

=head3 new

  my $sqlite_setup = Kinetic::Store::Setup::DB::SQLite->new(\%params);

The constructor inherits from
L<Kinetic::Store::Setup::DB|Kinetic::Store::Setup:::DB>, but detects when the
C<dsn> attribute isn't set, and sets it to a default value. The database file
in that value will be F<kinetic.db> and will live in the directory returned by
C<File::Temp::tempdir()>.

=cut

sub new {
    my $self = shift->SUPER::new(@_);
    unless ($self->dsn) {
        require File::Spec;
        $self->dsn(
            'dbi:SQLite:dbname='
            . File::Spec->catfile(File::Spec->tmpdir, 'kinetic.db')
        );
    }
    return $self;
}

##############################################################################

=head2 Class Methods

=head3 connect_attrs

  DBI->connect(
      $dsn, $user, $pass,
      { Kinetic::Store::Setup::DB::SQLite->connect_attrs }
  );

Returns a list of arugments to be used in the attributes hash passed to the
DBI C<connect()> method. Overrides that provided by
L<Kinetic::Store::Setup::DB|Kinetic::Store::Setup::DB> to add
C<< unicode => 1 >>.

=cut

sub connect_attrs {
    return (
        shift->SUPER::connect_attrs,
        unicode => 1,
    );
}

##############################################################################

=head1 Instance Interface

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
    my $dbh  = $self->connect;

    # Check the version of SQLite.
    my $req = version->new('3.2.0');
    my $got = version->new($dbh->{sqlite_version});
    throw_unsupported [
        '[_1] is compiled with [_2] [_3] but we require version [_4]',
        'DBD::SQLite',
        'SQLite',
        $got,
        $req,
    ] if $got < $req;

    # Set the database handle and send it on up.
    $self->dbh($dbh);
    $self->SUPER::setup;
    $self->dbh(undef);
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

