package Kinetic::Store::DB::mysql;

# $Id$

use strict;
use base qw(Kinetic::Store::DB);

=head1 Name

Kinetic::Store::DB::mysql - MySQL specific behavior for Kinetic::Store::DB

=head1 Synopsis

  use Kinetic::Store;

  my $store = Kinetic::Store->load('DB');

  $store->connect('dbi:mysql:kinetic', $user, $pw);

  my $coll = $store->search('Kinetic::SubClass' =>
                            attr => 'value');

=head1 Description

This class implements MySQL-specific behavior for the Kinetic
storage API, by overriding C<Kinetic::Store::DB> methods as needed.

=cut

sub _comparison_operator_for_single {
    my $self = shift;
    my ($has_not, $operator, $type) = @_;

    if ( $operator eq 'LIKE' ) {
        return $has_not ? 'NOT REGEXP' : 'REGEXP';
    } else {
        return $self->SUPER::_comparison_operator_for_single(@_);
    }
}
