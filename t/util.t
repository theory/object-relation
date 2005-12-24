#!/usr/bin/perl -w

# $Id: meta.t 2238 2005-11-19 07:33:20Z theory $

use strict;
use Test::More tests => 12;
#use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.

BEGIN { use_ok('Kinetic::Util::Functions') or die; }

NOIMPORT: { # 1 test.
    package MyTest1;
    use Kinetic::Util::Functions;
    use Test::More;
    ok !defined(&create_uuid), 'create_uuid() should not have been imported';
}

UUID: { # 10 tests.
    package MyTest2;
    use Kinetic::Util::Functions qw(:uuid);
    use Kinetic::Util::Constants qw($UUID_RE);
    use Test::More;
    can_ok __PACKAGE__, 'create_uuid';
    can_ok __PACKAGE__, 'uuid_to_bin';
    can_ok __PACKAGE__, 'uuid_to_hex';
    can_ok __PACKAGE__, 'uuid_to_b64';

    ok my $uuid = create_uuid(), 'Create a UUID';
    like $uuid, $UUID_RE, 'It should be a valid UUID';

    # Test uuid_to_hex().
    (my $hex = $uuid) =~ s/-//g;
    is uuid_to_hex($uuid), "0x$hex", 'uuid_to_hex should work';

    # Test uuid_to_bin().
    my $ug = OSSP::uuid->new;
    $ug->import(str => $uuid);
    my $bin = $ug->export('bin');
    is uuid_to_bin($uuid), $bin, 'uuid_to_bin should work';

    # Test uuid_to_b64().
    is uuid_to_b64($uuid), MIME::Base64::encode($bin),
        'uuid_to_b64 should work';
}
