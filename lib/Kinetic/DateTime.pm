package Kinetic::DateTime;

# $Id$

use strict;
use base 'DateTime';
use DateTime::TimeZone;

=head1 Name

Kinetic::DateTime - Kinetic DateTime objects

=head1 Synopsis

  my $dt = Kinetic::DateTime->new(
    year   => 1964,
    month  => 10,
    day    => 16,
    hour   => 16,
    minute => 12,
    second => 47,
  );

=head1 Description

This module subclasses the L<DateTime|DateTime> module to offer DateTime
objects to Kinetic applications. The only way in which it differs from
DateTime is that all new Kinetic::DateTime objects are in the "UTC" time zone
unless another time zone is specified.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $dt = Kinetic::DateTime->new(
    year   => 1964,
    month  => 10,
    day    => 16,
    hour   => 16,
    minute => 12,
    second => 47,
  );

Constructs and returns a new DateTime object. Unless a time zone is specified,
the time zone will be UTC.

=cut

my $utc = DateTime::TimeZone::UTC->new;

sub new { shift->SUPER::new(time_zone => $utc, @_) }

1;
__END__

##############################################################################

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This Library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
