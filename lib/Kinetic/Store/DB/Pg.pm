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

use version;
our $VERSION = version->new('0.0.2');

use base qw(Kinetic::Store::DB);
use Exception::Class::DBI;
use Kinetic::Util::Exceptions qw(throw_unsupported);
use List::Util qw(first);
use DBI        qw(:sql_types);
use DBD::Pg    qw(:pg_types);
use overload;
use constant _connect_attrs => {
    RaiseError     => 0,
    PrintError     => 0,
    pg_enable_utf8 => 1,
    HandleError    => Kinetic::Util::Exception::DBI->handler,
};

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

=begin private

=head1 Interface

=head2 Private Instance Methods

=head3 _set_id

  $store->_set_id($object);

This method is used by C<_insert> to set the C<id> of an object from the
sequence used to insert it. See C<_insert> for caveats about object C<id>s.

=cut

sub _set_id {
    my ( $self, $object ) = @_;
    my $class = $object->my_class;
    my $seq   = $class->key;

    # If this class inherits from other classes, the sequence will be that
    # of the base class.
    if (my $base = first { !$_->abstract } reverse $class->parents) {
        $seq = $base->key;
    }

    # XXX This should work, but doesn't. The alternative is the equivalent,
    # so we'll just use it.
    #$object->{id}  = $self->_dbh->last_insert_id(
    #undef, undef, undef, undef, { sequence => "seq_$seq" }
    #);
    $object->id(
        $self->_dbh->selectrow_array("SELECT CURRVAL('seq_$seq')")
    );
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

=head3 _bind_attr

  my $bind_attr = $store->_bind_attr($type_name);

Returns a hash reference to be used as the attribute argument to a call to
C<bind_col()> or C<bind_param()> on a DBI statement handle. For most data
types, no such attribute is necessary, and so this method will return
C<undef>. But for a few, such as C<binary> and C<blob>, it will return the
appropriate hash reference, e.g., C<{ pg_type => PG_BYTEA }>.

=cut

sub _bind_attr {
    my ($self, $type) = @_;
    return { pg_type => PG_BYTEA } if $type eq 'binary';
    return { TYPE => SQL_BLOB }    if $type eq 'blob';
    return;
}

##############################################################################

=head3 _execute

  $self->_execute($sth, \@bind_params);

L<DBD::Pg|DBD::Pg> does not allow references in bind params, thus disallowing
objects overloaded for stringification.  This method converts all objects
who've had their stringify method overloaded into the overloaded form.

=cut

sub _execute {
    my ( $self, $sth, $bind_params ) = @_;
    @$bind_params =
      map { ( ref && overload::Method( $_, '""' ) ) ? "$_" : $_ } @$bind_params;
    $sth->execute(@$bind_params);
}

sub _eq_date_handler {
    my ( $self, $search ) = @_;
    my $date     = $search->data;
    my $field    = $search->notes('column');
    my $operator = $search->operator;
    my ( @tokens, @values );
    foreach my $segment ( $date->defined_store_fields ) {
        push @tokens => "EXTRACT($segment FROM $field) $operator ?";
        push @values => $date->$segment;
    }
    return ( "(" . join ( ' AND ' => @tokens ) . ")", \@values );
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
    my ( $self, $search ) = @_;
    my ( $date, $operator ) = ( $search->data, $search->operator );
    throw_unsupported
      "You cannot do GT or LT type searches with non-contiguous dates"
      unless $date->contiguous;
    my ( $token, $value ) = $self->_date_token_and_value( $search, $date );
    return ( "$token $operator ?", [$value] );
}

sub _date_token_and_value {
    my ( $self, $search, $date ) = @_;
    my ( $format, $value ) = ( '', '' );
    foreach my $segment ( $date->defined_store_fields ) {
        $format .= $DATE{$segment}{format};
        $value .= sprintf "%0$DATE{$segment}{length}d" => $date->$segment;
    }
    my $field = $search->notes('column');
    my $token = "to_char($field, '$format')";
    return ( $token, $value );
}

sub _between_date_sql {
    my ( $self,    $search )   = @_;
    my ( $date1,   $date2 )    = @{ $search->data };
    my ( $negated, $operator ) = ( $search->negated, $search->operator );
    my ( $token, $value1 ) = $self->_date_token_and_value( $search, $date1 );
    my ( undef, $value2 ) = $self->_date_token_and_value( $search, $date2 );
    return ( "$token $negated $operator ? AND ?", [ $value1, $value2 ] );
}

sub _any_date_handler {
    my ( $self, $search ) = @_;
    my ( $negated, $value ) = ( $search->negated, $search->data );
    my ( @tokens, @values );
    my $field = $search->notes('column');
    foreach my $date (@$value) {
        my ( $token, $value ) = $self->_date_token_and_value( $search, $date );
        push @tokens => "$token = ?";
        push @values => $value;
    }
    my $token = join ' OR ' => @tokens;
    return ( $token, \@values );
}

##############################################################################

=head3 _coll_set

  $self->_coll_set($object, $attribute, \@coll_ids);

This method sets a collection to a specific list of IDs, using the PL/pgSQL
C<*_set()> function to do so correctly and efficiently.

=cut

sub _coll_set { _coll_query(@_, 'set'); }

##############################################################################

=head3 _coll_add

  $self->_coll_add($object, $attribute, \@coll_ids);

This method adds a specific list of IDs to a collection, using the PL/pgSQL
C<*_add()> function to do so correctly and efficiently.

=cut

sub _coll_add { _coll_query(@_, 'add'); }

##############################################################################

=head3 _coll_del

  $self->_coll_del($object, $attribute, \@coll_ids);

This method deletes a specific list of IDs from a collection, using the
PL/pgSQL C<*_del()> function to do so correctly and efficiently.

=cut

sub _coll_del { _coll_query(@_, 'del'); }

##############################################################################

=head3 _coll_clear

  $self->_coll_clear($object, $attribute);

This method clears a specific list of IDs from a collection, using the
PL/pgSQL C<*_clear()> function to do so correctly and efficiently.

=cut

sub _coll_clear {
    my ($self, $obj, $attr) = @_;
    my $func = $attr->collection_view . '_clear';
    my $sth = $self->_dbh->prepare_cached("SELECT $func(?)");
    $sth->execute($obj->id);
    $sth->finish;
    return $self;
}

##############################################################################

=head2 Private Functions

=head3 _coll_query

  _coll_query($object, $attribute, \@coll_ids, $function);

This function is called by C<_coll_set()>, C<_coll_add()>, and C<_coll_del()>
to actually do the work of executing the PL/pgSQL function. Since the three
functions are all executed identically except in the name of he function, the
arguments are the same as those to the methods, with the addition of an extra
argument specifying the function to call. The C<$function> argument may be any
one of:

=over

=item set

=item add

=item del

=back

=cut

sub _coll_query {
    my ($self, $obj, $attr, $coll_ids, $func) = @_;
    $func   = $attr->collection_view . "_$func";
    my $sth = $self->_dbh->prepare_cached("SELECT $func(?, ?)");
    $sth->execute($obj->id, '{' . join(',', @$coll_ids) . '}');
    $sth->finish;
    return $self;
}

##############################################################################

1;
__END__

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
