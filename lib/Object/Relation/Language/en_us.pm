package Object::Relation::Language::en_us;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.1.0');

use base 'Object::Relation::Language::en';
use encoding 'utf8';

=encoding utf8

=head1 Name

Object::Relation::Language::en_us - Object::Relation US English localization

=head1 Description

This class handles Object::Relation US English localization. See
L<Object::Relation::Language|Object::Relation::Language> for a complete description of the
Object::Relation localization interface.

=cut

our %Lexicon = (
  # Classes.
  'Persons' => 'People',
);

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@obj_relode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
