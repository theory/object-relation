package Kinetic::Util::Exceptions;

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
use Kinetic::Util::Context;

use Exception::Class(
    'Kinetic::Util::Exception' => {
        description => 'Kinetic Exception',
    },

    ##########################################################################
    # Unlocalized exceptions.
    ##########################################################################
    # XXX Perhaps there's a way to get Class::Meta and others to localize
    # exceptions?
    'Kinetic::Util::Exception::ExternalLib' => {
        description => 'External library exception',
        alias       => 'throw_exlib',
    },

    ##########################################################################
    # Fatal exceptions.
    ##########################################################################

    'Kinetic::Util::Exception::Fatal' => {
        description => 'Kinetic fatal exception',
        isa         => 'Kinetic::Util::Exception',
        alias       => 'throw_fatal',
    },

    'Kinetic::Util::Exception::Fatal::Invalid' => {
        description => 'Invalid data',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_invalid',
    },

    'Kinetic::Util::Exception::Fatal::ReadOnly' => {
        description => 'Assignment to read-only value',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_read_only',
    },

    'Kinetic::Util::Exception::Fatal::Language' => {
        description => 'Localization exception',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_lang',
    },

    'Kinetic::Util::Exception::Fatal::Stat' => {
        description => 'File status exception',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_stat',
    },

    'Kinetic::Util::Exception::Fatal::IO' => {
        description => 'File IO exception',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_io',
    },

    ##########################################################################
    # Non-fatal errors.
    ##########################################################################

    'Kinetic::Util::Exception::Error' => {
        description => 'Kinetic error',
        isa         => 'Kinetic::Util::Exception',
        alias       => 'throw_error',
    },

    'Kinetic::Util::Exception::Error::Password' => {
        description => 'Kinetic password error',
        isa         => 'Kinetic::Util::Exception::Error',
        alias       => 'throw_password',
    },


);

Kinetic::Util::Exception->Trace(1);

use Exporter::Tidy all => [
  qw(isa_kinetic_exception isa_exception throw_exlib throw_fatal throw_invalid
       throw_read_only throw_lang throw_stat throw_io throw_error
       throw_password)
];

##############################################################################

=head1 Name

Kinetic::Util::Exceptions - Kinetic exception object definitions

=head1 Synopsis

  use Kinetic::Util::Exceptions ':all';
  throw_fatal 'Whoops!';

  # The error is fully localizable.
  throw_fatal ['Unknown value "[_1]", 'foo'];

=head1 Description

This class defines Kinetic exception objects. It subclasses Exception::Class,
which provides a robust exception implementation. It extends Exception::Class
by requiring localizable error messages. All error messages must be
represented in the appropriate Kinetic::Util::Language lexicons.

There currently three major classes of exceptions:

=over

=item Kinetic::Util::Exception::Fatal

This class and its subclasses represent fatal, non-recoverable errors.
Exceptions of this sort are unexpected, and should be reported to an
administrator or to the Kinetic developers.

=item Kinetic::Util::Exception::Error

This clas and its subclasses represent non-fatal errors triggered by invalid
data. These can be used to let users know that the data they've entered is
invalid.

=item Kinetic::Util::Exception::ExternalLib

This class inherits from Exception::Class rather than from Kinetic::Util::Exception
so that it can be used for exceptions thrown by libraries not under direct
Kinetic control and therefore are not localizable.

=back

=cut

##############################################################################

=head1 Exception Classes

The exception classes generated by this module are as follows:

=over 4

=item Kinetic::Util::Exception

Kinetic exception base class. It generally should not be thrown, only its
subclasses.

=item Kinetic::Util::Exception::Fatal

Base class for fatal exceptions. Alias: C<throw_fatal>.

=item Kinetic::Util::Exception::Fatal::Invalid

Invalid data exception. Thrown when an invalid value is assigned to a Kinetic
class attribute. Alias: C<throw_invalid>.

=item Kinetic::Util::Exception::Error

Base class for error exceptions. These are non-fatal errors, generally
triggered by problems with data entered by users. Alias: C<throw_error>.

=back

=cut

##############################################################################

=head1 Interface

=head2 Functions

In addition to the functions that can be imported to throw the above
exceptions, there are a few other functions that may be imported into a client
class.

=head3 isa_kinetic_exception

  if (isa_kinetic_exception($@))
      print 'A Kinetic exception was thrown';
      print "...and it was fatal!' if isa_kinetic_exception($@, 'Fatal');
  }

This function returns true if the argument passed to it is a Kinetic
exception. The optional second argument can be used to test for a specific
Kinetic exception. If no such exception exists, an exception will be thrown.

=cut

sub isa_kinetic_exception {
    my ($err, $name) = @_;
    return unless $err;

    my $class = "Kinetic::Util::Exception";
    if ($name) {
        $class .= "::$name";
        throw_fatal qq{No such exception class "$class"}
          unless isa_exception($class);
    }

    return UNIVERSAL::isa($err, $class);
}

##############################################################################

=head3 isa_exception

  if (isa_exception($@)) {
      print "What we have here...is an exception object";
  }

This function returns true if the argument passed to it is an Exception::Class
object.

=cut

sub isa_exception {
    my $err = shift;
    return $err && UNIVERSAL::isa($err, 'Exception::Class::Base');
}

##############################################################################
# From here on in, we're modifying the behavior of Exception::Class::Base.

package Kinetic::Util::Exception;

sub new {
    my $class = shift;
    my %p =  @_ == 1 ? ( error => $_[0] ) : @_;
    # Localize the error message.
    $p{error} = Kinetic::Util::Context->language->maketext(
        ref $p{error} ? @{$p{error}} : $p{error}
    );
    $class->SUPER::new(%p);
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. <info@kineticode.com>

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
