#!/usr/bin/perl -w

# $Id: meta.t 2238 2005-11-19 07:33:20Z theory $

use strict;
use Kinetic::Build::Test;

#use Test::More tests => 21;
use Test::More 'no_plan';
use Test::Exception;

# XXX We should either remove this test once we know what's going on or find
# an easy way to incorporate it in another test.

use Kinetic::Util::Functions 'load_store';
lives_ok { my $classes = load_store('t/sample/lib') }
  'We should be able to load the store';
