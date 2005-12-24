package Kinetic::Engine::Request::CGI;

# $Id: CGI.pm 2414 2005-12-22 07:21:05Z theory $

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
use base 'Kinetic::Engine::Request';
use Kinetic::Util::Exceptions qw/throw_fatal/;

use version;
our $VERSION = version->new('0.0.1');

# XXX Currently there is no implementation here.  This is merely a stub so
# that the common request object can be tested

##############################################################################

=head3 new

 my $engine = Kinetic::Engine::Request::CGI->new; 

Returns a new Kinetic::Engine::Request object.  This class is actually a factory which
will return an object corresponding to the appropriate subclass for Catalyst,
Apache, SOAP, etc.

=cut

sub new {
    my $class = shift;
    bless {}, $class;
}

sub param {
    my $self = shift;
    my $cgi  = $self->handler;
    return sort $cgi->param unless @_;
    if ( 1 == @_ ) {
        my $param = shift;
        return wantarray ? $cgi->param($param) : scalar $cgi->param($param);
    }
    my ( $param, $value ) = @_;
    unless ( 'ARRAY' eq ref $value ) {
        throw_fatal [ 'Argument "[_1]" is not an array reference', 'value' ];
    }
    $cgi->param( -name => $param, -value => $value );
}

1;

##############################################################################

=head1 OVERRIDDEN METHODS

=over 4

=item * param

=back

=cut

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
