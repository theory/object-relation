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

use version;
our $VERSION = version->new('0.0.1');

use Kinetic::Util::Context;

=head1 Name

Kinetic::Util::Exceptions - Kinetic exception object definitions

=head1 Synopsis

  use Kinetic::Util::Exceptions ':all';
  throw_fatal 'Whoops!';

  # The error is fully localizable.
  throw_fatal ['Unknown value "[_1]"', 'foo'];

=head1 Description

This class defines Kinetic exception objects. It subclasses Exception::Class,
which provides a robust exception implementation. It extends Exception::Class
by requiring localizable error messages. All error messages must be represented
in the appropriate Kinetic::Util::Language lexicons.

There currently four major classes of exceptions:

=over

=item Kinetic::Util::Exception::Fatal

This class and its subclasses represent fatal, non-recoverable errors.
Exceptions of this sort are unexpected, and should be reported to an
administrator or to the Kinetic developers.

=item Kinetic::Util::Exception::Error

This class and its subclasses represent non-fatal errors triggered by invalid
data. These can be used to let users know that the data they've entered is
invalid.

=item Kinetic::Util::Exception::ExternalLib

This class will never has its error message localized. This is so that it can
be thrown by libraries not under direct Kinetic control and therefore are not
localizable. This class is also used for the global C<$SIG{__DIE__}> and
C<$SIG{__WARN__}> handlers, so that error messages and warnings always include
a nicely formatted stack trace.

=item Kinetic::Util::Exception::DBI

This class is used solely for handling exceptions thrown by L<DBI|DBI>. You
should never need to access it directly.

=back

=cut

##############################################################################

=head1 Exception Classes

The exception classes generated by this module are as follows:

=over 4

=item Kinetic::Util::Exception

Kinetic exception base class. It generally should not be thrown, only its
subclasses.

=cut

use Exception::Class(
    'Kinetic::Util::Exception' => {
        description => 'Kinetic Exception',
    }
);

##############################################################################
# Fatal exceptions.
##############################################################################

=item Kinetic::Util::Exception::Fatal

Base class for fatal exceptions. Alias: C<throw_fatal>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal' => {
        description => 'Kinetic fatal exception',
        isa         => 'Kinetic::Util::Exception',
        alias       => 'throw_fatal',
    },
);

=item Kinetic::Util::Exception::Fatal::Invalid

Invalid data exception. Thrown when an invalid value is assigned to a Kinetic
class attribute. Alias: C<throw_invalid>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::Invalid' => {
        description => 'Invalid data',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_invalid',
    },
);

=item Kinetic::Util::Exception::Fatal::ReadOnly

ReadOnly exception. Thrown when an someone attempts to assign a value to a
read-only attribute. Alias: C<throw_read_only>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::ReadOnly' => {
        description => 'Assignment to read-only value',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_read_only',
    },
);

=item Kinetic::Util::Exception::Fatal::Language

Localization exception. Thrown if an error is encountered while attempting to
localize a string. Alias: C<throw_lang>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::Language' => {
        description => 'Localization exception',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_lang',
    },
);

=item Kinetic::Util::Exception::Fatal::Stat

File status exception. Thrown if an error is encountered while attempting to
stat a file. Alias: C<throw_stat>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::Stat' => {
        description => 'File status exception',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_stat',
    },
);

=item Kinetic::Util::Exception::Fatal::IO

IO exception. Thrown if an error is encountered while attempting to read or
write to a file. Alias: C<throw_io>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::IO' => {
        description => 'File IO exception',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_io',
    },
);

=item Kinetic::Util::Exception::Fatal::Unimplemented

Unimplemented exception. Thrown if a feature has not yet been implemented or
must be overridden in a subclass. Alias: C<throw_unimplemented>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::Unimplemented' => {
        description => 'Unimplemented exception',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_unimplemented',
    },
);

=item Kinetic::Util::Exception::Fatal::RequiredArguments

Missing arguments exception. Thrown if required arguments to a method are not
present.  Alias: C<throw_required>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::RequiredArguments' => {
        description => 'Missing arguments to method call',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_required',
    },
);

=item Kinetic::Util::Exception::Fatal::NotFound

Object Not Found exception.  Thrown if something searched for is not found.
Usually this is for objects in data stores, but also might be used for
anything that is being looked for (such as a file).


Alias: C<throw_not_found>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::NotFound' => {
        description => 'Object not found exception',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_not_found',
    },
);

=item Kinetic::Util::Exception::Fatal::Unsupported

Unsupported feature exception. Thrown if code attempts to use an unsupported
feature.  Alias: C<throw_unsupported>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::Unsupported' => {
        description => 'Unsupported feature requested.',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_unsupported',
    },
);

=item Kinetic::Util::Exception::Fatal::XML

XML parse exception. Thrown if a problem is found parsing XML.
Alias: C<throw_xml>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::XML' => {
        description => 'Error parsing XML',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_xml',
    },
);

=item Kinetic::Util::Exception::Fatal::InvalidClass

Invalid class exception. Thrown if an incorrect class is encountered.
Alias: C<throw_invalid_class>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::InvalidClass' => {
        description => 'Invalid class',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_invalid_class',
    },
);

=item Kinetic::Util::Exception::Fatal::UnknownClass

Unknown class exception. Thrown if an unknown class is encountered.
Alias: C<throw_unknown_class>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::UnknownClass' => {
        description => 'Invalid class',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_unknown_class',
    },
);

=item Kinetic::Util::Exception::Fatal::Attribute

Kinetic attribute exception. Thrown if a Kinetic attribute is used
incorrectly, such as "unknown attributes" or trying to use a non-unique
attribute where a unique attribute would be used. Alias: C<throw_attribute>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::Attribute' => {
        description => 'Improper use of attribute',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_attribute',
    },
);

=item Kinetic::Util::Exception::Fatal::Search

Store search exception. Thrown if data store cannot figure out how to respond
to a search request.  Alias: C<throw_search>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::Search' => {
        description => 'Bad search request',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'throw_search',
    },
);

=item Kinetic::Util::Exception::Fatal::Panic

Panic exception. This internal exception should (theoretically) never be
thrown.  It only occurs if the internal state of something has reached a point
that cannot occur.  For example, an "ANY" search in a store class can only
occur if the values searched on are contained in an array reference.  If an ANY
search occurs and the values are not an array reference, a panic is thrown.
Alias: C<panic>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Fatal::Panic' => {
        description => 'Invalid class',
        isa         => 'Kinetic::Util::Exception::Fatal',
        alias       => 'panic',
    },
);

##############################################################################
# Non-fatal errors.
##############################################################################

=item Kinetic::Util::Exception::Error

Base class for error exceptions. These are non-fatal errors, generally
triggered by problems with data entered by users. Alias: C<throw_error>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Error' => {
        description => 'Kinetic error',
        isa         => 'Kinetic::Util::Exception',
        alias       => 'throw_error',
    },
);

=item Kinetic::Util::Exception::Error::Password

Password error. Thrown for authentication failures. This exception class may or
may not be retained. Alias: C<throw_password>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::Error::Password' => {
        description => 'Kinetic password error',
        isa         => 'Kinetic::Util::Exception::Error',
        alias       => 'throw_password',
    },
);

##############################################################################
# Unlocalized exceptions.
##############################################################################

=item Kinetic::Util::Exception::ExternalLib

Class for exceptions thrown external to Kinetic code. Exceptions of this class
behave just like any other Kinetic exception objects, except that error
messages are not localized. Alias: C<throw_exlib>.

=cut

use Exception::Class(
    'Kinetic::Util::Exception::ExternalLib' => {
        description => 'External library exception',
        isa         => 'Kinetic::Util::Exception',
        alias       => 'throw_exlib',
    },
);

##############################################################################

use Exporter::Tidy all => [
  qw(
    panic isa_kinetic_exception isa_exception throw_exlib throw_fatal
    throw_invalid throw_read_only throw_lang throw_stat throw_io throw_error
    throw_password throw_required throw_xml throw_unknown_class
    throw_invalid_class throw_not_found throw_unsupported throw_unimplemented
    throw_search throw_attribute sig_handlers
  )
];

##############################################################################

=back

=cut

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

This function returns true if the argument passed to it is a Kinetic exception.
The optional second argument can be used to test for a specific Kinetic
exception. If no such exception exists, an exception will be thrown.

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

=head3 sig_handlers

  sig_handlers(0);

This function accepts a boolean value. If true, it turns on stack traces via
the WARN and DIE signal handlers. If false, it disables them. If called
without arguments, it merely returns a boolean value indicating whether or not
the signal handlers are enabled.

=cut

my $SIG_DIE = sub {
    my $err = shift;
    $err->rethrow if UNIVERSAL::can($err, 'rethrow');
    Kinetic::Util::Exception::ExternalLib->throw($err);
};

my $SIG_WARN = sub {
    print STDERR Kinetic::Util::Exception::ExternalLib->new(shift)->as_string;
};

my $HANDLERS = 1;
sub sig_handlers {
    _set_handlers(shift) if @_;
    return $HANDLERS;
}

sub _set_handlers {
    $HANDLERS = shift;
    if ($HANDLERS) {
        $SIG{__DIE__}  = $SIG_DIE;
        $SIG{__WARN__} = $SIG_WARN;
    }
    else {
        local $^W;
        undef $SIG{__DIE__};
        undef $SIG{__WARN__};
    }
}

# Always use exception objects for exceptions and warnings.
# XXX I can't recall how we said we would deal with this
sig_handlers(1); # turn on signal handlers by default
##############################################################################
# From here on in, we're modifying the behavior of Exception::Class::Base.

package Kinetic::Util::Exception;

=head2 Constructors

=head3 new

  my $err = Kinetic::Util::Exception->new("Whoops!");
  my $err = Kinetic::Util::Exception->new(error => 'Whoops!');
  my $err = Kinetic::Util::Exception->new(['Unknown value "[_1]"', 'foo']);
  my $err = Kinetic::Util::Exception->new(
      error => ['Unknown value "[_1]"', 'foo']
  );

Creates and returns a new exception object. Use this method with C<die> to
throw exceptions yourself, or if you don't want to import any C<throw_>
functions into your namespace. Otherwise, a C<throw_> function is generally the
preferred way to throw an exception. Besides, it requires less typting!

The base class supports only a single parameter, C<error>, for the exception
error message. If only a single argument is passed to C<new()>, it is assumed
to be the C<error> parameter. Other exception classes may support other
parameters; consult their <descriptions|"Exception Classes"> for details. All
C<throw_> functions for the exception subclasses support the parameters that
correspond to their respective classes.

=cut

sub new {
    my $class = shift;
    my %p =  @_ == 1 ? ( error => $_[0] ) : @_;

    # Localize the error message.
    $p{error} = Kinetic::Util::Context->language->maketext(
        ref $p{error} ? @{$p{error}} : $p{error}
    );
    $class->SUPER::new(%p);
}

##############################################################################

=head2 Instance Methods

=head3 as_string

  my $string $err->as_string;

Returns a stringified representation of the exception, which includes the full
error message and the stack trace. The method overrides stringification
(double-quoted string context), so its return value is output whenever an
exception object is printed.

We override the base class version of this method in order to provide a nicer,
more legible stack trace, rather than the default Carp-style trace.

=cut

sub as_string {
    my $self = shift;
    return sprintf("%s\n%s\n", $self->full_message, $self->trace_as_text);
}

##############################################################################

=head3 trace_as_text

  my $trace = $err->trace_as_text;

Returns a stringified representation of the stack trace for the exception
object. Used by C<as_string()> to pretty-print the stack trace.

=cut

sub trace_as_text {
    my $self = shift;
    return join "\n", map {
        sprintf("[%s:%d]", $_->filename, $_->line);
    } $self->_filtered_frames;
}

##############################################################################

=begin private

=head2 Private Instance Methods

=head3 _filtered_frames

  my @trace_frames = $err->_filtered_frames;

Returns a list of stack trace frames, filtering out those that derive from
Exception::Class::Base, Kinetic::Util::Exception::__ANON__ (the C<throw_>
fucnctions), and C<(eval)>. Used by C<trace_as_text()>.

=cut

sub _filtered_frames {
    my $self = shift;
    my %ignore_subs = map { $_ => 1 } qw{
         (eval)
         Exception::Class::Base::throw
         Kinetic::Util::Exception::__ANON__
    };

    my $faultregex = qr{/Kinetic/Util/Exception\.pm|/dev/null};
    my @frames;
    my $trace = $self->trace;
    while (my $frame = $trace->next_frame) {
        push @frames, $frame
          unless $frame->filename =~ $faultregex
          || $ignore_subs{$frame->subroutine};
    }

    unless (@frames) {
        @frames = grep { $_->filename !~ $faultregex } $trace->frames;
    }
    return @frames;
}

# Make Exception::Class::DBI inherit from this class, too.
package Kinetic::Util::Exception::DBI;
use base qw(Kinetic::Util::Exception::Fatal);
use Exception::Class::DBI;

# XXX Fool class that shouldn't have localized messages into not calling our
# new() method. I'd rather not reference Exception::Class::Base::new directly
# here, but SUPER::SUPER doesn't quite to the job. Schwern says he'd be willing
# to write a module to make SUPER::SUPER work...

sub new { Exception::Class::Base::new(@_) }
sub Kinetic::Util::Exception::ExternalLib::new { Exception::Class::Base::new(@_) }

sub handler { Exception::Class::DBI::handler(@_) }
sub full_message {
    my $self = shift;
    return $self->SUPER::full_message unless $self->can('statement');
    return $self->SUPER::full_message
        . ' [for Statement "'
        . $self->statement . '"]';
}

# XXX Yes, this is ugly, but it's the simplest way to do it, because
# Exception:Class::DBI and its subclasses are not really subclassable.
unshift @Exception::Class::DBI::ISA, __PACKAGE__;

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
