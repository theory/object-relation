#!/usr/bin/perl -w

# $Id: datetime.t 2506 2006-01-11 00:05:35Z theory $

use strict;

#use Test::More tests => 29;
use Test::More 'no_plan';
use Test::NoWarnings;    # Adds an extra test.

my $CLASS;

BEGIN {
    $CLASS = 'Kinetic::UI::Email::Workflow';
    use_ok $CLASS, or die;
}

can_ok $CLASS, 'new';
ok my $email = $CLASS->new, '... and calling it should succeed';
isa_ok $email, $CLASS, '... and the object it returns';

my $text = <<'END_EMAIL';
    [ ] Forward to Gayle  {33333}
END_EMAIL


