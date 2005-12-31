package Kinetic::Util::Auth;

# $Id: Auth.pm 2265 2005-12-02 02:27:48Z curtis $

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
use Kinetic::Util::Config qw(:auth);
use Kinetic::Util::Exceptions qw(throw_config throw_auth throw_unimplemented);

# Load the subclasses.
throw_config [
    'The "[_1]" configuration section needs a "[_2]" setting',
    'auth',
    'protocol',
] unless AUTH_PROTOCOL;

for my $protocol (AUTH_PROTOCOL) {
    eval 'use ' . __PACKAGE__ . "::$protocol";
}

=head1 Name

Kinetic::Util::Auth - Kinetic authentication factory class

=head1 Synopsis

In F<kinetic.conf>:

  [auth]
  protocol: LDAP
  protocol: Kinetic

In Kinetic::Engine code:

  use aliased 'Kinetic::Util::Auth';
  my $user = Auth->authenticate($username, $password);

=head1 Description

This class handles authentication for all supported authentication protocols.
Support for protocols is implemented as subclasses that will be loaded by
Kinetic::Util::Auth based on F<kinetic.conf> settings. There may be any number
of supported protocols, and each will be evaluated for a call to
C<_authenticate()> in the order defined by the C<protocol> settings in the
C<auth> section of F<kinetic.conf>. Possible supported protcols include
Kinetic (TKP's internal authentication scheme), LDAP, SASL, or TrustApache.
Check for the supported subclasses.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $auth = Kinetic::Util::Auth->new;

Returns a Kinetic::Util::Auth object, which you might like to use as a
convenient shorthand to access the class methods. On the other hand, you can
just C<use aliased 'Kinetic::Util::Auth';> and then use C<Auth> to call the
class methods.

=cut

my $AUTH = bless [], __PACKAGE__;

sub new { $AUTH }

##############################################################################
# Class Methods.
##############################################################################

=head2 Class Methods

=head3 authenticate

  my $user = Kinetic::Util::Auth->authenticate($username, $password);

Authenticates the user identified by the username and password passed as
arguments. Throws an exception if the login fails and returns the user if the
login succeeds. Each protocol specified by the C<protocol> settings in
F<kinetic.conf> will be evaluated. Once one protocol has successfully
authenticated the user, no more protocols will be tried.

=cut

sub authenticate {
    my ( $self, $user, $pass ) = @_;
    for my $proto (AUTH_PROTOCOL) {
        my $subclass = __PACKAGE__ . "::$proto";
        if ( my $ret = $subclass->_authenticate( $user, $pass ) ) {
            return $ret;
        }
    }
    throw_auth 'Authentication failed';
}

##############################################################################
# Private Interface.
##############################################################################

=begin private

=head1 Private Interface

=head2 Private Instance Methods

=head3 _authenticate

  Kinetic::Util::Auth->_authenticate($username, $password);

This method must be implemented by all subclasses. It will be called by
authenticate() for each subclass configured in the C<protocol> settings in
F<kinetic.conf>. If it is not implemented, then this default version will
throw an exception. The method must return a
L<Kinetic::Party::User|Kinetic::Party::User> object upon success, and C<undef>
upon failure.

=cut

sub _authenticate {
    throw_unimplemented [
        '"[_1]" must be overridden in a subclass',
        '_authenticate',
    ];
}

1;
__END__

=end private

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
