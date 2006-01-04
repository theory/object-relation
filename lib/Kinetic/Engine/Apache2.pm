package Kinetic::Engine::Apache2;

# $Id: Engine.pm 2414 2005-12-22 07:21:05Z theory $

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

use version;
our $VERSION = version->new('0.0.1');

use CGI;
CGI->compile;
use aliased 'Kinetic::UI::Catalyst';
use aliased 'Kinetic::UI::REST';

##############################################################################

=head2 handler

  Kinetic::Engine::Apache2::handler($r);

Kinetic <mod_perl> 2.0 handler.

=cut

# XXX There are plenty of Apache constants which we do not handle because
# Catalyst handles them for us by detecting the environment it runs under.
# I am not yet sure how REST will handle this.

sub handler {
    my $r = shift;
    return Catalyst->handle_request($r);
}

##############################################################################

=head2 rest

  Kinetic::Engine::Apache2::rest($r);

The Kinetic REST handler.  See C<Kinetic::UI::REST>.

=cut

use Apache2::RequestRec ();
use Apache2::RequestIO  ();

use Apache2::Const -compile => qw(OK);

{
    my $rest;

    sub rest {
        my $r = shift;
        unless ( defined $rest ) {
            $rest = _get_rest_object($r);
        }
        $rest->handle_request( CGI->new($r) );
        $r->content_type('text/plain');
        $r->print( $rest->response );

        return Apache2::Const::OK;
    }
}

sub _get_rest_object {
    # XXX much of this is cribbed from Catalyst::Engine::Apache
    my $r = shift;
    my $secure = ( ( $ENV{HTTPS} && uc $ENV{HTTPS} eq 'ON' )
          || ( 443 == $r->get_server_port ) ) ? 1 : 0;
    my $scheme = $secure ? 'https' : 'http';
    my $host = $r->hostname || 'localhost';
    my $port = $r->get_server_port;

    my $base_path = '';

    # Are we running in a non-root Location block?
    my $location = $r->location;
    if ( $location && $location ne '/' ) {
        $base_path = $location;
    }
    my $uri = URI->new;
    $uri->scheme($scheme);
    $uri->host($host);
    $uri->port($port);
    $uri->path( $r->uri );
    my $query_string = $r->args;
    $uri->query($query_string);

    # sanitize the URI
    $uri = $uri->canonical;

    $location = substr $location, 1;
    my ($domain) = $uri =~ m{^(.+)$location};
    return REST->new( domain => $domain, path => $location );
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
