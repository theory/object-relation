package Kinetic::Party;

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
use base qw(Kinetic);

=head1 Name

Kinetic::Party - Kinetic parties (people, organizations)

=head1 Description

This class serves as the abstract base class for parties in Kinetic. By
"party", we do not, unfortunately, mean that this class will serve drinks and
hors d'oevres or get people dancing to the music. Rather, a "party" is a
person or an organization. See the
L<Kinetic::Party::Person|Kinetic::Party::Person> and
L<Kinetic::Party::Org|Kinetic::Party::Org> subclasses for full
implementations.

=cut

BEGIN {
    my $cm = Kinetic::Meta->new(
        key         => 'party',
        name        => 'Party',
        plural_name => 'Parties',
        abstract    => 1,
    );

##############################################################################
# Constructors.
##############################################################################

=head1 Instance Interface

In addition to the interface inherited from L<Kinetic|Kinetic>, this class
offers a number of its own attributes.

=head2 Accessors

=head3 contacts

  my $contacts = $party->contacts;

Returns a Kinetic::Util::Collection of Kinetic::Contact objects associated
with the party. Use the collection API to add contacts to or remove contacts
from the party.

=cut

##############################################################################

=head3 placements

  my $placements = $party->placements;

Returns a Kinetic::Util::Collection of Kinetic::Placment objects associated
with the party. Use the collection API to add places to or remove places from
the party.

=cut

    $cm->build;
} # BEGIN

1;
__END__

##############################################################################

=head1 See Also

=over 4

=item L<Kinetic|Kinetic>

The class from which Kinetic::Party inherits.

=item L<Kinetic::Party::Person|Kinetic::Party::Person>

A concrete base class that inerites from Kinetic::Party.

=item L<Kinetic::Party::Org|Kinetic::Party::Org>

Another concrete base class that inerites from Kinetic::Party.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. <info@kineticode.com>

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