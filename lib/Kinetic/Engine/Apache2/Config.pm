package Kinetic::Engine::Apache2::Config;

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

use version;
our $VERSION = version->new('0.0.1');

use CGI;
CGI->compile;

use Kinetic::Util::Config qw(:kinetic);
use Apache2::Const -compile => qw(OK);
use Apache2::ServerUtil ();
use File::Spec::Functions qw(catdir);


BEGIN {
    sub _apache_conf_template {
        my $self       = shift;
        my $doc_root   = catdir(KINETIC_ROOT, 'root');
        my $base_uri   = KINETIC_BASE_URI;

        return <<"        END_CONF";
    DocumentRoot $doc_root

    <Location $base_uri>
        SetHandler          modperl
        PerlResponseHandler Kinetic::Engine::Apache2::Config
        Order allow,deny
        Allow from all
    </Location>

    # static files
    <Location $base_uri/ui>
        Order allow,deny
        Allow from all
    </Location>

    # REST
    <Location $base_uri/rest>
        SetHandler          modperl
        PerlResponseHandler Kinetic::Engine::Apache2::Config::rest
    </Location>
        END_CONF
    }
    my $conf = __PACKAGE__->_apache_conf_template;
    Apache2::ServerUtil->server->add_config( [ split /\n/, $conf ] );
}

# XXX Important:  server->add_config must be called *before* the Kinetic app
# modules are loaded.  For some reason, we're having problems with Class::Meta
# getting loaded twice, wiping out whatever value Kinetic::Meta->keys returns.
use Kinetic::Engine; # loads the modules
use aliased 'Kinetic::UI::Catalyst';
use aliased 'Kinetic::UI::REST';


##############################################################################

=head2 handler

  Kinetic::Engine::Apache2::Config::handler($r);

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

  Kinetic::Engine::Apache2::Config::rest($r);

The Kinetic REST handler.  See C<Kinetic::UI::REST>.

=cut

{
    my $rest;

    sub rest {
        my $r = shift;
        unless ( defined $rest ) {
            $rest = _get_rest_object($r);
        }
        $rest->handle_request( CGI->new($r) );
        $r->content_type( $rest->content_type );
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
    my ($base_url) = $uri =~ m{^(.+$location)};
    return REST->new( base_url => $base_url );
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
