package Kinetic::Format::JSON;

# $Id: JSON.pm 2190 2005-11-08 02:05:10Z curtis $

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
use warnings;
use Kinetic::Util::Constants '$TEXT_CT';
use JSON ();
use Class::Delegator
  send => [qw/objToJson jsonToObj/],
  to   => '{json}';

use version;
our $VERSION = version->new('0.0.1');

use base 'Kinetic::Format';

=head1 Name

Kinetic::Format::JSON - The Kinetic JSON serialization class

=head1 Synopsis

  use Kinetic::Format::JSON;
  my $formatter = Kinetic::Format::JSON->new;
  my $json      = $formatter->serialize($kinetic_object);
  my $object    = $formatter->deserialize($json);

=head1 Description

This class is used for serializing and deserializing Kinetic objects to and 
from JSON.  New objects may be created or existing objects may be updated using
this class.

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

  my $xml = Kinetic::Format::JSON->new;
  # or
  my $xml = Kinetic::Format::JSON->new({
    pretty => 1,
    indent => 2,
  });

Creates and returns a new JSON format  object.  It optionally takes a
L<Kinetic|Kinetic> object as an argument.  This is equivalent to:

If preferred, a hashref may be passed as an argument.  Keys are:

=over 4

=item * pretty

Whether to use newlines between JSON elements.

=item * indent

Indentation level (in spaces) for nested JSON elements.

=back

As a general rule, you will want to call C<new> without arguments.  This
ensures a more compact JSON representation, thus saving bandwidth.

=cut

sub _init {
    my ( $class, $arg_for ) = @_;
    $arg_for ||= {};
    my $json = JSON->new(%$arg_for);
    $json->unmapping(1)
      ;    # return 'null' as undef instead of a JSON::NotString object
    $arg_for->{json} = $json;
    return $arg_for;
}

##############################################################################

=head3 content_type

  my $content_type = $formatter->content_type;

Returns the MIME content type for the current format.

=cut

# XXX There also appears to be a 'text/x-json' content type, but it's not
# standard, not is it widespread.

sub content_type { $TEXT_CT }

##############################################################################

=head3 ref_to_format

  my $json = $formatter->ref_to_format($reference);

Converts an arbitrary reference to its JSON equivalent.

=cut

sub ref_to_format {
    my ( $self, $ref ) = @_;
    $ref = $self->expand_ref($ref);
    return $self->objToJson($ref);
}

##############################################################################

=head3 format_to_ref

  my $reference = $formatter->format_to_ref($json);

Converts JSON to its equivalent Perl reference.

=cut

sub format_to_ref { shift->jsonToObj(@_) }

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
