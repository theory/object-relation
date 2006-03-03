package Kinetic::Type::Contact;

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

use base 'Kinetic::Type';
use Kinetic::Meta;
use Kinetic::Meta::Declare ':all';

=head1 Name

Kinetic::Type::Contact - Kinetic person objects

=head1 Description

This class serves as the base class for contacts in TKP.  See the
L<Kinetic::Contact|Kinetic::Contact> for full implementation.

=cut

##############################################################################
# Instance Interface.
##############################################################################

=head1 Instance Interface

=cut

# XXX we're not actually inheriting from Kinetic::Type yet

#In addition to the interface inherited from L<Kinetic::|Kinetic> and
#L<Kinetic::Type|Kinetic::Type>, this class offers a number of its own
#attributes.

=head2 Accessors

=head3 description 

  my $description = $contact->description;
  $contact->description($description);

The description of the contact.

=cut

Kinetic::Meta::Declare->new(
    meta => [
        key         => 'contact_type',
        plural_name => 'Contact types',
    ],
    attributes => [
        description => {
            widget_meta => Kinetic::Meta::Widget->new(
                type => 'text',
                tip  => "The description of the contact"
            )
        },
    ],
);

1;
__END__

##############################################################################

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
