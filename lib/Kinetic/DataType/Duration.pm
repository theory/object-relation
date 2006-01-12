package Kinetic::DataType::Duration;

# $Id: Duration.pm 2488 2006-01-04 05:17:14Z theory $

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
use base 'DateTime::Duration';
use DateTime;
use Kinetic::Meta::Type;
use Kinetic::Util::Exceptions qw(throw_invalid);
use Kinetic::Util::Config qw(:store);

use overload
    'fallback' => 1,
    'cmp'      => \&_compare_overload,
    '<=>'      => \&_compare_overload,
;

use version;
our $VERSION = version->new('0.0.1');

=head1 Name

Kinetic::DataType::Duration - Kinetic Duration objects

=head1 Synopsis

  my $dt = Kinetic::DataType::Duration->new(
    years   => 2,
    months  => 10,
    days    => 16,
    hours   => 16,
    minutes => 12,
    seconds => 47,
  );

=head1 Description

This module creates the "duration" data type for use in Kinetic attributes. It
subclasses the L<DateTime::Duration|DateTime::Duration> module to offer
duration objects to Kinetic applications. It differs from DateTime::Duration
in overloading the comparison operators C<==> and C<eq> and in providing
C<raw()> and C<bake()> methods for serialization and deserialization to the
data store.

A note about the comparision overloading: It uses the C<compare()> method
inherited from L<DateTime::Duration|DateTime::Duration> and calculates the
differences against a DateTime object for the current Date and time. Thus, the
caveats the apply to C<comare()> apply also to the overloaded comparision
functionality of this module.

=cut

# Create the data type.
Kinetic::Meta::Type->add(
    key     => 'duration',
    name    => 'Duration',
    raw     => sub { ref $_[0] ? shift->raw   : shift },
    store_raw   => sub { ref $_[0] ? shift->store_raw : shift },
    bake    => sub { __PACKAGE__->bake(shift) },
    check   => __PACKAGE__,
);

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 bake

  my $duration = Kinetic::DataType::Duration->bake($string);

Parses an ISO-8601 Duration or PostgreSQL-formatted C<INTERVAL> string and
returns a Kinetic::DataType::Duration object.

=cut

sub bake {
    my ($class, $str) = @_;
    my ($year, $mon, $day, $sgn, $hour, $min, $sec, $frc, $ago);

    if (!defined $str) {
        throw_invalid [ 'No duration string passed to bake()' ];
    }

    elsif ($str eq '' || $str eq 'P' || $str eq 'ago') {
        # "0" is allowed by PostgreSQL.
        throw_invalid [ 'Invalid duration string: "[_1]"', $str ];
    }

    elsif ($str =~ /\AP/xms) {
        # ISO-8601 format: "PnYnMnDTnHnMnS".
        ($year, $mon, $day, $hour, $min, $sec, $frc) = $str =~ m{
            \A                              # Start of string
            (?:P)                           # Required starting "P"
            (?:([-+]?\d+)Y)?                # Years
            (?:(?<![TH])([-+]?\d+)M)?       # Months (no preceding T or H)
            (?:([-+]?\d+)D)?                # Days
            (?:(?:T)?([-+]?\d+)H)?          # Hours
            (?:(?:T)?([-+]?\d+)M)?          # Minutes
            (?:(?:T)?([-+]?\d+)?(\.\d+)?S)? # Seconds
            \z
        }xms or throw_invalid [ 'Invalid duration string: "[_1]"', $str ];
    }

    else {
        # Refactored from DateTime::Format::Pg (patch sent, too).
        ($year, $mon, $day, $sgn, $hour, $min, $sec, $frc, $ago) = $str =~ m{
            \A                                     # Start of string.
            (?:\@\s*)?                             # Optional leading @.
            (?:([-+]?\d+)\s+years?\s*)?            # years
            (?:([-+]?\d+)\s+mons?\s*)?             # months
            (?:([-+]?\d+)\s+days?\s*)?             # days
            (?:                                    # Start h/m/s
              # hours
              (?:([-+])?([012345]\d(?=:)|\d+(?=\s+hour))(?:\s+hours?)?\s*)?
              # minutes
              (?::?((?<=:)[012345]\d|\d+(?=\s+mins?))(?:\s+mins?)?\s*)?
              # seconds
              (?::?((?<=:)[012345]\d|\d+(?=\.|\s+secs?))?(\.\d+)?(?:\s+secs?)?\s*)?
            ?)                                     # End hh:mm:ss
            (ago)?                                 # Optional inversion
            \z                                     # End of string
        }xms or throw_invalid [ 'Invalid duration string: "[_1]"', $str ];

        # HH:MM:SS.FFFF share a single sign
        if ($sgn && $sgn eq '-') {
            no warnings 'uninitialized';
            $_ *= -1 for $hour, $min, $sec, $frc;
        }

    }

    # DateTime::Duration needs its parameters to be defined.
    $_ ||= 0 for $year, $mon, $day, $hour, $min, $sec, $frc;

    my $self = $class->SUPER::new(
        years       => $year,
        months      => $mon,
        days        => $day,
        hours       => $hour,
        minutes     => $min,
        seconds     => $sec,
        nanoseconds => $frc * DateTime::MAX_NANOSECONDS,
    );
    return $ago ? $self->inverse : $self;
}

##############################################################################

=head2 Instance Interface

=head3 raw

  my $iso_duration = $duration->raw;

Returns an ISO-8601-compliant duration string. This string takes the form
"PnYnMnDTnHnMnS". For example, "P3Y6M4DT12H30M0S" defines "a period of three
years, six months, four days, twelve hours, thirty minutes, and zero seconds".
See L<http://en.wikipedia.org/wiki/ISO_8601#Duration> for details and links to
the ISO-8601 spec.

The values of the duration parts will be normalized. For example, if a new
duration object is created with the C<minutes> parameter set to "90", the raw
representation will contain 1 hour and 30 minutes, instead.

=cut

sub raw {
    my ($self) = @_;

    my @units = $self->in_units(
        qw(years months days hours minutes seconds nanoseconds)
    );

    # Turn nanoseconds into the decimal form.
    $units[5] += sprintf '%f',
        ( delete( $units[6] ) / DateTime::MAX_NANOSECONDS );

    # Default to ISO-8601 format: "PnYnMnDTnHnMnS".
    return sprintf 'P%sY%sM%sDT%sH%sM%sS', @units;
}

##############################################################################

=head3 store_raw

  my $store_duration = $duration->store_raw;

Returns a duration string suitable for storage in the data store. The string
returned depends on the data store class. For the PostgreSQL store, the string
will be returned in a PostgreSQL-standard C<INTERVAL> string representation of
the duration object.

For other data stores, it will be stored in an non-standard ISO-8601 duration
string format with zero-padded parts. The number of years is padded to five
places, so no durations greater than 99,999 years or less than -9,999 years
are allowed for the non-PostgreSQL data stores.

  raw                Other                     PostgreSQL
  P0Y0M0DT1H0M0S     P00000Y00M00DT01H00M00S   0 years 0 mons 0 days 1 hours 0 mins 0 secs
  P0Y0M0DT-8H0M0S    P00000Y00M00DT-8H00M00S   0 years 0 mons 0 days 1 hours 0 mins 0.299 secs
  P9Y1M-12DT13H14M0S P00009Y01M-12DT13H14M00S  9 years 1 mons -12 days 13 hours 14 mins 0 secs

The reason for the special padded version of the ISO-8601 duration string is
to allow data stores without a C<duration> or C<interval> data type to do
proper string-based comparisons.

As with raw(), The values of the duration parts will be normalized.

=cut

sub store_raw {
    my $self = shift;
    my @units = $self->in_units(
        qw(years months days hours minutes seconds nanoseconds)
    );

    if (STORE_CLASS eq 'Kinetic::Store::DB::Pg') {
        # Use PostgreSQL's ugly format.
        $units[5] += delete($units[6]) / DateTime::MAX_NANOSECONDS;
        return sprintf '%s years %s mons %s days %s hours %s mins %s secs',
            @units
    }

    else {
        # Use 0-padded ISO-8601 format: "PnYnMnDTnHnMnS". Not strictly
        # compliant, but allows database comparisions of TEXT columns.
        if ($units[6]) {
            # Convert to the factional part.
            $units[6] = sprintf '%f', $units[6] / DateTime::MAX_NANOSECONDS;
            # Strip off leading 0.
            $units[6] =~ s/^0//;
            # Stripp off trailing 0s.
            $units[6] =~ s/0+$//;
        } else {
            # Make it empty.
            $units[6] = ''
        }
        return sprintf 'P%05sY%02sM%02sDT%02sH%02sM%02s%sS', @units;
    }
}

##############################################################################

=begin private

=head1 Private Interface

=head2 Private Instance Methods

=head3 _compare_overload

  if ($duration1 == $duration2) { print 'They are the same'; }

This instance method overloads string and numeric comparison to return true if
the two objects are the same and false if they are not. The comparision is
executed by the C<compare()> method inherited from DateTime::Duration, and the
calcuations are performed on a DateTime object with the date
"1970-01-01T00:00:00 UTC".

=cut

sub _compare_overload {
    my ($self, $other) = $_[2] ? @_[1, 0] : @_;
    $self->compare(
        $self,
        $other,
        DateTime->new( year => 1970, month => 1, day => 1)
    );
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

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
