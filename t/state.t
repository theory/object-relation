#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 94;

BEGIN {
    use_ok('Kinetic::State');
}

IMPORT: { # 10 tests.
    package Kinetic::State::TestImport;
    use Kinetic::State qw(:all);
    use Test::More;

    for my $state (PERMANENT, ACTIVE, INACTIVE, DELETED, PURGED) {
        ok(ref $state, "Got $state" );
        isa_ok($state, 'Kinetic::State');
    }
}

NOIMPORT: { # 5 tests.
    package Kinetic::State::TestNoImport;
    use Kinetic::State;
    use Test::More;
    for my $state qw(PERMANENT ACTIVE INACTIVE DELETED PURGED) {
        eval "my \$foo = $state;";
        ok($@, "$state not imported" );
    }
}

NEW: { # 20 tests.
    package Kinetic::State::TestNew;
    use Kinetic::State;
    use Test::More;
    for my $val (-2..2) {
        my $state = Kinetic::State->new($val);
        ok(ref $state, "new($val)");
        is( $state->value, $val, "Value is $val" );
        is( int($state), $val, "Numeric context gets $val" );
        unlike( "$state", qr/Kinetic::State=ARRAY/,
                "Stringify $state");
    }
}

BOOL: { # 10 tests.
    package Kinetic::State::TestBool;
    use Kinetic::State qw(:all);
    use Test::More;

    ok( PERMANENT, "Permanent is true" );
    ok( PERMANENT->is_active, "Permanent is active" );
    ok( ACTIVE, "Active is true" );
    ok( ACTIVE->is_active, "Active is active" );
    ok( ! INACTIVE, "Inactive is false" );
    ok( ! INACTIVE->is_active, "Inactive is not active" );
    ok( ! DELETED, "Deleted is false" );
    ok( ! DELETED->is_active, "Deleted is not active" );
    ok( ! PURGED, "Purged is false" );
    ok( ! PURGED->is_active, "Purged is not active" );
}

COMPARE: { # 48 tests.
    package Kinetic::State::TestCompare;
    use Kinetic::State qw(:all);
    use Test::More;

    my $state = INACTIVE;
    ok ( ref $state, "Get Inactive");
    my $lt = DELETED;
    ok( ref DELETED, "Get Deleted" );
    ok( my $gt = ACTIVE, "Get Active" );

    # Equivalence.
    is( $state->compare($state), 0, "$state->compare($state)" );

    ok( $state == $state, "$state == $state");
    ok( $state eq $state, "$state eq $state");
    ok( !($state != $state), "!($state != $state)");
    ok( !($state ne $state), "!($state ne $state)");

    ok( !($state > $state), "!($state > $state)");
    ok( !($state gt $state), "!($state gt $state)");
    ok( $state >= $state, "$state >= $state" );
    ok( $state ge $state, "$state ge $state" );

    ok( !($state < $state), "!($state < $state)");
    ok( !($state lt $state), "!($state lt $state)");
    ok( $state <= $state, "$state <= $state" );
    ok( $state le $state, "$state le $state" );

    is( $state <=> $state, 0, "$state <=> $state" );
    is( $state cmp $state, 0, "$state <=> $state" );

    # Greater than.
    is( $state->compare($lt), 1, "$state->compare($lt)" );

    ok( !($state == $lt), "!($state == $lt)");
    ok( !($state eq $lt), "!($state ne $lt)");
    ok( $state != $lt, "$state != $lt");
    ok( $state ne $lt, "$state ne $lt");

    ok( $state > $lt, "$state > $lt");
    ok( $state gt $lt, "$state gt $lt");
    ok( $state >= $lt, "$state >= $lt" );
    ok( $state ge $lt, "$state ge $lt" );

    ok( !($state < $lt), "!($state < $lt)");
    ok( !($state lt $lt), "!($state lt $lt)");
    ok( !($state <= $lt), "!($state <= $lt)" );
    ok( !($state le $lt), "!($state le $lt)" );

    is( $state <=> $lt, 1, "$state <=> $lt" );
    is( $state cmp $lt, 1, "$state <=> $lt" );

    # Less than.
    is( $state->compare($gt), -1, "$state->compare($gt)" );

    ok( !($state == $gt), "!($state == $gt)");
    ok( !($state eq $gt), "!($state ne $gt)");
    ok( $state != $gt, "$state != $gt");
    ok( $state ne $gt, "$state ne $gt");

    ok( !($state > $gt), "!($state > $gt)");
    ok( !($state gt $gt), "!($state gt $gt)");
    ok( !($state >= $gt), "!($state >= $gt)" );
    ok( !($state ge $gt), "!($state ge $gt)" );

    ok( $state < $gt, "$state < $gt");
    ok( $state lt $gt, "$state lt $gt");
    ok( $state <= $gt, "$state <= $gt" );
    ok( $state le $gt, "$state le $gt" );

    is( $state <=> $gt, -1, "$state <=> $gt" );
    is( $state cmp $gt, -1, "$state <=> $gt" );
}

1;
__END__
