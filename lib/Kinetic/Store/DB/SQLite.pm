Postgrespackage Kinetic::Store::DB::SQLite;

# $Id$

use strict;
use base qw(Kinetic::Store::DB);

=head1 Name

Kinetic::Store::DB::SQLite - SQLite specific behavior for Kinetic::Store::DB

=head1 Synopsis

  use Kinetic::Store;

  my $store = Kinetic::Store->load('DB');

  $store->connect('dbi:SQLite:dbname=kinetic.db', '', '');

  my $coll = $store->search('Kinetic::SubClass' =>
                            attr => 'value');

=head1 Description

This class implements SQLite-specific behavior for the Kinetic
storage API, by overriding C<Kinetic::Store::DB> methods as needed.

=cut

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
