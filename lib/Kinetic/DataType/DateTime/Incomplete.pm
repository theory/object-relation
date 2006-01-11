package Kinetic::DataType::DateTime::Incomplete;

# $Id: DateTime.pm 1253 2005-02-11 02:35:40Z theory $

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

use version;
our $VERSION = version->new('0.0.1');

use base 'DateTime::Incomplete';
use Kinetic::DataType::DateTime;
use DateTime::TimeZone;
use Exporter::Tidy other => ['is_incomplete_iso8601'];

=head1 Name

Kinetic::DataType::DateTime::Incomplete - Incomplete Kinetic DateTime objects

=head1 Synopsis

  my $dt = Kinetic::DataType::DateTime::Incomplete->new(
    month  => 10,
    day    => 16,
  );

=head1 Description

This module subclasses the L<DateTime::Incomplete|DateTime::Incomplete> module
to offer DateTime::Incomplete objects to Kinetic applications. The only way in
which it differs from DateTime::Incomplete is that all new Kinetic::DataType::DateTime
objects are in the "UTC" time zone unless another time zone is specified and it
knows to properly stringify itself when accessed by
L<Kinetic::Store|Kinetic::Store>.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $dt = Kinetic::DataType::DateTime::Incomplete->new(
    month  => 10,
    day    => 16,
  );

Constructs and returns a new Kinetic::DataType::DateTime::Incomplete object. Unless a
time zone is specified, the time zone will be UTC.

=cut

my $utc = DateTime::TimeZone::UTC->new;

sub new { shift->SUPER::new(time_zone => $utc, @_) }

##############################################################################

=head3 bake

  my $dt = Kinetic::DataType::DateTime->bake('1964-10-16T16:12:47.0');

Same as C<new> but takes an incomplete iso8601 date string as the argument.

=cut

sub bake {
    my ($class, $iso8601_date_string) = @_;
    return unless $iso8601_date_string;
    my $args = Kinetic::DataType::DateTime->parse_iso8601_date($iso8601_date_string);
    my %args;
    while (my ($key, $value) = each %$args) {
        next if $value =~ /x/;
        $args{$key} = $value;
    }
    return $class->new(%args);
};

##############################################################################

=head3 contiguous

  if ($date->contiguous) { ... }

This method returns a true or false value depending upon whether or not all of
the date components are contiguous.  For example, "month, day and hour" are
contiguous, but "month, day, and minute" are not.

This method will return false if none of the date components are defined.

=cut

my @COMPONENTS = qw/
    year
    month
    day
    hour
    minute
    second
/;

sub contiguous {
    my $self  = shift;
    my $count = 0;
    my @indexes;
    foreach my $index (0 .. $#COMPONENTS) {
        my $component = $COMPONENTS[$index];
        if (defined $self->$component) {
            $count++;
            push @indexes => $index;
        }
    }
    return unless $count; # no components will be considered non-contiguous
    return (1 + ($indexes[-1] - $indexes[0])) == $count;
}

=head3 is_incomplete_iso8601

  use Kinetic::DataType::DateTime::Incomplete qw/is_incomplete_iso8601/;
  if (is_incomplete_iso8601('1964-xx-16T16:12:47.0')) {
    ...
  }

Returns a true or false value depending upon whether or not the supplied string
matches an incomplete ISO 8601 datetime string.  This is a function, not a
method.

If a particular date segment is not present, it may be replaced with 'Xs'.
However, the complete date segment must be replaced.  For example, you can
replace the year 1968 with 'xxxx', but not '19xx'.  If nanoseconds are not
present, omit them.

Currently ignores timezone.

It won't match:

 1964-10-16T17:12:47.0 # the date is not incomplete
 1964-10-16 17:12:47.0 # missing the "T"
 xx64-10-16T17:12:47.0 # year segment only partially replaced

Valid incomplete datetime strings:

 xxxx-10-16T17:12:47.0 
 1964-xx-16T17:12:47.0 
 1964-xx-xxT17:xx:xx.0 
 1964-10-16T17:12:xx

=cut

sub is_incomplete_iso8601 {
    my $date = shift || return;
    return unless $date =~ /x/; # must have at least one incomplete date segment
    return $date =~ /^
        (?:\d\d\d\d|xxxx)  # year
        -
        (?:[0123]\d|xx)    # month
        -
        (?:[0123]\d|xx)    # day
        T
        (?:[012]\d|xx)     # hour
        :
        (?:[012345]\d|xx)  # minute
        :
        (?:[012345]\d|xx)  # seconds
        (?:\.\d+)?         # optional nanoseconds
    $/x;
}

##############################################################################

=head3 defined_store_fields

  my @fields = $date->defined_store_fields;

This method returns a list of all defined fields which are also valid for the
data stores.

=cut

sub defined_store_fields {
    my $self = shift;
    return grep ! /(?:time_zone|locale)/ => $self->defined_fields;
}

##############################################################################

=head3 sort_string

  my $sortable_string = $date->sort_string;

Returns the date in a string format suitable for sorting.  There are no
component separators and undefined components are ommitted.  All components
except year are zero padded to 2 characters.  The year is zero padded with
four characters.

  '19970623' eq Kinetic::DataType::DateTime::Incomplete->new(
    year  => 1997,
    month => 6,
    hour  => 23
  )->sort_string;

=cut

sub sort_string {
    my $self = shift;
    my $sort_string = $self->year? sprintf('%04d' => $self->year) : '';
    foreach my $i (1 .. $#COMPONENTS) {
        my $component = $COMPONENTS[$i];
        my $value     = $self->$component;
        $sort_string .= defined $value? sprintf('%02d' => $value) : '';
    }
    return $sort_string;
}

##############################################################################

=head3 same_segments

  if ($date->same_segments($other_date)) {
    ...
  }

Returns a boolean value indicating whether or not two dates have the same
segments defined.

=cut

sub same_segments {
    my ($self, $date)  = @_;
    return $self->_date_segments eq $date->_date_segments;
}

sub _date_segments {
    my $self = shift;
    return join '' => map { defined $self->$_? '1' : '0' } @COMPONENTS;
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
