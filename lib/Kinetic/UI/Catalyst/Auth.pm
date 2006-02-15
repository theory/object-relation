package Kinetic::UI::Catalyst::Auth;

# $Id: Cache.pm 2623 2006-02-14 03:24:40Z theory $

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

use Kinetic::Util::Config qw(:auth);
use Kinetic::Util::Exceptions qw/throw_unknown_class throw_unimplemented/;

use version;
our $VERSION = version->new('0.0.1');

BEGIN {
    eval 'require ' . AUTH_CLASS or throw_unknown_class [
        'I could not load the class "[_1]": [_2]',
        CACHE_CATALYST_CLASS,
        $@
    ];
}

=head1 NAME

Kinetic::UI::Catalyst::Auth - Authentication and authorization

=head1 SYNOPSIS

  my $auth        = Kinetic::UI::Catalyst::Auth->new;

=head1 DESCRIPTION

Returns an authorization object for managing users in Catalyst.

=head1 METHODS

=head2 new

  my $auth = Kinetic::UI::Catalyst::Auth->new;

Returns a new authorization object for the Kinetic::UI::Catalyst interface.

=cut

sub new {
    return bless { auth => AUTH_CLASS->new }, shift;
}

sub from_session {
    my ( $self, $c, $id ) = @_;

    return $id if ref $id;

    $self->get_user( $id );
}

sub get_user {
    my ( $self, $id ) = @_;

    return unless exists $self->{hash}{$id};

    my $user = $self->{hash}{$id};

    if ( ref $user ) {
        if ( Scalar::Util::blessed($user) ) {
            $user->store( $self );
            $user->id( $id );
            return $user;
        }
        elsif ( ref $user eq "HASH" ) {
            $user->{id} ||= $id;
            $user->{store} ||= $self;
            return bless $user, "Catalyst::Plugin::Authentication::User::Hash";
        }
        else {
            Catalyst::Exception->throw( "The user '$id' is a reference of type "
                  . ref($user)
                  . " but should be a HASH" );
        }
    }
    else {
        Catalyst::Exception->throw(
            "The user '$id' is has to be a hash reference or an object");
    }

    return $user;
}

sub user_supports {
    my $self = shift;
    # authorization
}

1;

=head1 Provided methods (called by other methods)

=over 4

=item new

=item from_session

=item get_user

=item user_supports

=back

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