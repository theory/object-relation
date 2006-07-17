package Kinetic::Util::Language::en_uk;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use base 'Kinetic::Util::Language::en';
use encoding 'utf8';

=encoding utf8

=head1 Name

Kinetic::Util::Language::en_uk - Kinetic UK English localization

=head1 Description

This class handles Kinetic UK English localization. See
L<Kinetic::Util::Language|Kinetic::Util::Language> for a complete description of the
Kinetic localization interface.

=cut

our %Lexicon = (
  # Attribute labels and tips.
  'Last Name' => 'Surname',
  "The person's last name",
  "The person's surname",

  'First Name', => 'Given Name',
  "The person's first name",
  "The person's given name",
);

1;
__END__

##############################################################################

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
