package Kinetic::UI::Catalyst::Auth::Credential::Password;

# $Id: Password.pm 2633 2006-02-15 20:21:23Z curtispoe $

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

=head1 Name

Kinetic::UI::Catalyst::Auth::Credential::Password - Web password authentication

=head1 Synopsis

 use base 'Kinetic::UI::Catalyst::Auth::Credential::Password';
 use Kinetic::UI::Catalyst @plugins;

=head1 Description

This module implements authentication for the Kinetic Catalyst interface.
However, it will probably be moved to the L<Kinetic::UI::Catalyst::Auth>
namespace.  I was duplicating namespaces based on the Catalyst auth model and
this was a mistake.  See the commit message (I will be removing this note on
the next commit).

=cut

##############################################################################

=head3 login

  if ($c->login) {
     ....
  }

This method attempts to read C<username> and C<password> fields from a form
and authenticate them to a use with C<Kinetic::Util::Auth>.  If a user
successfully authenticates, sets the user object for later retrieval with 
C<< $c->user >> and returns true.  Otherwise, returns false.

=cut

# XXX Note that though this works, it is not yet implemented because the
# various Catalyst authentication classes are tightly coupled together and
# have their own expectations of what a user object should be allowed to do.
# This will be hooked up once we determine the best way of stripping those
# other objects.

sub login {
    my $c = shift;

    my ( $user, $pass ) = $c->_get_user_pass;
    if ( $user && ( my $user_object = Auth->authenticate( $user, $pass ) ) ) {
        $c->set_authenticated($user_object);
        $c->log->debug("Successfully authenticated user '$user'.")
          if $c->debug;
        return 1;
    }
    else {
        $c->log->debug(
            "Failed to authenticate user '$user'. Reason: 'Incorrect password'"
          )
          if $c->debug;
        return;
    }
}

##############################################################################

=begin private

=head3 _get_user_pass

  my ($user, $pass) = $c->_get_user_pass;

Returns the username and password found, if any.  Expects to have parameters
cunningly named C<username> and C<password>.  If either parameter is not
found, writes the problem to the error log and returns nothing.  The actual
error is not displayed to the end user (nor should it be).

=cut

sub _get_user_pass {
    my $c = shift;
    my ( $user, $pass );
    unless ( $user = $c->request->param("username") ) {
        $c->log->debug(
            "Can't login a user without a user object or user ID param");
        return;
    }

    unless ( $pass = $c->request->param("password") ) {
        $c->log->debug("Can't login a user without a password");
        return;
    }
    return ( $user, $pass );
}

##############################################################################

1;
__END__

=end private

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
