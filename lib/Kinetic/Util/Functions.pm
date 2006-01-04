package Kinetic::Util::Functions;

# $Id: Constants.pm 1818 2005-06-29 03:35:14Z curtis $

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
use OSSP::uuid;
use MIME::Base64;

=head1 Name

Kinetic::Util::Functions - Kinetic Utility Functions.

=head1 Synopsis

  use Kinetic::Util::Functions qw/:uuid/;
  my $uuid = create_uuid();

=head1 Description

This class is a centralized repository for Kinetic utility functions.

=cut

use Exporter::Tidy
    uuid => [qw(
        create_uuid
        uuid_to_bin
        uuid_to_hex
        uuid_to_b64
    )],
;

##############################################################################

=head2 :uuid

These functions manage UUIDs.

=over

=item * create_uuid()

Generates and returns a version 4 UUID string.

=item * uuid_to_bin

Converts a UUID from its string representation into its binary representation.

=item * uuid_to_hex

Converts a UUID from its string representation into its hex representation.

=item * uuid_to_b64

Converts a UUID from its string representation into its base 64
representation.

=back

=cut

sub create_uuid {
    my $uuid = OSSP::uuid->new;
    $uuid->make('v4');
    return $uuid->export('str');
}

sub uuid_to_bin {
    my $uuid = OSSP::uuid->new;
    $uuid->import(str => shift);
    return $uuid->export('bin');
}

sub uuid_to_hex {
    (my $uuid = shift) =~ s/-//g;
    return "0x$uuid";
}

sub uuid_to_b64 {
    encode_base64(uuid_to_bin(shift));
}

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
