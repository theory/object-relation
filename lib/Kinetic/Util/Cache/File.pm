package Kinetic::Util::Cache::File;

# $Id: Cache.pm 2488 2006-01-04 05:17:14Z theory $

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

=head1 Name

Kinetic::Util::Cache::File - Kinetic caching

=head1 Synopsis

  use Kinetic::Util::Cache::File;

  my $cache = Kinetic::Util::Cache::File->new;
  $cache->set($uuid, $object);
  $cache->add($uuid, $object);
  $object = $cache->get($uuid);

=head1 Description

This class provides an interface for caching data in Kinetic, regardless of
the underlying caching mechanism chosen.

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


