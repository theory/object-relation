package Kinetic::Store::DB::Pg;

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
use Kinetic::Util::Config qw(:pg);
use Exception::Class::DBI;
use overload;
use constant _connect_args => (
    PG_DSN, PG_DB_USER, PG_DB_PASS, {
        RaiseError     => 0,
        PrintError     => 0,
        pg_enable_utf8 => 1,
        HandleError    => Exception::Class::DBI->handler,
    }
);

=head1 Name

Kinetic::Store::DB::Pg - Postgres specific behavior for Kinetic::Store::DB

=head1 Synopsis

  use Kinetic::Store;

  my $store = Kinetic::Store->load('DB');

  $store->connect('dbi:Pg:kinetic', $user, $pw);

  my $coll = $store->search('Kinetic::SubClass' =>
                            attr => 'value');

=head1 Description

This class implements Postgres-specific behavior for the Kinetic
storage API, by overriding C<Kinetic::Store::DB> methods as needed.

=cut

##############################################################################

=head3 _set_id

  $store->_set_id($object);

This method is used by C<_insert> to set the C<id> of an object.  This is
frequently database specific, so this method may have to be overridden in a
subclass.  See C<_insert> for caveats about object C<id>s.

=cut

sub _set_id {
    my ($self, $object) = @_;
    my $view        = $self->search_class->key;
    # XXX This should work, but doesn't. The alternative is the equivalent,
    # so we'll just use it.
    #$object->{id}  = $self->_dbh->last_insert_id(
    #undef, undef, undef, undef, { sequence => 'seq_kinetic' }
    #);
    ($object->{id}) = $self->_dbh->selectrow_array("SELECT CURRVAL('seq_kinetic')");
    return $self;
}

##############################################################################

=head3 _full_text_search

  ...

TBD.

=cut

sub _full_text_search {
    # XXX not yet implemented
}

##############################################################################

=head3 _execute

  $self->_execute($sth, \@bind_params);

L<DBD::Pg|DBD::Pg> does not allow references in bind params, thus disallowing
objects overloaded for stringification.  This method converts all objects
who've had their stringify method overloaded into the overloaded form.

=cut

sub _execute {
    my ($self, $sth, $bind_params) = @_;
    @$bind_params = map { (ref && overload::Method($_, '""'))? "$_" : $_ } @$bind_params;
    $sth->execute(@$bind_params);
}

sub _eq_date_handler {
    my ($self, $search) = @_;
    my $date  = $search->data;
    my $field = $search->column;
    my $operator = $search->operator;
    my (@tokens, @values);
    foreach my $segment ($date->defined_store_fields) {
        push @tokens => "EXTRACT($segment FROM $field) $operator ?";
        push @values => $date->$segment;
    }
    return ("(".join(' AND ' => @tokens).")", \@values);
}

my %DATE = (
    year   => { format => 'IYYY', length => 4 },
    month  => { format => 'MM',   length => 2 },
    day    => { format => 'DD',   length => 2 },
    hour   => { format => 'HH24', length => 2 },
    minute => { format => 'MI',   length => 2 },
    second => { format => 'SS',   length => 2 },
);

sub _gt_lt_date_handler {
    my ($self, $search) = @_;
    my ($date, $operator) = ($search->data, $search->operator);
    unless ($date->contiguous) {
        require Carp;
        Carp::croak "You cannot do GT or LT type searches with non-contiguous dates";
    }
    my ($token, $value) = $self->_date_token_and_value($search, $date);
    return ("$token $operator ?", [$value]);
}

sub _date_token_and_value {
    my ($self, $search, $date) = @_;
    my ($format,$value) = ('','');
    foreach my $segment ($date->defined_store_fields) {
        $format .= $DATE{$segment}{format};
        $value  .= sprintf "%0$DATE{$segment}{length}d" => $date->$segment;
    }
    my $field = $search->column;
    my $token = "to_char($field, '$format')";
    return ($token, $value);
}

sub _between_date_handler {
    my ($self, $search) = @_;
    my $data = $search->data;
    my ($date1, $date2) = @$data;
    unless ($date1->contiguous && $date2->contiguous) {
        require Carp;
        Carp::croak "You cannot do range searches with non-contiguous dates";
    }
    unless ($date1->same_segments($date2)) {
        require Carp;
        Carp::croak "BETWEEN search dates must have identical segments defined";
    }
    my ($negated, $operator) = ($search->negated, $search->operator);
    my ($token, $value1) = $self->_date_token_and_value($search, $date1);
    my (undef,  $value2) = $self->_date_token_and_value($search, $date2);
    return ("$token $negated $operator ? AND ?", [$value1, $value2])
}

sub _any_date_handler {
    my ($self, $search)   = @_;
    my ($negated, $value) = ($search->negated, $search->data);
    my (@tokens, @values);
    my $field = $search->column;
    foreach my $date (@$value) {
        my ($token, $value) = $self->_date_token_and_value($search, $date);
        push @tokens => "$token = ?";
        push @values => $value;
    }
    my $token = join ' OR ' => @tokens;
    return ($token, \@values);
}

##############################################################################
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
