#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok 'Kinetic::Context' }

ok my $cx = Kinetic::Context->new, "Get Context";
isa_ok $cx, 'Kinetic::Context';
ok my $lang = $cx->language, "Get language";
isa_ok $lang, 'Kinetic::Language';
is( Kinetic::Context->language, $lang,
    "Check that class and instance are the same" );
