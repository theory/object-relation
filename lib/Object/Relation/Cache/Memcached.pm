package Object::Relation::Cache::Memcached;

# $Id$

use strict;

our $VERSION = '0.11';

use base 'Object::Relation::Cache';
use aliased 'Cache::Memcached';

=head1 Name

Object::Relation::Cache::Memcached - Object::Relation caching

=head1 Synopsis

  use Object::Relation::Cache::Memcached;

  my $cache = Object::Relation::Cache::Memcached->new;
  $cache->set($id, $object);
  $cache->add($id, $object);
  $object = $cache->get($id);

=head1 Description

This class provides an interface for caching data in Object::Relation,
regardless of the underlying caching mechanism chosen.

=cut

my %IDS;    # YUCK!

sub new {
    my ($class, $params) = @_;
    bless {
        # XXX Add support for configuring these arguments.
        cache   => Memcached->new( { servers => [127.0.0.1:11211] } ),
        expires => $params->{expires} || 3600,
    }, $class;
}

sub set {
    my ( $self, $id, $object ) = @_;
    $self->_cache->set( $id, $object, $self->{expires} );
    $IDS{$id} = 1;
    return $self;
}

sub add {
    my ( $self, $id, $object ) = @_;
    return if $self->get($id);
    $IDS{$id} = 1;
    $self->_cache->add( $id, $object, $self->{expires} );
    return $self;
}

sub get {
    my ( $self, $id ) = @_;
    my $object = $self->_cache->get($id);
    return $object if $object;
    delete $IDS{$id};
    return;
}

#sub clear {
#    my $self  = shift;
#    my $cache = $self->_cache;
#    $cache->delete($_) foreach keys %IDS;
#    %IDS = ();
#    return $self;
#}

sub remove {
    my ( $self, $id ) = @_;
    $self->_cache->delete($id);
    delete $IDS{$id};
    return $self;
}

=head1 Overridden methods

=over 4

=item * new

=item * set

=item * add

=item * get

=item * remove

=back

=cut

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut


