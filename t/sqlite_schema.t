#!/usr/bin/perl -w

# $Id$

use strict;
use warnings;
use lib 't/lib';
use Kinetic::TestSetup store => { class => 'Kinetic::Store::DB::SQLite' };
use Test::More tests => 5;

BEGIN { use_ok 'Kinetic::Build::SchemaGen' };

ok my $sg = Kinetic::Build::SchemaGen->new, 'Get new SchemaGen';
isa_ok $sg, 'Kinetic::Build::SchemaGen';
isa_ok $sg, 'Kinetic::Build::SchemaGen::DB';
isa_ok $sg, 'Kinetic::Build::SchemaGen::DB::SQLite';
