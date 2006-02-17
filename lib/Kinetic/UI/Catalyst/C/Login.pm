package Kinetic::UI::Catalyst::C::Login;

# $Id$

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

use version;
our $VERSION = version->new('0.0.1');

=head1 Name

Kinetic::UI::Catalyst::C::Login - Catalyst Controller

=head1 Synopsis

See L<Kinetic::UI::Catalyst>

=head1 Description

Catalyst Controller.

=head1 Methods

=cut

##############################################################################

=head2 login

  $c->forward("Kinetic::UI::Catalyst::C::Login", 'login');

This method automatically checks authentication and attempts to log the user
in.  If successful, forwards them to the referring page.  Otherwise, returns
them to the login screen.

=cut

sub login : Local {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'login.tt';

    $c->session->{referer} ||= $c->req->referer;
    if ( !$c->login ) {
        if (! $c->session->{tried_to_login}) {
            $c->session->{tried_to_login} = 1;
        }
        else {
            $c->log->debug('login failed');
            $c->stash->{message} = 'Login failed.';
        }
        $c->forward('Kinetic::UI::Catalyst::V::TT');
    }
    else {
        if ( $c->session->{referer} =~ m{log(?:in|out)$} ) {
            $c->session->{referer} ||= $c->req->referer;
        }
        $c->log->debug('login succeeded');
        $c->session->{tried_to_login} = 0;
        $c->res->redirect( $c->session->{referer} );
    }
}

##############################################################################

=head3 logout

  $c->logout;

Logs the user out of their session.

=cut

sub logout : Global {
    my ( $self, $c ) = @_;
    $c->logout;
    $c->req->action(undef);
    $c->forward( 'login', 'login' );
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
