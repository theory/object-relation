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
    #$object->{id}  = $self->_dbh->last_insert_id(undef, undef, $view, undef); # XXX Doesn't work
    #($object->{id}) = $self->_dbh->selectrow_array("SELECT MAX(id) FROM $view"); # XXX Aack!
    #$object->{id}  = $self->_dbh->last_insert_id(undef, undef, undef, undef, {sequence => 'seq_kinetic' });
    ($object->{id}) = $self->_dbh->selectrow_array("SELECT CURRVAL('seq_kinetic')"); # XXX Aack!
    return $self;
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

sub _cast_as_int {
    my ($self, @tokens) = @_;
    return 'CAST('. join(' || ' => @tokens) .' AS int8)';
}

sub _comparison_operator_for_single {
    my $self = shift;
    my ($has_not, $operator, $type) = @_;

    if ( $operator eq 'LIKE' ) {
        return $has_not ? '!~' : '~';
    } else {
        return $self->SUPER::_comparison_operator_for_single(@_);
    }
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
