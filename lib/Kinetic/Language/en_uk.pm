package Kinetic::Language::en_uk;

# $Id$

use strict;
use base 'Kinetic::Language::en';
use encoding 'utf8';

=encoding utf8

=head1 Name

Kinetic::Language::en_uk - Kinetic UK English localization

=head1 Description

This class handles Kinetic UK English localization. See
L<Kinetic::Language|Kinetic::Language> for a complete description of the
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

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item L<Kinetic::Language|Kinetic::Language>

The Kinetic localization class.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This Library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
