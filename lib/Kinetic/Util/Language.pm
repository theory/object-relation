package Kinetic::Util::Language;

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

use encoding 'utf8';
binmode STDERR, ':utf8';

use base qw(Locale::Maketext);

=encoding utf8

=head1 Name

Kinetic::Util::Language - Kinetic localization class

=head1 Synopsis

  # Add localization strings.
  package MyApp::Language::en;
  use Kinetic::Util::Language::en;
  Kinetic::Util::Language::en->add_to_lexicon(
    'Thingy' => 'Thingy',
    'Thingies' => 'Thingies',
  );

  # Use directly.
  use Kinetic::Util::Language;
  my $lang = Kinetic::Util::Language->get_handle('en_us');
  print $lang->maketext($msg);

=head1 Description

This class handles Kinetic localization. To add this functionality, it
subclasses L<Locale::Maketext|Locale::Maketext> and adds a few other features.
One of these features is that failure to find a localization string will
result in the throwing of a Kinetic::Util::Exception::Fatal::Language
exception.

But since the Kinetic framework is just that, a framework, this class
functions as the base class for the localization libraries of all Kinetic
applications. Those applications can add their own localization strings
libraries via the C<add_to_lexicon()> method.

Those who wish to add new localizations to the Kinetic framework should
consult the C<en> subclass for a full lexicon.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 add_to_lexicon

  Kinetic::Util::Language::en->add_to_lexicon(
    'Thingy' => 'Thingy',
    'Thingies' => 'Thingies',
  );

Adds new entries to the lexicon of the class. This method is intended to be
used by the localization libraries of Kinetic applications, which will have
their own strings that need localizing.

=cut

sub add_to_lexicon {
    no strict 'refs';
    my $lex = \%{shift() . "::Lexicon"};
    while (my $k = shift) {
        $lex->{$k} = shift;
    }
}

##############################################################################
# This is the default lexicon from which all other languages inherit.
##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 init

This method is used internally by Locale::Maketext to set up failed
localization key lookups to throw exceptions.

=cut

my $fail_with = sub {
    my ($lang, $key) = @_;
    require Kinetic::Util::Exceptions;
    Kinetic::Util::Exception::Fatal::Language->throw(
        ['Localization for "[_1]" not found', $key]
    );
};

sub init {
    my $handle = shift;
    $handle->SUPER::init(@_);
    $handle->fail_with($fail_with);
}

1;
__END__

##############################################################################

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
