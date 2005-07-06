package Kinetic::DateTime;

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
use base 'DateTime';
use DateTime::TimeZone;
use DateTime::Format::Strptime;

use Exporter::Tidy other => ['is_iso8601'];

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

##############################################################################

=head3 new_from_iso8601

  my $dt = Kinetic::DateTime->new_from_iso8601('1964-10-16T16:12:47.0');

Same as C<new> but takes an iso8601 date string as the argument.

=cut

my $utc       = DateTime::TimeZone::UTC->new;
#my $formatter = DateTime::Format::Strptime->new(pattern => '%Y-%m-%dT%H:%M:%S.%1N%z');
my $formatter = DateTime::Format::Strptime->new(pattern => '%Y-%m-%dT%H:%M:%S');
sub new { 
    my $class = shift;
    $class->SUPER::new(
        time_zone => $utc, 
        formatter => $formatter,
        @_
    );
}

sub new_from_iso8601 {
    my ($class, $iso8601_date_string) = @_;
    return unless $iso8601_date_string;
    my $args = $class->parse_iso8601_date($iso8601_date_string);
    return $class->new(%$args);
};

##############################################################################

=head3 parse_iso8601_date

  my $date_href = $date->parse_iso8601_date;

Given an ISO8601 date string, returns a hashref with the date parts as values
to the keys.  Keys are:

    year 
    month 
    day 
    hour 
    minute 
    second 
    nanosecond
    
=cut

my $ISO8601_TEMPLATE =  'a4 x a2 x a2 x a2 x a2 x a2 a*';
sub parse_iso8601_date {
    my ($class, $iso8601_date_string) = @_;
    # It turns out that unpack() is faster than using a Regex. See
    # http://www.justatheory.com/computers/programming/perl/pack_vs_regex.html
    my %args;
    @args{qw(year month day hour minute second nanosecond)}
      = unpack $ISO8601_TEMPLATE, $iso8601_date_string;
    {
        no warnings;
        $args{nanosecond} *= 1.0E9;
    }
    return \%args;
}

=head3 is_iso8601

  use Kinetic::DateTime qw/is_iso8601/;
  if (is_iso8601('1964-10-16T16:12:47.0')) {
    ...
  }

Returns a true or false value depending upon whether or not the supplied
string matches an ISO 8601 datetime string.  This is a function, not a 
method.

Nanoseconds are optional.  Currently ignores timezone.

=cut

sub is_iso8601 {
    my $date = shift;
    return $date =~ /^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?$/;
}    

##############################################################################

=head3 raw

  my $date_string = $date->raw;

Return the ISO8601 value of the datetime object.

=cut

sub raw {
    my $self = shift;
    return "$self";
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2005 Kineticode, Inc. <info@kineticode.com>

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
