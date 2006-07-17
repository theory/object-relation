package Kinetic::Store::Language;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use encoding 'utf8';
binmode STDERR, ':utf8';

use base qw(Locale::Maketext);

=encoding utf8

=head1 Name

Kinetic::Store::Language - Kinetic localization class

=head1 Synopsis

  # Add localization strings.
  package MyApp::Language::en;
  use Kinetic::Store::Language::en;
  Kinetic::Store::Language::en->add_to_lexicon(
    'Thingy' => 'Thingy',
    'Thingies' => 'Thingies',
  );

  # Use directly.
  use Kinetic::Store::Language;
  my $lang = Kinetic::Store::Language->get_handle('en_us');
  print $lang->maketext($msg);

=head1 Description

This class handles Kinetic localization. To add this functionality, it
subclasses L<Locale::Maketext|Locale::Maketext> and adds a few other features.
One of these features is that failure to find a localization string will
result in the throwing of a Kinetic::Store::Exception::Fatal::Language
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

  Kinetic::Store::Language::en->add_to_lexicon(
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
    require Kinetic::Store::Exceptions;
    Kinetic::Store::Exception::Fatal::Language->throw(
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

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
