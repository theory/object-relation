package Kinetic::Party::Person::User;

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

use version;
our $VERSION = version->new('0.0.1');

use base qw(Kinetic::Party::Person);
use Kinetic::Util::Config qw(:user);
use Kinetic::Util::Exceptions qw(throw_password);
use Digest::MD5;

=head1 Name

Kinetic::Party::Person::User - Kinetic user objects

=head1 Description

This class provides the basic interface for Kinetic user objects.

=cut

BEGIN {
    my $cm = Kinetic::Meta->new(
        key         => 'usr',
        name        => 'User',
        plural_name => 'Users',
    );

##############################################################################
# Constructors.
##############################################################################

=head1 Instance Interface

In addition to the interface inherited from L<Kinetic::|Kinetic>,
L<Kinetic::Party|Kinetic::Party>, and
L<Kinetic::Party::Person|Kinetic::Party::Person>, this class offers a number
of its own attributes.

=head2 Accessors

=head3 username

  my $username = $person->username;
  $person->username($username);

The user's username, which can be used to log into the system.

=cut

    $cm->add_attribute(
        name        => 'username',
        label       => 'Username',
        type        => 'string',
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => "The user's username"
        )
    );

##############################################################################

=head3 password

  $person->password($password);

The person's password. This attribute is write-only. The password must have at
least the number of characters specified by the C<min_pass_len> of the C<user>
section of F<kinetic.conf> or an exception will be thrown.

B<Throws:>

=over

=item Fatal::Invalid

=back

=cut

    $cm->add_attribute(
        name        => 'password',
        label       => 'Password',
        type        => 'string',
        authz       => Class::Meta::READ,
        create      => Class::Meta::NONE,
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'password',
            tip  => "The user's password"
        )
    );

    # So we define the accessor ourselves.
    sub password {
        my $self = shift;
        unless (@_) {
            # XXX This isn't the cleanest way to handle things, but it works
            # for now. Need to have a way for Kinetic::Store to get at the
            # password value for, erm, storing.
            return unless caller->isa('Kinetic::Store');
            return $self->{password};
        }

        my $password = shift;
        throw_password [
            'Password must be as least [_1] characters',
            USER_MIN_PASS_LEN
        ] unless length $password > USER_MIN_PASS_LEN;

        # The password is okay. Stash it for changing in save().
        $self->{new_pass} = $password;

        # XXX Switch to a different digest?
        $self->{password} = Digest::MD5::md5_hex(
            '$8fFidf*34;,a(o};"?i8J<*/#1qE3 $*23kf3K4;-+3f#\'Qz-4feI3rfe}%:e'
            . Digest::MD5::md5_hex($password)
        );
        return $self;
    }

##############################################################################

=head2 Instance Methods

=head3 session

=head3 authenticate

=head3 login

=head3 logout

=head3 is_logged_in

=cut

##############################################################################

=head3 save

  $user->save;

Overrides the parent C<save()> method in order to save changed passwords to
all appropriate password stores.

B<Throws:>

=over 4

=item Error::Undef

=item Error::Invalid

=item Exception::DA

=back

=cut

    $cm->build;
} # BEGIN

sub save {
    my $self = shift;
    $self->SUPER::save(@_);
    my $new_pass = $self->{new_pass} or return $self;
    # XXX Change the password in all password stores.

    # Return control.
    return $self;
}

1;
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
