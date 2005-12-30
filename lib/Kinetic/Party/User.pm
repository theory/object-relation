package Kinetic::Party::User;

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

use base qw(Kinetic::Party);
use Kinetic::Party::Person;
use Kinetic::Util::Config qw(:user);
use Kinetic::Util::Exceptions qw(throw_password throw_attribute);
use Digest::MD5;

=head1 Name

Kinetic::Party::User - Kinetic user objects

=head1 Description

This class extends L<Kinetic::Party::Person|Kinetic::Party::Person> to
implement Kinetic user objects.

=cut

BEGIN {
    my $cm = Kinetic::Meta->new(
        key         => 'usr',
        name        => 'User',
        plural_name => 'Users',
        extends     => 'person',
    );

##############################################################################
# Instance Interface.
##############################################################################

=head1 Instance Interface

In addition to the interface inherited from L<Kinetic::|Kinetic>,
L<Kinetic::Party|Kinetic::Party>, and extended from
L<Kinetic::Party::Person|Kinetic::Party::Person>, this class offers a number
of its own attributes.

=head2 Accessors

=head3 username

  my $username = $person->username;
  $person->username($username);

The user's username. This attribute is unique for all active and inactive
users.


=cut

    $cm->add_attribute(
        name        => 'username',
        label       => 'Username',
        required    => 1,
        unique      => 1,
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

    # Start with the public attribute. Not persistent.
    $cm->add_attribute(
        name        => 'password',
        label       => 'Password',
        type        => 'string',
        required    => 1,
        authz       => Class::Meta::WRITE,
        create      => Class::Meta::NONE,
        persistent  => 0,
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'password',
            tip  => q{The user's password}
        )
    );

    # Add the attribute that actually gets stored.
    $cm->add_attribute(
        name        => '_password',
        type        => 'string',
        required    => 1,
        authz       => Class::Meta::RDWR,
        view        => Class::Meta::TRUSTED,
    );

    # Add the attribute used for updating other authentication schemes.
    $cm->add_attribute(
        name       => '_new_pass',
        type       => 'string',
        authz      => Class::Meta::RDWR,
        view       => Class::Meta::PRIVATE,
        persistent => 0,
    );

    # So we define the accessor ourselves.
    sub password {
        my $self = shift;
        throw_attribute [
            'Attribute "[_1]" is write-only',
            'password',
        ] unless @_;

        my $password = shift;
        throw_password [
            'Password must be as least [_1] characters',
            USER_MIN_PASS_LEN
        ] unless length $password >= USER_MIN_PASS_LEN;

        # The password is okay. Stash it for changing in save().
        $self->_new_pass($password);
        return $self->_password(_hash($password));
    }

##############################################################################

=head2 Instance Methods

=head3 compare_password

  $user->compare_password($password);

Compares the password passed as the sole argument to the user's current
password. Returns the user object if the passwords are the same, and C<undef>
if they are not.

=cut

    $cm->add_method(
        name => 'compare_password',
        code => sub {
            my $self = shift;
            return $self->_password eq _hash(shift) ? $self : undef;
        },
    );

##############################################################################

=begin private

=head2 Private Instance Methods

=head3 _save_prep

  $user->_save_prep;

Overrides the parent C<_save_prep()> method in order to save changed passwords
to all appropriate password stores.

B<Throws:>

=over 4

=item Error::Undef

=item Error::Invalid

=item Exception::DA

=back

=cut

    $cm->build;
} # BEGIN

sub _save_prep {
    my $self = shift;
    $self->SUPER::_save_prep(@_);
    my $new_pass = $self->_new_pass or return $self;
    $self->_new_pass(undef);
    # XXX Change the password in all password stores.

    # Return control.
    return $self;
}

##############################################################################

=head2 Private Functions

  my $hash = _hash($string);

Returns a hashed version of $string. Used for hasing passwords.

=cut

sub _hash {
    # XXX Switch to a different hashing digest?
    Digest::MD5::md5_hex(
        '$8fFidf*34;,a(o};"?i8J<*/#1qE3 $*23kf3K4;-+3f#\'Qz-4feI3rfe}%:e'
        . Digest::MD5::md5_hex(shift)
    );
}

1;
__END__

##############################################################################

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
