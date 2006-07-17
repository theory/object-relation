package Kinetic::Store::Handle::DB::mysql;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use base qw(Kinetic::Store::Handle::DB);

=head1 Name

Kinetic::Store::Handle::DB::mysql - MySQL specific behavior for Kinetic::Store::Handle::DB

=head1 Synopsis

  use Kinetic::Store::Handle;

  my $store = Kinetic::Store::Handle->load('DB');

  $store->connect('dbi:mysql:kinetic', $user, $pw);

  my $coll = $store->search('Kinetic::SubClass' =>
                            attr => 'value');

=head1 Description

This class implements MySQL-specific behavior for the Kinetic
storage API, by overriding C<Kinetic::Store::Handle::DB> methods as needed.

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

1;
__END__

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
