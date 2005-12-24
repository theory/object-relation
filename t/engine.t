#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw/no_plan/;
use Test::Exception;

my $ENGINE;

BEGIN {
    chdir 't' if -d 't';
    use lib '../lib';
    $ENGINE = 'Kinetic::Engine';
    use_ok $ENGINE or die;
}

can_ok $ENGINE, 'new';
ok my $engine = $ENGINE->new, '... and calling it should succeed';
isa_ok $engine, $ENGINE, '... and the object it returns';

can_ok $engine, 'type';
ok !defined $engine->type, '... and it should not be defined for this stub';
