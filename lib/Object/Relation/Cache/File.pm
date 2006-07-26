package Object::Relation::Cache::File;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use base 'Object::Relation::Cache';

use aliased 'Cache::FileCache';    # In the Cache::Cache distribution

=head1 Name

Object::Relation::Cache::File - Object::Relation caching

=head1 Synopsis

  use Object::Relation::Cache::File;

  my $cache = Object::Relation::Cache::File->new;
  $cache->set($id, $object);
  $cache->add($id, $object);
  $object = $cache->get($id);

=head1 Description

This class provides an interface for caching data in Object::Relation,
regardless of the underlying caching mechanism chosen. See
L<Object::Relation::Cache|Object::Relation::Cache> for a description of the
interface.

=cut

sub new {
    my ($class, $params) = @_;
    bless {
        # XXX Add support for configuring these arguments.
        cache => FileCache->new({
            default_expires_in => $params->{expires} || 3600,
            namespace          => $class,
            cache_root         => $params->{root},
        }),
    }, $class;
}

sub set {
    my ( $self, $id, $object ) = @_;
    $self->_cache->purge;    # purge expired objects
    $self->_cache->set( $id, $object );
    return $self;
}

sub add {
    my ( $self, $id, $object ) = @_;
    return if $self->_cache->get($id);
    return $self->set( $id, $object );
}

sub get {
    my $self = shift;
    return $self->_cache->get(@_);
}

#sub clear {
#    my $self = shift;
#    $self->_cache->clear;
#    return $self;
#}

sub remove {
    my ( $self, $id ) = @_;
    $self->_cache->remove($id);
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

Copyright (c) 2004-2006 Kineticode, Inc. <info@obj_relode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut

