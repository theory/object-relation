#!/usr/bin/perl -w

# $Id: datetime.t 2506 2006-01-11 00:05:35Z theory $

use strict;

#use Test::More tests => 29;
use Test::More 'no_plan';
use Test::NoWarnings;    # Adds an extra test.
use Data::Dumper;

my $CLASS;

BEGIN {
    $CLASS = 'Kinetic::UI::Email::Workflow::Lexer';
    use_ok $CLASS, or die;
}

can_ok $CLASS, 'new';
ok my $email = $CLASS->new, '... and calling it should succeed';
isa_ok $email, $CLASS, '... and the object it returns';

my $text = <<'END_EMAIL';
    [ ] Forward to Gayle  {33333}
END_EMAIL

can_ok $email, 'lex';
ok my $result = $email->lex($text),
  '... and lexing valid data should succeed';
my $expected = [
    [ LBRACKET => '[' ],
    [ RBRACKET => ']' ],
    [ WORD     => 'Forward' ],
    [ WORD     => 'to' ],
    [ WORD     => 'Gayle' ],
    [ JOBID    => '33333' ]
];

is_deeply $result, $expected, '... and it should return the correct tokens';

$text = <<'END_EMAIL';
    [ ] "Forward to Gayle"  {33333}
END_EMAIL
ok $result = $email->lex($text),
  'We should be able to lex descriptions in quotes';
$expected = [
    [ LBRACKET => '[' ],
    [ RBRACKET => ']' ],
    [ WORD     => '"Forward to Gayle"' ],
    [ JOBID    => '33333' ]
];

is_deeply $result, $expected, '... and it should return the correct tokens';

$text = <<'END_EMAIL';
    [ ] "Forward [some stuff] to Gayle"  {33333}
END_EMAIL
$result   = $email->lex($text);
$expected = [
    [ LBRACKET => '[' ],
    [ RBRACKET => ']' ],
    [ WORD     => '"Forward [some stuff] to Gayle"' ],
    [ JOBID    => '33333' ]
];

is_deeply $result, $expected,
  '... even if we have brackets in the description';

$text = <<'END_EMAIL';
    [ ] Review document 
         {22222}
    [X] "Forward [some stuff] to Gayle"  {33333}
END_EMAIL

$expected = [
    [ LBRACKET => '[' ],
    [ RBRACKET => ']' ],
    [ WORD     => 'Review' ],
    [ WORD     => 'document' ],
    [ JOBID    => '22222' ],
    [ LBRACKET => '[' ],
    [ WORD     => 'X' ],
    [ RBRACKET => ']' ],
    [ WORD     => '"Forward [some stuff] to Gayle"' ],
    [ JOBID    => '33333' ],
];

$result = $email->lex($text);
is_deeply $result, $expected, 'We should be able to lex multiple tasks';
