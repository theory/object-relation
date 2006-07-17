package Kinetic::Store::DataType::DateTime;

# $Id$

use strict;
use base 'DateTime';
use DateTime::TimeZone;
use DateTime::Format::Strptime;
use Kinetic::Meta::Type;
use Exporter::Tidy other => ['is_iso8601'];

use version;
our $VERSION = version->new('0.0.2');

=head1 Name

Kinetic::Store::DataType::DateTime - Kinetic DateTime objects

=head1 Synopsis

  my $dt = Kinetic::Store::DataType::DateTime->new(
      year   => 1964,
      month  => 10,
      day    => 16,
      hour   => 16,
      minute => 12,
      second => 47,
  );

=head1 Description

This module creates the "datetime" data type for use in Kinetic attributes. It
subclasses the L<DateTime|DateTime> module to offer DateTime objects to
Kinetic applications. The only way in which it differs from DateTime is that
all new Kinetic::Store::DataType::DateTime objects are in the "UTC" time zone unless
another time zone is specified.

=cut

my $utc = DateTime::TimeZone::UTC->new;
Kinetic::Meta::Type->add(
    key     => 'datetime',
    name    => 'DateTime',
    raw     => sub {
        ref $_[0]
            ? shift->clone->set_time_zone($utc)->iso8601
            : shift;
    },
    bake    => sub { __PACKAGE__->bake(shift) },
    check   => __PACKAGE__,
);

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $dt = Kinetic::Store::DataType::DateTime->new(
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

=head3 bake

  my $dt = Kinetic::Store::DataType::DateTime->bake('1964-10-16T16:12:47.0');

Same as C<new> but takes an ISO-8601 date string as the argument.

=cut

#my $formatter = DateTime::Format::Strptime->new(pattern => '%Y-%m-%dT%H:%M:%S.%1N%z');
my $formatter =
  DateTime::Format::Strptime->new( pattern => '%Y-%m-%dT%H:%M:%S' );

sub new {
    my $class = shift;
    $class->SUPER::new(
        time_zone => $utc,
        formatter => $formatter,
        @_
    );
}

sub bake {
    my ( $class, $iso8601_date_string ) = @_;
    return unless $iso8601_date_string;
    my $args = $class->parse_iso8601_date($iso8601_date_string);
    return $class->new(%$args);
}

##############################################################################

=head2 Class Methods

=head3 parse_iso8601_date

  my $date_href = Kinetic::Store::DataType::DateTime->parse_iso8601_date($string);

Given an ISO8601 date string, returns a hashref with the date parts as values
to the keys. Keys are:

    year
    month
    day
    hour
    minute
    second
    nanosecond

Note that C<nanosecond> will not be a key in the hashref unless it is
specifically included in the ISO date string.

=cut

my $ISO8601_TEMPLATE = 'a4 x a2 x a2 x a2 x a2 x a2 a*';

sub parse_iso8601_date {
    my ( $class, $iso8601_date_string ) = @_;

    # It turns out that unpack() is faster than using a Regex. See
    # http://www.justatheory.com/computers/programming/perl/pack_vs_regex.html
    my %args;
    @args{qw(year month day hour minute second nanosecond)} =
      unpack $ISO8601_TEMPLATE, $iso8601_date_string;

    if ( '' eq $args{nanosecond} || !defined $args{nanosecond} ) {
        delete $args{nanosecond};
    }
    else {
        no warnings;
        $args{nanosecond} *= 1.0E9;
    }
    return \%args;
}

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 raw

  my $date_string = $date->raw;

Return the ISO8601 value of the datetime object.

=cut

sub raw {
    my $self = shift;
    return "$self";
}

##############################################################################

=head1 Functional Interface.

=head2 Exportable Functions

=head3 is_iso8601

  use Kinetic::Store::DataType::DateTime qw/is_iso8601/;
  if (is_iso8601('1964-10-16T16:12:47.0')) {
    ...
  }

Returns a true or false value depending upon whether or not the supplied
string matches an ISO 8601 datetime string. This is a function, not a method.

Nanoseconds are optional. Currently ignores timezone.

=cut

sub is_iso8601 {
    shift
        =~ /^\d\d\d\d-[0123]\d-[0123]\dT[012]\d:[012345]\d:[012345]\d(?:\.\d+)?$/;
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
