#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 20;
#use Test::More 'no_plan';
use Test::NoWarnings; # Adds an extra test.
use Test::Exception;

my $CLASS;
BEGIN {
    $CLASS = 'Kinetic::Store::DataType::MediaType';
    use_ok $CLASS or die;
};

ok my $mt = $CLASS->bake('text/html'), 'Get text/html type';
isa_ok $mt, $CLASS, 'It';
isa_ok $mt, 'MIME::Type', 'It';
is $mt->type, 'text/html', 'Its type should be "text/html"';

# Test singleton.
ok my $mt2 = $CLASS->bake('text/html'), 'Get text/html type again';
is overload::StrVal($mt), overload::StrVal($mt2),
    'It should be the same object';

# Try non-existing media type.
ok $mt = $CLASS->bake('text/foobarbad'), 'Get text/foobarbad type';
isa_ok $mt, $CLASS, 'It';
isa_ok $mt, 'MIME::Type', 'It';
is $mt->type, 'text/foobarbad', 'Its type should be "text/foobarbad"';

# Try an invalid media type.
throws_ok { $CLASS->bake('foo') }
    'Kinetic::Store::Exception::Fatal::Invalid',
    'Invalid media type should throw an exception';
like $@, qr/Value \x{201c}foo\x{201d} is not a valid media type/,
    'It should have the proper error message';

# Test new().
ok $mt = $CLASS->new( type => 'text/plain'), 'Get text/plain from new()';
isa_ok $mt, $CLASS, 'It';
isa_ok $mt, 'MIME::Type', 'It';
ok $mt = $CLASS->new( 'text/plain'),
    'Get text/plain as single argument to new()';
isa_ok $mt, $CLASS, 'It';
isa_ok $mt, 'MIME::Type', 'It';
