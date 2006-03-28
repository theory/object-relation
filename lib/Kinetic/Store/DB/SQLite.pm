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
use version;
our $VERSION = version->new('0.0.1');
use Encode qw(_utf8_on);

use Kinetic::Store qw(:logical);
use Kinetic::Util::Config qw(:store);
use Kinetic::Util::Exceptions qw(throw_unsupported);
use Kinetic::Util::Functions ();
use Exception::Class::DBI;
use OSSP::uuid;

use constant DBI_CLASS => 'Kinetic::Store::DB::SQLite::DBI';
use constant _connect_args => (
    STORE_DSN,
    '', '',
    {
        RaiseError  => 0,
        PrintError  => 0,
        HandleError => Kinetic::Util::Exception::DBI->handler,
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

=head3 _fetchrow_hashref

  $store->_fetchrow_hashref($sth);

This method delegates the fetchrow hashref call to the statement handle, but
ensures that data returned is utf8.

=cut

sub _fetchrow_hashref {
    my ( $self, $sth ) = @_;
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
    my ( $class, $object ) = @_;
    my $view = $object->my_class->key;

    # XXX last_insert_id() doesn't seem to work properly. Watch
    # http://sqlite.org/cvstrac/tktview?tn=1191 for the fix.
    my $result =
      $class->_dbh->selectcol_arrayref( "SELECT id FROM $view WHERE uuid = ?",
        undef, $object->uuid );
    $object->id( $result->[0] );
    return $class;
}

##############################################################################

=head3 _full_text_search

  # not implemented in SQLite

Not implemented in SQLite

=cut

sub _full_text_search {
    throw_unsupported [ "[_1] does not support full-text searches",
        __PACKAGE__ ];
}

##############################################################################

=head3 _MATCH_SEARCH

  my $op = $store->_MATCH_SEARCH($key);

Works like C<Kinetic::Store::DB::_MATCH_SEARCH> but supports full Perl regular
expressions via the SQLite C<REGEXP> operator. As the regular expressions are
compiled with the C<ixms> modifiers, they are always case-insensitive,
and C<^> matches the beginning of the whole string, and C<$> matches the end
of the whole string.

=cut

sub _MATCH_SEARCH {
    my ( $self, $search ) = @_;
    my $col = $search->column;
    my $not = $search->negated ? ' NOT' : '';
    return ( "$col$not REGEXP ?", [ $search->data ] );
}

##############################################################################

=head3 _is_case_sensitive

  if ($store->_is_case_sensitive($type)) {
    ...
  }

For SQLite, case-insensitivity only works for ASCII, not UNICODE.  Thus, we
will make no column types case-insensitive.

=cut

sub _is_case_sensitive { }

##############################################################################

my @DATE = (
    [ year  => '%Y' ], # XXX Years before 1000 and after 9999 are not supported.
    [ month => '%m' ],
    [ day   => '%d' ],
    [ hour  => '%H' ],
    [ minute => '%M' ],
    [ second => '%S' ],
);

sub _field_format {
    my ( $self, $field, $date ) = @_;
    my @tokens;
    foreach my $date_data (@DATE) {
        my ( $segment, $fmt ) = @$date_data;
        my $value = $date->$segment;
        next unless defined $value;
        push @tokens => "strftime('$fmt', $field)";
    }
    return join ( ' || ' => @tokens );
}

##############################################################################

sub _eq_date_handler {
    my ( $self, $search ) = @_;
    my $date     = $search->data;
    my $token    = $self->_field_format( $search->column, $date );
    my $operator = $search->operator;
    return ( "$token $operator ?", [ $date->sort_string ] );
}

sub _gt_lt_date_handler {
    my ( $self, $search ) = @_;
    my ( $date, $operator ) = ( $search->data, $search->operator );
    throw_unsupported
      "You cannot do GT or LT type searches with non-contiguous dates"
      unless $date->contiguous;
    my $token = $self->_field_format( $search->column, $date );
    my $value = $date->sort_string;
    return ( "$token $operator ?", [$value] );
}

sub _between_date_sql {
    my ( $self,    $search )   = @_;
    my ( $date1,   $date2 )    = @{ $search->data };
    my ( $negated, $operator ) = ( $search->negated, $search->operator );
    my $token = $self->_field_format( $search->column, $date1 );
    return (
        "$token $negated $operator ? AND ?",
        [ $date1->sort_string, $date2->sort_string ]
    );
}

sub _any_date_handler {
    my ( $self, $search ) = @_;
    my ( $negated, $value ) = ( $search->negated, $search->data );
    my ( @tokens, @values );
    my $field = $search->column;
    foreach my $date (@$value) {
        my $token = $self->_field_format( $field, $date );
        push @tokens => "$token = ?";
        push @values => $date->sort_string;
    }
    my $token = join ' OR ' => @tokens;
    return ( $token, \@values );
}

##############################################################################
# Subclass DBI in order to add custom functions to SQLite at the beginning of
# every connection.

package Kinetic::Store::DB::SQLite::DBI;
use base 'DBI';

package Kinetic::Store::DB::SQLite::DBI::st;
use base 'DBI::st';

package Kinetic::Store::DB::SQLite::DBI::db;
use base 'DBI::db';

sub connected {
    my $dbh = shift;
    return if exists $dbh->{private_KineticSQLite_functions};

    # Add UUID_V4() function.
    $dbh->func(
        'UUID_V4',
        0,
        \&Kinetic::Util::Functions::create_uuid,
        'create_function'
    );

    # Add regexp() function for use by REGEXP operator. See
    # http://www.justatheory.com/computers/databases/sqlite/add_regexen.html
    $dbh->func('regexp', 2, sub {
        my ($regex, $string) = @_;
        return $string =~ /$regex/ixms;
    }, 'create_function');

    $dbh->{private_KineticSQLite_functions} = 1;
}

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
