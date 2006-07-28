package Object::Relation::Handle::DB::SQLite;

# $Id$

use strict;
use base qw(Object::Relation::Handle::DB);
use version;
our $VERSION = version->new('0.0.2');

use Object::Relation::Handle qw(:logical);
use DBD::SQLite;
use Object::Relation::Handle::DB::SQLite::DBI;
use Object::Relation::Exceptions qw(throw_unsupported);
use Exception::Class::DBI;

use constant DBI_CLASS => 'Object::Relation::Handle::DB::SQLite::DBI';
use constant _connect_attrs => {
    RaiseError  => 0,
    PrintError  => 0,
    unicode     => 1,
    HandleError => Object::Relation::Exception::DBI->handler,
};

=head1 Name

Object::Relation::Handle::DB::SQLite - SQLite specific behavior for Object::Relation::Handle::DB

=head1 Synopsis

See L<Object::Relation::Handle|Object::Relation::Handle>.

=head1 Description

This class implements SQLite-specific behavior for the Object::Relation storage API by
overriding C<Object::Relation::Handle::DB> methods as needed. It uses
L<Object::Relation::Handle::DB::SQLite::DBI|Object::Relation::Handle::DB::SQLite::DBI>, a subclass
of the L<DBI|DBI>, for custom interactions with the database.

=cut

##############################################################################

=begin private

=head3 _set_id

  $store->_set_id($obj_rel_object);

SQLite-specific implementation of C<Object::Relation::Handle::DB::_set_id>.

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

Works like C<Object::Relation::Handle::DB::_MATCH_SEARCH> but supports full Perl regular
expressions via the SQLite C<REGEXP> operator. As the regular expressions are
compiled with the C<ixms> modifiers, they are always case-insensitive,
and C<^> matches the beginning of the whole string, and C<$> matches the end
of the whole string.

=cut

sub _MATCH_SEARCH {
    my ( $self, $search ) = @_;
    my $col = $search->notes('column');
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
    my $token    = $self->_field_format( $search->notes('column'), $date );
    my $operator = $search->operator;
    return ( "$token $operator ?", [ $date->sort_string ] );
}

sub _gt_lt_date_handler {
    my ( $self, $search ) = @_;
    my ( $date, $operator ) = ( $search->data, $search->operator );
    throw_unsupported
      "You cannot do GT or LT type searches with non-contiguous dates"
      unless $date->contiguous;
    my $token = $self->_field_format( $search->notes('column'), $date );
    my $value = $date->sort_string;
    return ( "$token $operator ?", [$value] );
}

sub _between_date_sql {
    my ( $self,    $search )   = @_;
    my ( $date1,   $date2 )    = @{ $search->data };
    my ( $negated, $operator ) = ( $search->negated, $search->operator );
    my $token = $self->_field_format( $search->notes('column'), $date1 );
    return (
        "$token $negated $operator ? AND ?",
        [ $date1->sort_string, $date2->sort_string ]
    );
}

sub _any_date_handler {
    my ( $self, $search ) = @_;
    my ( $negated, $value ) = ( $search->negated, $search->data );
    my ( @tokens, @values );
    my $field = $search->notes('column');
    foreach my $date (@$value) {
        my $token = $self->_field_format( $field, $date );
        push @tokens => "$token = ?";
        push @values => $date->sort_string;
    }
    my $token = join ' OR ' => @tokens;
    return ( $token, \@values );
}

##############################################################################

=head3 _coll_set

  $self->_coll_set($object, $attribute, \@coll_ids);

This method sets a collection to a specific list of IDs, using the SQLite
C<coll_set()> function defined by
L<Object::Relation::Handle::DB::SQLite::DBI|Object::Relation::Handle::DB::SQLite::DBI> to do so
correctly.

=cut

sub _coll_set { _coll_query(@_, 'set') }

##############################################################################

=head3 _coll_add

  $self->_coll_add($object, $attribute, \@coll_ids);

This method adds a specific list of IDs to a collection, using the SQLite
C<coll_add()> function defined by
L<Object::Relation::Handle::DB::SQLite::DBI|Object::Relation::Handle::DB::SQLite::DBI> to do so
correctly.

=cut

sub _coll_add { _coll_query(@_, 'add') }

##############################################################################

=head3 _coll_del

  $self->_coll_del($object, $attribute, \@coll_ids);

This method deletes a specific list of IDs from a collection, using the SQLite
C<coll_del()> function defined by
L<Object::Relation::Handle::DB::SQLite::DBI|Object::Relation::Handle::DB::SQLite::DBI> to do so
correctly.

=cut

sub _coll_del { _coll_query(@_, 'del') }

##############################################################################

=head3 _coll_clear

  $self->_coll_clear($object, $attribute);

This method clears a specific list of IDs from a collection, using the SQLite
C<coll_clear()> function defined by
L<Object::Relation::Handle::DB::SQLite::DBI|Object::Relation::Handle::DB::SQLite::DBI> to do so
correctly.

=cut

sub _coll_clear {
    my ($self, $obj, $attr, $coll_ids) = @_;
    my $sth = $self->_dbh->prepare_cached('SELECT coll_clear(?, ?, ?)');
    $sth->execute( $obj->my_class->key => $obj->id, $attr->name );
    $sth->finish;
    return $self;
}

##############################################################################

=head2 Private Functions

=head3 _coll_query

  _coll_query($object, $attribute, \@coll_ids, $function);

This function is called by C<_coll_set()>, C<_coll_add()>, and C<_coll_del()>
to actually do the work of executing the SQLite function. Since the three
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
    my $sth = $self->_dbh->prepare_cached("SELECT coll_$func(?, ?, ?, ?)");
    $sth->execute(
        $obj->my_class->key => $obj->id,
        $attr->name         => join ',', @$coll_ids
    );
    $sth->finish;
    return $self;
}

1;
__END__

=end private

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@obj_relode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
