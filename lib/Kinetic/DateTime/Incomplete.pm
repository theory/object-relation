package Kinetic::DateTime::Incomplete;

# $Id: DateTime.pm 1253 2005-02-11 02:35:40Z theory $

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
use base 'DateTime::Incomplete';
use DateTime::TimeZone;

=head1 Name

Kinetic::DateTime::Incomplete - Incomplete Kinetic DateTime objects

=head1 Synopsis

  my $dt = Kinetic::DateTime::Incomplete->new(
    month  => 10,
    day    => 16,
  );

=head1 Description

This module subclasses the L<DateTime::Incomplete|DateTime::Incomplete> module
to offer DateTime::Incomplete objects to Kinetic applications. The only way in
which it differs from DateTime::Incomplete is that all new Kinetic::DateTime
objects are in the "UTC" time zone unless another time zone is specified and it
knows to properly stringify itself when accessed by
L<Kinetic::Store|Kinetic::Store>.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $dt = Kinetic::DateTime::Incomplete->new(
    month  => 10,
    day    => 16,
  );

Constructs and returns a new Kinetic::DateTime::Incomplete object. Unless a
time zone is specified, the time zone will be UTC.

=cut

my $utc = DateTime::TimeZone::UTC->new;

sub new { shift->SUPER::new(time_zone => $utc, @_) }

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2005 Kineticode, Inc. <info@kineticode.com>

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
