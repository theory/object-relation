package Kinetic::Language::en_us;

# $Id$

use strict;
use base 'Kinetic::Language';
use utf8;

=encoding utf8

=head1 Name

Kinetic::Language::en_us - Kinetic US English localization

=head1 Description

This class handles Kinetic US English localization. It is used internally by
Kinetic. See L<Kinetic::Language|Kinetic::Language> for a
complete description of the Kinetic localization interface.

=cut

our %Lexicon = (
  # Classes.
  'Persons' => 'People',
);

1;
__END__

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
