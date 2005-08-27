package Kinetic::::Party::Person::User;

# $Id$

use strict;
use base qw(Kinetic::Party::Person);
use Kinetic::Util::Config qw(:user);
use Kinetic::Util::Exceptions qw(throw_password);
use Digest::MD5;

=head1 Name

Kinetic::::Party::Person::User - Kinetic user objects

=head1 Description

This class provides the basic interface for Kinetic user
objects.

=cut

BEGIN {
    my $cm = Kinetic::Meta->new(
        key         => 'user',
        name        => 'User',
        plural_name => 'Users',
    );

##############################################################################
# Constructors.
##############################################################################

=head1 Instance Interface

In addition to the interface inherited from
L<Kinetic::::|Kinetic::>,
L<Kinetic::::Party|Kinetic::::Party>, and
L<Kinetic::::Party::Person|Kinetic::::Party::Person>, this class
offers a number of its own attributes.

=head2 Accessors

=head3 username

  my $username = $person->username;
  $person->username($username);

The person's last name.

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
least the number of characters specified by the C<min_pass_len> of the
C<user> section of F<kinetic.conf> or an exception will be thrown.

B<Throws:>

=over

=item Fatal::Invalid

=back

=cut

    $cm->add_attribute(
        name        => 'password',
        label       => 'Password',
        type        => 'string',
        authz       => Class::Meta::SET,
        create      => Class::Meta::NONE,
        widget_meta => Kinetic::Meta::Widget->new(
            type => 'password',
            tip  => "The user's password"
        )
    );

    # So we define the accessor ourselves.
    sub password {
        my $self = shift;
        return unless @_;
        my $password = shift;
        throw_password ['Password must be as least [_1] characters',
                        USER_MIN_PASS_LEN]
          unless length $password > USER_MIN_PASS_LEN;
        # The password is okay. Stash it for changing in save().
        $self->{new_pass} = $password;
        $self->{password} =
          Digest::MD5::md5_hex('$8fFidf*34;,a(o};"?i8J<*/#1qE3 $*23kf3K4;-+3f'
                               . '#\'Qz-4feI3rfe}%:e'
                               . Digest::MD5::md5_hex($password));
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
    # Change the password in all password stores.

    # Return control.
    return $self;
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2005 Kineticode, Inc. See
L<Kinetic::License|Kinetic::License> for complete license terms and
conditions.

=cut
