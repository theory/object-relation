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

=head3 date_handler

  $store->date_handler($date);

Used to return the correct representation of a date object for purposes of a 
store's search mechanism.

=cut

my %date = (
    year   => [0, 4],
    month  => [5, 2],
    day    => [8, 2],
    hour   => [11,2],
    minute => [14,2],
    second => [17,2],
); 

sub date_handler {
    my ($self, $date, $field, $comparator) = @_;
    return $self->_like_string($date) unless defined $field; 
    my (@tokens,@values);
    while (my ($segment, $idx) = each %date) {
        my $value = $date->$segment;
        next unless defined $value;
        push @tokens => "substr($field, $idx->[0], $idx->[1]) $comparator ?";
        push @values => $value;
    }
    my $token = join ' AND ' => @tokens;
    return $token, \@values;
}

sub _like_string {
    my ($self, $date) = @_;
    # 2005-03-14T23:01:26
    # YYYY-MM-DD{T}hh:mm:ss
    my $year = defined $date->year? sprintf("%04d",$date->year) : '____';
    my @date;
    foreach my $segment (qw/month day hour minute second/) {
        push @date => defined $date->$segment? sprintf("%02d",$date->$segment) : '__'
    }
    return sprintf "$year-%02s-%02sT%02s:%02s:%02s" => @date;
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

sub _comparison_handler {
    my ($class, $key) = @_;
    if ($key =~ /MATCH/) {
        require Carp;
        Carp::croak("$key:  SQLite does not support regular expressions");
    }
    return $class->SUPER::_comparison_handler($key);
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
