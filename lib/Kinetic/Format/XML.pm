package Kinetic::Format::XML;

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
use warnings;
use XML::Simple ();

use version;
our $VERSION = version->new('0.0.2');

use base 'Kinetic::Format';

=head1 Name

Kinetic::Format::XML - The Kinetic XML serialization class

=head1 Synopsis

  use Kinetic::Format::XML;
  my $formatter = Kinetic::Format::XML->new;
  my $xml      = $formatter->serialize($kinetic_object);
  my $object    = $formatter->deserialize($xml);

=head1 Description

This class is used for serializing and deserializing Kinetic objects to and 
from XML.  New objects may be created or existing objects may be updated using
this class.

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

  my $xml = Kinetic::Format::XML->new;
  # or
  my $xml = Kinetic::Format::XML->new({
    pretty => 1,
    indent => 2,
  });

Creates and returns a new XML format  object.  It optionally takes a
L<Kinetic|Kinetic> object as an argument.  This is equivalent to:

If preferred, a hashref may be passed as an argument.  Keys are:

=over 4

=item * pretty

Whether to use newlines between XML elements.

=item * indent

Indentation level (in spaces) for nested XML elements.

=back

As a general rule, you will want to call C<new> without arguments.  This
ensures a more compact XML representation, thus saving bandwidth.

=cut

sub _init {
    my ( $class, $arg_for ) = @_;
    $arg_for ||= {};
    my $xml  = XML::Simple->new;
    $arg_for->{xml} = $xml;
    return $arg_for;
}

##############################################################################

=head3 content_type

  my $content_type = $formatter->content_type;

Returns the MIME content type for the current format.

=cut

sub content_type { 'text/xml' }

##############################################################################

=head3 ref_to_format

  my $xml = $formatter->ref_to_format($reference);

Converts an arbitrary reference to its XML equivalent.

=cut

sub ref_to_format {
    my ( $self, $ref ) = @_;
    $ref = $self->expand_ref($ref);
    local $^W;   # suppress "uninitialized" warnings.  These are common with
                 # undef keys
    return $self->{xml}->XMLout($ref);
}

##############################################################################

=head3 format_to_ref

  my $reference = $formatter->format_to_ref($xml);

Converts XML to its equivalent Perl reference.

=cut

sub format_to_ref { 
    my ($self, $xml) = @_; 
    return $self->{xml}->XMLin(
        $xml,
        suppressempty => undef,
        keyattr       => [],
        #ForceArray    => [ 'instance' ], # XXX maybe later?
    );
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
