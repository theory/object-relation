package Kinetic::DataType::MediaType;

# $Id: MediaType.pm 2488 2006-01-04 05:17:14Z theory $

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
use base 'MIME::Type';
use MIME::Types;
use Kinetic::Meta::Type;
use Kinetic::Util::Exceptions qw(throw_invalid);

use version;
our $VERSION = version->new('0.0.1');

=head1 Name

Kinetic::DataType::MediaType - Kinetic MediaType objects

=head1 Synopsis

  use aliased 'Kinetic::DataType::MediaType';
  my $media_type = MediaType->bake('text/html');

=head1 Description

This module creates the "media_type" data type for use in Kinetic attributes.
It subclasses the L<MIME::Type|MIME::Type> module to offer media types to
Kinetic applications. It differs from MIME::Type in providing the C<bake()>
method for deserialization from the data store. Use the C<type()> method for
serialization.

=cut

# Create the data type.
Kinetic::Meta::Type->add(
    key   => 'media_type',
    name  => 'Media Type',
    raw   => sub { ref $_[0] ? shift->type : shift },
    bake  => sub { __PACKAGE__->bake(shift) },
    check => __PACKAGE__,
);

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $media_type = Kinetic::DataType::MediaType->new($string);

Overrides the implementation of C<new()> in L<MIME::Type|MIME::Type> to
redispatch to C<bake()> if there is only one agrument. Otherwise, it sends the
arguments off to MIME::Type's C<new()>.

=cut

sub new {
    my $class = shift;
    return @_ == 1 ? $class->bake(@_) : $class->SUPER::new(@_);
}

##############################################################################

=head3 bake

  my $media_type = Kinetic::DataType::MediaType->bake($string);

Parses a media type string and returns a Kinetic::DataType::MediaType object.
If the media type does not currently exist, it will be created by calling
C<new()>.

=cut

my $mt = MIME::Types->new;
sub bake {
    my ($class, $string) = @_;
    throw_invalid [ 'Value "[_1]" is not a valid media type', $string, ]
        if $string !~ m{\w+/\w+};
    return bless +(
        $mt->type($string) || __PACKAGE__->new(type => $string)
    ), $class;
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
