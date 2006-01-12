#!/usr/bin/perl -w

# $Id: datetime.t 2441 2005-12-24 00:39:59Z theory $

use strict;
# We're testing non-Pg interval representation.
use Kinetic::Build::Test store => { class => 'Kinetic::Store::DB::SQLite' };
use Test::More tests => 62;
#use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.

my $CLASS;
BEGIN {
    $CLASS = 'Kinetic::DataType::Duration';
    use_ok $CLASS or die;
};

for my $compare (
    [
        'P0Y0M0DT1H0M0S',
        'P00000Y00M00DT01H00M00S',
        $CLASS->new( hours => 1 ),
    ],

    [
        'P0Y0M0DT1H0M0.299S',
        'P00000Y00M00DT01H00M00.299S',
        $CLASS->new(
            hours       => 1,
            nanoseconds => .299 * DateTime::MAX_NANOSECONDS,
        ),
    ],

    [
        'P0Y0M0DT-8H0M0S',
        'P00000Y00M00DT-8H00M00S',
        $CLASS->new( hours => -8 ),
    ],

    [
        'P0Y0M-1DT0H0M0S',
        'P00000Y00M-1DT00H00M00S',
        $CLASS->new(days => -1),
    ],

    [
        'P0Y0M0DT-23H-59M0S',
        'P00000Y00M00DT-23H-59M00S',
        $CLASS->new(hours => -23, minutes => -59),
    ],

    [
        'P0Y0M-1DT0H-1M0S',
        'P00000Y00M-1DT00H-1M00S',
        $CLASS->new( days => -1, minutes => -1),
    ],

    [
        'P0Y1M-1DT0H0M0S',
        'P00000Y01M-1DT00H00M00S',
        $CLASS->new(months => 1)->add(days => -1),
    ],

    [
        'P0Y1M-1DT0H0M0.89S',
        'P00000Y01M-1DT00H00M00.89S',
        $CLASS->new(
            months      => 1,
            nanoseconds => .89 * DateTime::MAX_NANOSECONDS,
        )->add(days => -1),
    ],

    [
        'P0Y0M-1DT2H3M0S',
        'P00000Y00M-1DT02H03M00S',
        $CLASS->new(days => -1)
            ->add(
                hours  => 2,
                minutes => 3,
            ),
    ],

    [
        'P9Y1M-12DT13H14M0S',
        'P00009Y01M-12DT13H14M00S',
        $CLASS->new(
            years   => 9,
            months  => 1,
            hours   => 13,
            minutes => 14,
        )->add(days => -12),
    ],

    [
        'P0Y0M-1DT0H0M0S',
        'P00000Y00M-1DT00H00M00S',
        $CLASS->new( days => -1 ),
    ],

    [
        'P0Y0M1DT0H10M0S',
        'P00000Y00M01DT00H10M00S',
        $CLASS->new( days => 1, minutes => 10 ),
    ],

    [
        'P0Y0M0DT-23H-59M0S',
        'P00000Y00M00DT-23H-59M00S',
        $CLASS->new(
            hours => -23,
            minutes => -59
        ),
    ],

    [
        'P0Y0M-1DT0H-1M0S',
        'P00000Y00M-1DT00H-1M00S',
        $CLASS->new( days => -1, minutes => -1 ),
    ],

    [
        'P0Y0M10DT0H0M0S',
        'P00000Y00M10DT00H00M00S',
        $CLASS->new(days => 10 ),
    ],

    [
        'P34Y0M0DT0H0M0S',
        'P00034Y00M00DT00H00M00S',
        $CLASS->new(years => 34 ),
    ],

    [
        'P0Y3M0DT0H0M0S',
        'P00000Y03M00DT00H00M00S',
        $CLASS->new(months => 3 ),
    ],

    [
        'P0Y0M0DT0H0M-14S',
        'P00000Y00M00DT00H00M-14S',
        $CLASS->new(seconds => -14 ),
    ],

    [
        'P0Y0M1DT2H3M4S',
        'P00000Y00M01DT02H03M04S',
        $CLASS->new(
            days => 1,
            hours => 2,
            minutes => 3,
            seconds => 4,
        ),
    ],

    [
        'P0Y5M0DT12H0M0S',
        'P00000Y05M00DT12H00M00S',
        $CLASS->new( months => 5, hours => 12),
    ],

    [
        'P0Y0M0DT0H1M0S',
        'P00000Y00M00DT00H01M00S',
        $CLASS->new(minutes => 1 ),
    ],

    [
        'P0Y0M0DT5H0M0S',
        'P00000Y00M00DT05H00M00S',
        $CLASS->new( hours => 5 ),
    ],

    [
        'P34Y0M0DT0H0M0S',
        'P00034Y00M00DT00H00M00S',
        $CLASS->new(years => 34 ),
    ],

    [
        'P0Y3M0DT0H0M0S',
        'P00000Y03M00DT00H00M00S',
        $CLASS->new(months => 3 ),
    ],

    [
        'P0Y0M0DT0H0M-14S',
        'P00000Y00M00DT00H00M-14S',
        $CLASS->new( seconds => -14 ),
    ],

    [
        'P0Y0M1DT2H3M4S',
        'P00000Y00M01DT02H03M04S',
        $CLASS->new(
            days    => 1,
            hours   => 2,
            minutes => 3,
            seconds => 4,
        ),
    ],

    [
        'P0Y5M0DT12H0M0S',
        'P00000Y05M00DT12H00M00S',
        $CLASS->new( hours => 12, months => 5),
    ],

    [
        'P4541Y4M4DT0H17M31S',
        'P04541Y04M04DT00H17M31S',
        $CLASS->new(
            years   => 4541,
            months  => 4,
            days    => 4,
            minutes => 17,
            seconds => 31,
        ),
    ],

    [
        'P0Y6M5DT4H3M2S',
        'P00000Y06M05DT04H03M02S',
        $CLASS->new(
            months  => 6,
            days    => 5,
            hours   => 4,
            minutes => 3,
            seconds => 2,
        ),
    ],

    [
        'P0Y0M-1DT-2H-3M0S',
        'P00000Y00M-1DT-2H-3M00S',
        $CLASS->new(
            days    => -1,
            hours   => -2,
            minutes => -3,
        ),
    ],

) {
    my ($iso_raw, $iso_padded, $obj) = @$compare;
    my $du = $CLASS->bake($iso_raw);
    is $du->store_raw, $iso_padded,         qq{Padded iso is "$iso_padded"};
    is $CLASS->bake($iso_padded), $obj, qq{Parse         "$iso_padded"};
}


__END__
