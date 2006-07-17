package Kinetic::Util::Cache;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use Kinetic::Util::Exceptions qw(throw_unknown_class throw_unimplemented);

=head1 Name

Kinetic::Util::Cache - Kinetic caching

=head1 Synopsis

  use Kinetic::Util::Cache;

  my $cache = Kinetic::Util::Cache->new;
  $cache->set($id, $object);
  $cache->add($id, $object);
  $object = $cache->get($id);

=head1 Description

This class provides an interface for caching data in Kinetic, regardless of
the underlying caching mechanism chosen.

=cut

=head1 Methods

=head2 new

  my $cache = Kinetic::Util::Cache->new(
      $cache_class,
      $params,
  );

Returns a new cache object for whatever caching style was selected by the
user.

=cut

sub new {
    my ($pkg, $cache_class) = (shift, shift);
    eval "require $cache_class"
      or throw_unknown_class [
        'I could not load the class "[_1]": [_2]',
        $cache_class,
        $@
      ];
    return $cache_class->new(@_);
}

BEGIN {
    foreach my $method (qw/set add get remove/) {
        no strict 'refs';
        *$method = sub {
            throw_unimplemented [
                '"[_1]" must be overridden in a subclass',
                $method
            ];
        };
    }
}

sub _cache                  { shift->{cache} }

##############################################################################

=head3 set

  $cache->set($id, $object);

Adds an object to the cache regardless of whether or not that object exists.

=cut

##############################################################################

=head3 add

  $cache->add($id, $object);

Adds an object to the cache unless the object exists in the cache.  Returns a
boolean value indicating success or failure.

=cut

##############################################################################

=head3 get

  $cache->get($id);

Gets an object from the cache.

=cut

##############################################################################

=head3 remove

  $cache->remove($id);

Removes the corresponding object from the cache.

=cut

1;

__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut


