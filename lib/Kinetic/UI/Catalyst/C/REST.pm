package Kinetic::UI::Catalyst::C::REST;

# $Id: Catalyst.pm 2582 2006-02-07 02:27:45Z theory $

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or derivatives to
# this work, or any other work intended for use with the Kinetic framework, to
# Kineticode, Inc., you confirm that you are the copyright holder for those
# contributions and you grant Kineticode, Inc.  a nonexclusive, worldwide,
# irrevocable, royalty-free, perpetual license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute those
# contributions and any derivatives thereof.

use strict;
use warnings;
use base 'Catalyst::Controller';
use aliased 'Kinetic::UI::REST';

use version;
our $VERSION = version->new('0.0.1');

=head1 Name

Kinetic::UI::Catalyst::C::REST - Catalyst Controller

=head1 Synopsis

See L<Kinetic::UI::Catalyst>

=head1 Description

Catalyst Controller.

=head1 Methods

=head2 rest

  $c->forward('Kinetic::UI::Catalyst::C::REST', 'rest');

For a URL in the form C</rest/$rest_parameters>, this method will pull the
appropriate REST information and return it in the form of the first arg after
"rest/" in the URL (currently 'json' or 'xml').

=cut

sub rest : Regex('^rest/(.*)') {
    my ( $self, $c ) = @_;

    # Hello World
    $c->response->body('Kinetic::UI::Catalyst::C::REST is on Catalyst!');
    my $base_url = $c->uri_for('');
    my $rest = REST->new( base_url => $base_url );
    $rest->handle_request( $c->req );
    $c->res->header( 'Content-Type' => $rest->content_type );
    $c->res->status( $rest->status );
    $c->res->content_length( length $rest->response );
    $c->response->body( $rest->response );
}

1;
__END__

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
