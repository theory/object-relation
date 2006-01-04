package Kinetic::Util::Auth::Kinetic;

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
use aliased 'Kinetic::Party::User';
use Kinetic::Util::Exceptions qw(throw_auth);

=head1 Name

Kinetic::Util::Auth::Kinetic - Kinetic's internal authentication protocol

=head1 Synopsis

In F<kinetic.conf>:

  [auth]
  protocol: Kinetic

=head1 Description

This class provides the Kinetic authentication protocol. To use the Kinetic
authentication protocol, simply make sure that there is a C<protocol> setting
set to "Kinetic" in F<kinetic.conf>. See
L<Kinetic::Util::Auth|Kinetic::Util::Auth> for details.

=cut

##############################################################################

=begin private

=head1 Private Interface

=head2 Priate Class Methods

=head3 _authenticate

  my $user = Kinetic::Util::Auth->_authenticate($username, $password);

Looks up the L<Kinetic::Party::User|Kinetic::Party::User> object with the
specified username, and verifies the password by calling its
C<compare_password()> method.

=cut

sub _authenticate {
    my ($self, $username, $password) = @_;
    my $user = User->lookup( username => $username ) or return;
    return $user->compare_password($password);
}

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

