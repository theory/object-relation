#!/usr/bin/perl -w

# $Id: datetime.t 2441 2005-12-24 00:39:59Z theory $

use strict;
use Kinetic::Build::Test store => { class => 'Kinetic::Store::DB::Pg' };
use Test::More tests => 197;
#use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.
use Test::Exception;

my $CLASS;
BEGIN {
    $CLASS = 'Kinetic::DataType::Duration';
    use_ok $CLASS or die;
};

ok my $du = $CLASS->new, 'Create duration object';
isa_ok $du, $CLASS;
isa_ok $du, $CLASS;

for my $compare (
    [
        '01:00:00',
        '0 years 0 mons 0 days 1 hours 0 mins 0 secs',
        'PT1H',
        'P0Y0M0DT1H0M0S',
        $CLASS->new( hours => 1 ),
    ],

    [
        '01:00:00.299',
        '0 years 0 mons 0 days 1 hours 0 mins 0.299 secs',
        'PT1H.299S',
        'P0Y0M0DT1H0M0.299S',
        $CLASS->new(
            hours       => 1,
            nanoseconds => .299 * DateTime::MAX_NANOSECONDS,
        ),
    ],

    [
        '-08:00:00',
        '0 years 0 mons 0 days -8 hours 0 mins 0 secs',
        'PT-8H',
        'P0Y0M0DT-8H0M0S',
        $CLASS->new( hours => -8 ),
    ],

    [
        '-1 days',
        '0 years 0 mons -1 days 0 hours 0 mins 0 secs',
        'P-1D',
        'P0Y0M-1DT0H0M0S',
        $CLASS->new(days => -1),
    ],

    [
        '-23:59',
        '0 years 0 mons 0 days -23 hours -59 mins 0 secs',
        'PT-23H-59M',
        'P0Y0M0DT-23H-59M0S',
        $CLASS->new(hours => -23, minutes => -59),
    ],

    [
        '-1 days -00:01',
        '0 years 0 mons -1 days 0 hours -1 mins 0 secs',
        'P-1DT0H-1M',
        'P0Y0M-1DT0H-1M0S',
        $CLASS->new( days => -1, minutes => -1),
    ],

    [
        '1 mon -1 days',
        '0 years 1 mons -1 days 0 hours 0 mins 0 secs',
        'P1M-1D',
        'P0Y1M-1DT0H0M0S',
        $CLASS->new(months => 1)->add(days => -1),
    ],

    [
        '@ 1 mon -1 days .89 secs',
        '0 years 1 mons -1 days 0 hours 0 mins 0.89 secs',
        'P1M-1DT.89S',
        'P0Y1M-1DT0H0M0.89S',
        $CLASS->new(
            months      => 1,
            nanoseconds => .89 * DateTime::MAX_NANOSECONDS,
        )->add(days => -1),
    ],

    [
        '-1 days +02:03:00',
        '0 years 0 mons -1 days 2 hours 3 mins 0 secs',
        'P-1DT2H3M0S',
        'P0Y0M-1DT2H3M0S',
        $CLASS->new(days => -1)
            ->add(
                hours  => 2,
                minutes => 3,
            ),
    ],

    [
        '9 years 1 mon -12 days +13:14:00',
        '9 years 1 mons -12 days 13 hours 14 mins 0 secs',
        'P9Y1M-12DT13H14M0S',
        'P9Y1M-12DT13H14M0S',
        $CLASS->new(
            years   => 9,
            months  => 1,
            hours   => 13,
            minutes => 14,
        )->add(days => -12),
    ],

    [
        '@ 1 day ago',
        '0 years 0 mons -1 days 0 hours 0 mins 0 secs',
        'P-1D',
        'P0Y0M-1DT0H0M0S',
        $CLASS->new( days => -1 ),
    ],

    [
        '@ 1 day 10 mins',
        '0 years 0 mons 1 days 0 hours 10 mins 0 secs',
        'P1DT10M',
        'P0Y0M1DT0H10M0S',
        $CLASS->new( days => 1, minutes => 10 ),
    ],

    [
        '@ 23 hours 59 mins ago',
        '0 years 0 mons 0 days -23 hours -59 mins 0 secs',
        'PT-23H-59M',
        'P0Y0M0DT-23H-59M0S',
        $CLASS->new(
            hours => -23,
            minutes => -59
        ),
    ],

    [
        '@ 1 day 1 min ago',
        '0 years 0 mons -1 days 0 hours -1 mins 0 secs',
        'P-1DT-1M',
        'P0Y0M-1DT0H-1M0S',
        $CLASS->new( days => -1, minutes => -1 ),
    ],

    [
        '10 days',
        '0 years 0 mons 10 days 0 hours 0 mins 0 secs',
        'P10D',
        'P0Y0M10DT0H0M0S',
        $CLASS->new(days => 10 ),
    ],

    [
        '34 years',
        '34 years 0 mons 0 days 0 hours 0 mins 0 secs',
        'P34Y',
        'P34Y0M0DT0H0M0S',
        $CLASS->new(years => 34 ),
    ],

    [
        '3 mons',
        '0 years 3 mons 0 days 0 hours 0 mins 0 secs',
        'P3M',
        'P0Y3M0DT0H0M0S',
        $CLASS->new(months => 3 ),
    ],

    [
        '-00:00:14',
        '0 years 0 mons 0 days 0 hours 0 mins -14 secs',
        'P-14S',
        'P0Y0M0DT0H0M-14S',
        $CLASS->new(seconds => -14 ),
    ],

    [
        '1 day 02:03:04',
        '0 years 0 mons 1 days 2 hours 3 mins 4 secs',
        'P1DT2H3M4S',
        'P0Y0M1DT2H3M4S',
        $CLASS->new(
            days => 1,
            hours => 2,
            minutes => 3,
            seconds => 4,
        ),
    ],

    [
        '5 mons 12:00:00',
        '0 years 5 mons 0 days 12 hours 0 mins 0 secs',
        'P5MT12H',
        'P0Y5M0DT12H0M0S',
        $CLASS->new( months => 5, hours => 12),
    ],

    [
        '@ 1 min',
        '0 years 0 mons 0 days 0 hours 1 mins 0 secs',
        'PT1M',
        'P0Y0M0DT0H1M0S',
        $CLASS->new(minutes => 1 ),
    ],

    [
        '@ 5 hours',
        '0 years 0 mons 0 days 5 hours 0 mins 0 secs',
        'P5H',
        'P0Y0M0DT5H0M0S',
        $CLASS->new( hours => 5 ),
    ],

    [
        '@ 34 years',
        '34 years 0 mons 0 days 0 hours 0 mins 0 secs',
        'P34Y',
        'P34Y0M0DT0H0M0S',
        $CLASS->new(years => 34 ),
    ],

    [
        '@ 3 mons',
        '0 years 3 mons 0 days 0 hours 0 mins 0 secs',
        'P3M',
        'P0Y3M0DT0H0M0S',
        $CLASS->new(months => 3 ),
    ],

    [
        '@ 14 secs ago',
        '0 years 0 mons 0 days 0 hours 0 mins -14 secs',
        'P-14S',
        'P0Y0M0DT0H0M-14S',
        $CLASS->new( seconds => -14 ),
    ],

    [
        '@ 1 day 2 hours 3 mins 4 secs',
        '0 years 0 mons 1 days 2 hours 3 mins 4 secs',
        'P1DT2H3M4S',
        'P0Y0M1DT2H3M4S',
        $CLASS->new(
            days => 1,
            hours => 2,
            minutes => 3,
            seconds => 4,
        ),
    ],

    [
        '@ 5 mons 12 hours',
        '0 years 5 mons 0 days 12 hours 0 mins 0 secs',
        'P5MT12H',
        'P0Y5M0DT12H0M0S',
        $CLASS->new( hours => 12, months => 5),
    ],

    [
        '@ 4541 years 4 mons 4 days 17 mins 31 secs',
        '4541 years 4 mons 4 days 0 hours 17 mins 31 secs',
        'P4541Y4M4DT17M31S',
        'P4541Y4M4DT0H17M31S',
        $CLASS->new(
            years => 4541,
            months => 4,
            days => 4,
            minutes => 17,
            seconds => 31,
        ),
    ],

    [
        '@ 6 mons 5 days 4 hours 3 mins 2 secs',
        '0 years 6 mons 5 days 4 hours 3 mins 2 secs',
        'P6M5DT4H3M2S',
        'P0Y6M5DT4H3M2S',
        $CLASS->new(
            months => 6,
            days => 5,
            hours => 4,
            minutes => 3,
            seconds => 2,
        ),
    ],

    [
        '1 days 02:03:00 ago',
        '0 years 0 mons -1 days -2 hours -3 mins 0 secs',
        'P-1DT-2H-3M0S',
        'P0Y0M-1DT-2H-3M0S',
        $CLASS->new(
            days => -1,
            hours => -2,
            minutes => -3,
        ),
    ],

) {
    my ($pg, $pg_raw, $iso, $iso_raw, $obj) = @$compare;
    # Try Pg format.
    my $du = $CLASS->bake($pg);
    ok !$CLASS->compare($du, $obj), qq{Parse "$pg"};
    is $du->straw, $pg_raw, qq{Raw pg "$pg_raw"};

    # Try ISO-8601 format.
    $du = $CLASS->bake($iso);
    ok !$CLASS->compare($du, $obj), qq{Parse "$iso"};
    is $du->raw, $iso_raw, qq{Raw iso "$iso_raw"};
}

##############################################################################
# Test badly-formatted duration strings.
my $ex_class = 'Kinetic::Util::Exception::Fatal::Invalid';

throws_ok { $CLASS->bake('') } $ex_class, 'Empty string should fail to bake';
like $@, qr/Invalid duration string: \x{201c}\x{201d}/,
    '... And with the correct message';

throws_ok { $CLASS->bake(undef) } $ex_class, 'Undef should fail to bake';
like $@, qr/No duration string passed to bake()/,
    '... And with the correct message';

for my $str (
    'P',
    'P0M0Y',
    'PT',
    'PT10MT10M',
    '1 mon 10 years',
    '62:00',
    '22:105',
    '18:-23',
    'ago',
    '1 hour 3 hours',
    '00:23:23:23',
) {
    throws_ok { $CLASS->bake($str) } $ex_class, qq{"$str" should fail};
    like $@, qr/Invalid duration string: \x{201c}$str\x{201d}/,
        '... And with the correct message';
}

##############################################################################
# Test comparison overloading.
ok my $dur1 = $CLASS->new( hours => 1 ), 'Create a 1-hour duration';
ok my $dur2 = $dur1->clone, 'Clone it';

ok $dur1 eq $dur2,    'They should eq';
ok !($dur1 ne $dur2), 'They should not ne';
ok !($dur1 gt $dur2), 'They should not gt';
ok !($dur1 lt $dur2), 'They should not lt';
ok $dur1 ge $dur2,    'They should ge';
ok $dur1 le $dur2,    'They should le';

ok $dur1 == $dur2,    'They should ==';
ok !($dur1 != $dur2), 'They should not !=';
ok !($dur1 > $dur2),  'They should not >';
ok !($dur1 < $dur2),  'They should not >';
ok $dur1 >= $dur2,    'They should >=';
ok $dur1 <= $dur2,    'They should >=';

ok !($dur1 cmp $dur2), 'They should not cmp';
ok !($dur1 <=> $dur2), 'They should not <=>';

ok $dur2->add(minutes => -1) , 'Subract a minute from the clone';

ok !($dur1 eq $dur2), 'They should not eq';
ok $dur1 ne $dur2,    'They should ne';
ok $dur1 gt $dur2,    'They should gt';
ok !($dur1 lt $dur2), 'They should not lt';
ok $dur1 ge $dur2,    'They should ge';
ok !($dur1 le $dur2), 'They should not le';

ok !($dur1 == $dur2), 'They should not ==';
ok $dur1 != $dur2,    'They should !=';
ok $dur1 > $dur2,     'They should >';
ok !($dur1 < $dur2),  'They should not <';
ok $dur1 >= $dur2,    'They should >=';
ok !($dur1 <= $dur2), 'They should not =>';

is $dur1 cmp $dur2, 1, 'cmp should yield 1';
is $dur1 <=> $dur2, 1, '<=> should yield 1';

ok $dur2 = $CLASS->new(minutes => 65), 'Create a 65-minute duration';

ok !($dur1 eq $dur2), 'They should not eq';
ok $dur1 ne $dur2,    'They should ne';
ok !($dur1 gt $dur2), 'They should not gt';
ok $dur1 lt $dur2,    'They should le';
ok !($dur1 ge $dur2), 'They should not ge';
ok $dur1 le $dur2,    'They should le';

ok !($dur1 == $dur2), 'They should not ==';
ok $dur1 != $dur2,    'They should !=';
ok !($dur1 > $dur2),  'They should not >';
ok $dur1 < $dur2,     'They should <';
ok !($dur1 >= $dur2), 'They should not >=';
ok $dur1 <= $dur2,    'They should <=';

is $dur1 cmp $dur2, -1, 'cmp should yield -1';
is $dur1 <=> $dur2, -1, '<=> should yield -1';

