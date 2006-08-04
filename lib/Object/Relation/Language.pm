package Object::Relation::Language;

# $Id$

use strict;

our $VERSION = '0.11';

use encoding 'utf8';
binmode STDERR, ':utf8';

use base qw(Locale::Maketext);

=encoding utf8

=head1 Name

Object::Relation::Language - Object::Relation localization class

=head1 Synopsis

  # Add localization strings.
  package MyApp::Language::en;
  use Object::Relation::Language::en;
  Object::Relation::Language::en->add_to_lexicon(
    'Thingy' => 'Thingy',
    'Thingies' => 'Thingies',
  );

  # Use directly.
  use Object::Relation::Language;
  my $lang = Object::Relation::Language->get_handle('en_us');
  print $lang->maketext($msg);

=head1 Description

This class handles Object::Relation localization. To add this functionality, it
subclasses L<Locale::Maketext|Locale::Maketext> and adds a few other features.
One of these features is that failure to find a localization string will
result in the throwing of a Object::Relation::Exception::Fatal::Language
exception.

But since the Object::Relation framework is just that, a framework, this class
functions as the base class for the localization libraries of all Object::Relation
applications. Those applications can add their own localization strings
libraries via the C<add_to_lexicon()> method.

Those who wish to add new localizations to the Object::Relation framework should
consult the C<en> subclass for a full lexicon.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 add_to_lexicon

  Object::Relation::Language::en->add_to_lexicon(
    'Thingy' => 'Thingy',
    'Thingies' => 'Thingies',
  );

Adds new entries to the lexicon of the class. This method is intended to be
used by the localization libraries of Object::Relation applications, which will have
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
    require Object::Relation::Exceptions;
    Object::Relation::Exception::Fatal::Language->throw(
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
