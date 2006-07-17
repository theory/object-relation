package Kinetic::Store::Language::en_us;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use base 'Kinetic::Store::Language::en';
use encoding 'utf8';

=encoding utf8

=head1 Name

Kinetic::Store::Language::en_us - Kinetic US English localization

=head1 Description

This class handles Kinetic US English localization. See
L<Kinetic::Store::Language|Kinetic::Store::Language> for a complete description of the
Kinetic localization interface.

=cut

our %Lexicon = (
  # Classes.
  'Persons' => 'People',
);

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
