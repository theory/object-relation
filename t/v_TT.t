#!/usr/bin/perl -w

# $Id: meta.t 2238 2005-11-19 07:33:20Z theory $

use strict;
use Kinetic::Build::Test;
use Test::More tests => 2;
use Test::NoWarnings; # Adds an extra test.

use_ok('Kinetic::UI::Catalyst::V::TT');

