#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok 'Kinetic::Util::Context' or die }

ok my $cx = Kinetic::Util::Context->new, "Get Context";
isa_ok $cx, 'Kinetic::Util::Context';
ok my $lang = $cx->language, "Get language";
isa_ok $lang, 'Kinetic::Util::Language';
is( Kinetic::Util::Context->language, $lang,
    "Check that class and instance are the same" );
