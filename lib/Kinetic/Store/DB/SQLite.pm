package Kinetic::Store::DB::SQLite;

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
use base qw(Kinetic::Store::DB);
use Encode qw(_utf8_on);

use Kinetic::Store qw(:logical);
use Kinetic::Util::Config qw(:sqlite);
use Exception::Class::DBI;

use constant _connect_args => (
    'dbi:SQLite:dbname=' . SQLITE_FILE, '', '', {
        RaiseError  => 0,
        PrintError  => 0,
        HandleError => Exception::Class::DBI->handler
    }
);

=head1 Name

Kinetic::Store::DB::SQLite - SQLite specific behavior for Kinetic::Store::DB

=head1 Synopsis

See L<Kinetic::Store|Kinetic::Store>.

=head1 Description

This class implements SQLite-specific behavior for the Kinetic storage API by
overriding C<Kinetic::Store::DB> methods as needed.

=cut

##############################################################################

sub _cast_as_int {
    my ($self, @tokens) = @_;
    # that "abs()" forces SQLite to cast the result as a number, thus allowing
    # a proper numeric comparison.  Otherwise, the substr forces SQLite to 
    # treat it as a string, causing the SQL to not match our expectations.
    return 'abs('. join(' || ' => @tokens) .')';
}

=head3 _fetchrow_hashref

  $store->_fetchrow_hashref($sth);

This method delegates the fetchrow hashref call to the statement handle, but
ensures that data returned is uft8.

=cut

sub _fetchrow_hashref {
    my ($self, $sth) = @_;
    my $hash = $sth->fetchrow_hashref;
    return unless $hash;
    _utf8_on($_) foreach values %$hash;
    return $hash; 
}

##############################################################################

=head3 _set_id

  $store->_set_id($kinetic_object);

SQLite-specific implementation of C<Kinetic::Store::DB::_set_id>.

=cut

sub _set_id {
    my ($class, $object) = @_;
    my $view = $object->my_class->key;
    # XXX last_insert_id() doesn't seem to work properly.
    my $result = $class->_dbh->selectcol_arrayref(
        "SELECT id FROM $view WHERE guid = ?", undef, $object->guid
    );
    $object->{id} = $result->[0];
    return $class;
}

##############################################################################

=head3 _full_text_search

  # not implemented in SQLite

Not implemented in SQLite

=cut

sub _full_text_search {
    my $self = shift;
    require Carp;
    Carp::croak("SQLite does not support full-text searches");
}

##############################################################################

=head3 _comparison_handler

  my $op = $store->_comparison_handler($key);

Works like C<Kinetic::Store::DB::_comparison_handler> but it croaks if a
C<MATCH> handler is requested.  This is because regular expressions are not
supported on SQLite.

=cut

sub _MATCH_SEARCH {
    my ($class, $search) = @_;
    require Carp;
    Carp::croak("MATCH:  SQLite does not support regular expressions");
}

##############################################################################

=head3 _case_insensitive_types

  my @fields = $store->_case_insensitive_types;

For SQLite, case-insensitivity only works for ASCII, not UNICODE.  Thus, we
will make no fields case-insensitive.

=cut

sub _case_insensitive_types {}

1;
__END__

=head1 Copyright and License

Copyright (c) 2004-2005 Kineticode, Inc. <info@kineticode.com>

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
