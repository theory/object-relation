package Kinetic::Store::DBI::Pg;

# $Id$

use strict;
use base qw(Kinetic::Store::DBI);
=head1 Name

Kinetic::Store::DBI::Pg - Postgres specific behavior for Kinetic::Store::DBI

=head1 Synopsis

  use Kinetic::Store;

  my $store = Kinetic::Store->load('DBI');

  $store->connect('dbi:Pg:kinetic', $user, $pw);

  my $coll = $store->search('Kinetic::SubClass' =>
                            attr => 'value');

=head1 Description

This class implements Postgres-specific behavior for the Kinetic
storage API, by overriding C<Kinetic::Store::DBI> methods as needed.

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
