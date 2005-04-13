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

use Kinetic::Store            qw(:logical);
use Kinetic::Util::Config     qw(:sqlite);
use Kinetic::Util::Exceptions qw(:all);
use Exception::Class::DBI;

use constant _connect_args => (
    'dbi:SQLite:dbname=' . SQLITE_FILE, '', '', {
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
    # XXX last_insert_id() doesn't seem to work properly. Watch
    # http://sqlite.org/cvstrac/tktview?tn=1191 for the fix.
    my $result = $class->_dbh->selectcol_arrayref(
        "SELECT id FROM $view WHERE guid = ?", undef, $object->guid
    );
    $object->id($result->[0]);
    return $class;
}

##############################################################################

=head3 _full_text_search

  # not implemented in SQLite

Not implemented in SQLite

=cut

sub _full_text_search {
    throw_unsupported [ "[_1] does not support full-text searches", __PACKAGE__ ];
}

##############################################################################

=head3 _comparison_handler

  my $op = $store->_comparison_handler($key);

Works like C<Kinetic::Store::DB::_comparison_handler> but it throws an
exception if a C<MATCH> handler is requested.  This is because regular
expressions are not supported on SQLite.

=cut

sub _MATCH_SEARCH {
    throw_unsupported [
        "MATCH:  [_1] does not support regular expressions",
        __PACKAGE__
    ];
}

##############################################################################

=head3 _is_case_sensitive

  if ($store->_is_case_sensitive($type)) {
    ...
  }

For SQLite, case-insensitivity only works for ASCII, not UNICODE.  Thus, we
will make no column types case-insensitive.

=cut

sub _is_case_sensitive {}

##############################################################################

# XXX We should probably switch from substr() to strftime() and require
# SQLite 3.2.0 or later. That will allow more flexible years (before 1000 and
# after 9999, not to mention dates BCE. But see
# http://sqlite.org/cvstrac/tktview?tn=1190 for the Year 10000 problem.
my @DATE = (
    [year   => [1, 4]], # XXX Years before 1000 and after 9999 are not supported.
    [month  => [6, 2]],
    [day    => [9, 2]],
    [hour   => [12,2]],
    [minute => [15,2]],
    [second => [18,2]],
);

sub _field_format {
    my ($self, $field, $date) = @_;
    my @tokens;
    foreach my $date_data (@DATE) {
        my ($segment, $idx) = @$date_data;
        my $value = $date->$segment;
        next unless defined $value;
        push @tokens => "substr($field, $idx->[0], $idx->[1])";
    }
    return $self->_cast_as_int(@tokens);
}

##############################################################################

sub _eq_date_handler {
    my ($self, $search) = @_;
    my $date     = $search->data;
    my $token    = $self->_field_format($search->column, $date);
    my $operator = $search->operator;
    return ("$token $operator ?", [$date->sort_string]);
}

sub _gt_lt_date_handler {
    my ($self, $search) = @_;
    my ($date, $operator) = ($search->data, $search->operator);
    throw_unsupported "You cannot do GT or LT type searches with non-contiguous dates"
        unless $date->contiguous;
    my $token = $self->_field_format($search->column, $date);
    my $value = $date->sort_string;
    return ("$token $operator ?", [$value]);
}

sub _between_date_handler {
    my ($self, $search) = @_;
    my $data = $search->data;
    my ($date1, $date2) = @$data;
    throw_unsupported "You cannot do range searches with non-contiguous dates"
        unless $date1->contiguous && $date2->contiguous;
    throw_unsupported "BETWEEN search dates must have identical segments defined"
        unless $date1->same_segments($date2);
    my ($negated, $operator) = ($search->negated, $search->operator);
    my $token = $self->_field_format($search->column, $date1);
    return ("$token $negated $operator ? AND ?", [$date1->sort_string, $date2->sort_string])
}

sub _any_date_handler {
    my ($self, $search)   = @_;
    my ($negated, $value) = ($search->negated, $search->data);
    my (@tokens, @values);
    my $field = $search->column;
    foreach my $date (@$value) {
        my $token = $self->_field_format($field, $date);
        push @tokens => "$token = ?";
        push @values => $date->sort_string;
    }
    my $token = join ' OR ' => @tokens;
    return ($token, \@values);
}

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
