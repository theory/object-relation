package Object::Relation::Language::en_uk;

# $Id$

use strict;

our $VERSION = '0.11';

use base 'Object::Relation::Language::en';
use encoding 'utf8';

=encoding utf8

=head1 Name

Object::Relation::Language::en_uk - Object::Relation UK English localization

=head1 Description

This class handles Object::Relation UK English localization. See
L<Object::Relation::Language|Object::Relation::Language> for a complete description of the
Object::Relation localization interface.

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

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
