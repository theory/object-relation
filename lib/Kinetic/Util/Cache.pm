package Kinetic::Util::Cache;

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

use version;
our $VERSION = version->new('0.0.1');

use Kinetic::Util::Config qw(:cache);
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

  my $cache = Kinetic::Util::Cache->new;

Returns a new cache object for whatever caching style was selected by the
user.

=cut

sub new {
    my $class       = shift;
    my $cache_class = CACHE_OBJECT;
    eval "require $cache_class"
      or throw_unknown_class [
        'I could not load the class "[_1]": [_2]',
        $cache_class,
        $@
      ];
    return $cache_class->new;
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

# Testing hook
sub _expire_time_in_seconds {CACHE_EXPIRES}

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

=head1 See Also

=over 4

=item L<Kinetic::Util::Context|Kinetic::Util::Context>

Kinetic utility object context

=back

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

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


