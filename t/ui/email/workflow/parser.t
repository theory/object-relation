#!/usr/bin/perl -w

# $Id: datetime.t 2506 2006-01-11 00:05:35Z theory $

use strict;

use Test::More tests => 12;
#use Test::More 'no_plan';

use Test::NoWarnings;    # Adds an extra test.

my $CLASS;

BEGIN {
    $CLASS = 'Kinetic::UI::Email::Workflow::Parser';
    use_ok $CLASS, 'parse' or die;
}
use Kinetic::UI::Email::Workflow::Lexer 'lex';

#
# Incomplete stages
#

my $text = "> [ ] {Write Story}";
ok my $result = parse( lex($text) ),
  '... and parsing an unselected command should succeed';
is_deeply $result, [], '... and return an empty list';

$text = <<'END_EMAIL';
>  [ ] Return {Assign Writer(s)}
>  ============
>  This is a note
>  ============
>  [ ] {New Task}
>  [X] Help
END_EMAIL

ok $result = parse( lex($text) ),
  'Parsing a multi-stage workflow email should succed';

my $expected = [
    [ 1, 'help', '', '' ],
];
is_deeply $result, $expected, '... and return only the actions checked';

#
# Complete stages.  This is implicitly equivalent to the command:
#   [X] Complete {Assign Writer(s)}
# However, there will be no need for "Complete" in the email
#

$text = <<'END_EMAIL';
:   [X ] {Assign Writer(s)}
:   [ X ] Verbose email
END_EMAIL

ok $result = parse( lex($text) ), 'Lexing a complete stage should succeed';

$expected = [
    [ 1, 'complete',      'Assign Writer(s)', '' ],
    [ 1, 'verbose email', '',                 '' ],
];
is_deeply $result, $expected, '... and return the correct results';

#
# Multiple commands
#

$text = <<'END_EMAIL';
    [ $] {Assign Writer(s)}

    [n ] Return { Assign Writer(s) }
END_EMAIL

diag "Not sure yet of the best way to handle conflicting commands";
ok $result = parse( lex($text) ), 'Lexing conflicting commands might succeed';

$expected = [
    [ 1, 'complete', 'Assign Writer(s)', '' ],
    [ 1, 'return',   'Assign Writer(s)', '' ],
];
is_deeply $result, $expected, '... and return the correct results';

$text = <<'END_EMAIL';
> chromatic has finished "Assign Writer(s)".  You've been assigned to "Write
> Story".
> 
> This task is due on Tuesday, February 14, 2005.  When you have completed this
> task, please check the "Write Story" box and the task will be sent to "Copy
> Edit Story".
> 
> [x] {Write Story}
> 
> If you would like to add any notes to this task, please enter them below:
> 
> Enter any notes between these lines:
> ==========================================
> I finished my first draft.  Hope you like it.
> ==========================================
> 
> 
> If you do not wish to accept this task, please check the box below and enter
> an explanation below:
> 
> [ ] Return {Write Story}
> 
> Enter the reason between these lines:
> ===========================================
> 
> 
> 
> ===========================================
> 
> [ ] Verbose email
> 
> [ ] Help
> 
> Web interface:  http://ora.workflow.com/new_story/oo_blunders/
END_EMAIL

ok $result = parse( lex($text) ),
  'Parsing verbose email with notes should succeed';

$expected = [
    [   1,
        'complete',
        'Write Story',
        'I finished my first draft.  Hope you like it.'
    ],
];
is_deeply $result, $expected, '... and return the correct results';

