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
use constant _dsn => ('dbi:SQLite:dbname=' . SQLITE_FILE, '', '');

=head1 Name

Kinetic::Store::DB::SQLite - SQLite specific behavior for Kinetic::Store::DB

=head1 Synopsis

See L<Kinetic::Store|Kinetic::Store>.

=head1 Description

This class implements SQLite-specific behavior for the Kinetic storage API by
overriding C<Kinetic::Store::DB> methods as needed.

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

sub _comparison_operator {
    my ($class, $key) = @_;
    if ($key =~ /MATCH/) {
        require Carp;
        Carp::croak("$key:  SQLite does not support regular expressions");
    }
    return $class->SUPER::_comparison_operator($key);
}

1;
__END__

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. <info@kineticode.com>

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
