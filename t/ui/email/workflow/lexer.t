#!/usr/bin/perl -w

# $Id: datetime.t 2506 2006-01-11 00:05:35Z theory $

use strict;

use Test::More tests => 26;
#use Test::More 'no_plan';
use Test::NoWarnings;    # Adds an extra test.

my $CLASS;

BEGIN {
    $CLASS = 'Kinetic::UI::Email::Workflow::Lexer';
    use_ok $CLASS, 'lex' or die;
}

#
# Incomplete stages
#

my $text = <<'END_EMAIL';
    [ ] {Assign Writer(s)}
END_EMAIL

ok my $result = lex($text),
  '... and lexing an incomplete stage should succeed';
my $expected = [
    [ PERFORM => 0 ],
    [ ACTION  => 'complete' ],
    [ STAGE   => 'Assign Writer(s)' ],
];
is_deeply $result, $expected,
  '... and we should be able to lex a basic stage';

#
# Complete stages.  This is implicitly equivalent to the command:
#   [X] Complete {Assign Writer(s)}
# However, there will be no need for "Complete" in the email
#

$text = <<'END_EMAIL';
    [X ] {Assign Writer(s)}
END_EMAIL

ok $result = lex($text), 'Lexing a complete stage should succeed';

$expected = [
    [ PERFORM => 1 ],
    [ ACTION  => 'complete' ],
    [ STAGE   => 'Assign Writer(s)' ],
];
is_deeply $result, $expected, '... and return the correct results';

$text = <<'END_EMAIL';
    [ done ] {Assign Writer(s)}
END_EMAIL

ok $result = lex($text), 'Lexing a complete stage should succeed';

$expected = [
    [ PERFORM => 1 ],
    [ ACTION  => 'complete' ],
    [ STAGE   => 'Assign Writer(s)' ],
];
is_deeply $result, $expected, '... and return the correct results';

#
# Incomplete commands
#

$text = <<'END_EMAIL';
    [ ] Return { Assign Writer(s) }
END_EMAIL

ok $result = lex($text),
  'Lexing an incomplete command should succeed';

$expected = [
    [ PERFORM => 0 ],
    [ ACTION  => 'return' ],
    [ STAGE   => 'Assign Writer(s)' ],
];
is_deeply $result, $expected, '... and return the correct results';

#
# Complete commands
#

$text = <<'END_EMAIL';
    [ . ] Return { Assign Writer(s) }
END_EMAIL

ok $result = lex($text), 'Lexing a complete command should succeed';

$expected = [
    [ PERFORM => 1 ],
    [ ACTION  => 'return' ],
    [ STAGE   => 'Assign Writer(s)' ],
];
is_deeply $result, $expected, '... and return the correct results';

#
# Multiple commands
#

# Conflicts such as "complete $stage" and "return $stage" will be handled in
# the parser.

$text = <<'END_EMAIL';
    [ $] {Assign Writer(s)}

    [  ] Return { Assign Writer(s) }

    [ X] Verbose email
    [X] Help
END_EMAIL

ok $result = lex($text), 'Lexing a complete command should succeed';

$expected = [
    [ PERFORM => 1 ],
    [ ACTION  => 'complete' ],
    [ STAGE   => 'Assign Writer(s)' ],
    [ PERFORM => 0 ],
    [ ACTION  => 'return' ],
    [ STAGE   => 'Assign Writer(s)' ],
    [ PERFORM => 1 ],
    [ ACTION  => 'verbose email' ],
    [ PERFORM => 1 ],
    [ ACTION  => 'help' ],
];
is_deeply $result, $expected, '... and return the correct results';

# Conflicts such as "complete $stage" and "return $stage" will be handled in
# the parser.

$text = <<'END_EMAIL';
>    [ $] {Assign Writer(s)}
>
>    [  ] Return { Assign Writer(s) }
>
>    [ X] Verbose email
>    [X] Help
END_EMAIL

ok $result = lex($text),
  'Lexing a a normal email body should succeed';

$expected = [
    [ PERFORM => 1 ],
    [ ACTION  => 'complete' ],
    [ STAGE   => 'Assign Writer(s)' ],
    [ PERFORM => 0 ],
    [ ACTION  => 'return' ],
    [ STAGE   => 'Assign Writer(s)' ],
    [ PERFORM => 1 ],
    [ ACTION  => 'verbose email' ],
    [ PERFORM => 1 ],
    [ ACTION  => 'help' ],
];
is_deeply $result, $expected, '... and return the correct results';

$text = <<'END_EMAIL';
> chromatic has finished "Assign Writer(s)".  You've been assigned to "Write
> Story".
> 
> This task is due on Tuesday, February 14, 2005.  When you have completed this
> task, please check the "Write Story" box and the task will be sent to "Copy
> Edit Story".
>    [ $] {Assign Writer(s)}
>
>    [  ] Return { Assign Writer(s) }
>
>    [ X] Verbose email
>    [X] Help
END_EMAIL

ok $result = lex($text),
  'Lexing a a normal email body should succeed';

$expected = [
    [ PERFORM => 1 ],
    [ ACTION  => 'complete' ],
    [ STAGE   => 'Assign Writer(s)' ],
    [ PERFORM => 0 ],
    [ ACTION  => 'return' ],
    [ STAGE   => 'Assign Writer(s)' ],
    [ PERFORM => 1 ],
    [ ACTION  => 'verbose email' ],
    [ PERFORM => 1 ],
    [ ACTION  => 'help' ],
];
is_deeply $result, $expected, '... and return the correct results';

$text = <<'END_EMAIL';
] chromatic has finished "Assign Writer(s)".  You've been assigned to "Write
] Story".
] 
] This task is due on Tuesday, February 14, 2005.  When you have completed this
] task, please check the "Write Story" box and the task will be sent to "Copy
] Edit Story".
]    [ $] {Assign Writer(s)}
]
]    [  ] Return { Assign Writer(s) }
]
]    [ X] Verbose email
]    [X] Help
END_EMAIL

ok $result = lex($text),
  'Lexing a a normal email body with string quote characters should succeed';

$expected = [
    [ PERFORM => 1 ],
    [ ACTION  => 'complete' ],
    [ STAGE   => 'Assign Writer(s)' ],
    [ PERFORM => 0 ],
    [ ACTION  => 'return' ],
    [ STAGE   => 'Assign Writer(s)' ],
    [ PERFORM => 1 ],
    [ ACTION  => 'verbose email' ],
    [ PERFORM => 1 ],
    [ ACTION  => 'help' ],
];
is_deeply $result, $expected, '... and return the correct results';

$text = <<'END_EMAIL';
} chromatic has finished "Assign Writer(s)".  You've been assigned to "Write
} Story".
} 
} This task is due on Tuesday, February 14, 2005.  When you have completed this
} task, please check the "Write Story" box and the task will be sent to "Copy
} Edit Story".
}
}    [ $] {Assign Writer(s)}
}
}    [  ] Return { Assign Writer(s) }
}
}    [ X] Verbose email
}    [X] Help
END_EMAIL

ok $result = lex($text),
  'Lexing a a normal email body with string quote characters should succeed';

$expected = [
    [ PERFORM => 1 ],
    [ ACTION  => 'complete' ],
    [ STAGE   => 'Assign Writer(s)' ],
    [ PERFORM => 0 ],
    [ ACTION  => 'return' ],
    [ STAGE   => 'Assign Writer(s)' ],
    [ PERFORM => 1 ],
    [ ACTION  => 'verbose email' ],
    [ PERFORM => 1 ],
    [ ACTION  => 'help' ],
];
is_deeply $result, $expected, '... and return the correct results';

$text = <<'END_EMAIL';
chromatic has finished "Assign Writer(s)".  You've been assigned to "Write
Story".

This task is due on Tuesday, February 14, 2005.  When you have completed this
task, please check the "Write Story" box and the task will be sent to "Copy
Edit Story".

[ ] "Write Story"

If you would like to add any notes to this task, please enter them below:

Enter any notes between these lines:
==========================================

this is a note
==========================================


If you do not wish to accept this task, please check the box below and enter
an explanation below:

[ ] Return "Write Story"

Enter the reason between these lines:
===========================================
this is the reason
and another line

===========================================

[ ] Verbose email

[ ] Help

Web interface:  http://ora.workflow.com/new_story/oo_blunders/
END_EMAIL

ok $result = lex($text),
  'Lexing an email body with notes should succeed';

$expected = [
    [ PERFORM => 0 ],
    [ ACTION  => "write story" ],
    [ NOTE    => "this is a note" ],
    [ PERFORM => 0 ],
    [ ACTION  => "return" ],
    [ NOTE    => "this is the reason\nand another line" ],
    [ PERFORM => 0 ],
    [ ACTION  => "verbose email" ],
    [ PERFORM => 0 ],
    [ ACTION  => "help" ],
];
is_deeply $result, $expected, '... and return the notes';

$text = <<'END_EMAIL';
> chromatic has finished "Assign Writer(s)".  You've been assigned to "Write
> Story".
> 
> This task is due on Tuesday, February 14, 2005.  When you have completed this
> task, please check the "Write Story" box and the task will be sent to "Copy
> Edit Story".
> 
> [ ] "Write Story"
> 
> If you would like to add any notes to this task, please enter them below:
> 
> Enter any notes between these lines:
> ==========================================
> 
> this is a note
> ==========================================
> 
> 
> If you do not wish to accept this task, please check the box below and enter
> an explanation below:
> 
> [ ] Return "Write Story"
> 
> Enter the reason between these lines:
> ===========================================
> this is the reason
> and another line
> 
> ===========================================
> 
> [ ] Verbose email
> 
> [ ] Help
> 
> Web interface:  http://ora.workflow.com/new_story/oo_blunders/
END_EMAIL

ok $result = lex($text),
  'Lexing an email body with notes and quote characters should succeed';

$expected = [
    [ PERFORM => 0 ],
    [ ACTION  => "write story" ],
    [ NOTE    => "this is a note" ],
    [ PERFORM => 0 ],
    [ ACTION  => "return" ],
    [ NOTE    => "this is the reason\nand another line" ],
    [ PERFORM => 0 ],
    [ ACTION  => "verbose email" ],
    [ PERFORM => 0 ],
    [ ACTION  => "help" ],
];

is_deeply $result, $expected, '... and return the notes';

sub _dump {
    my $result = shift;
    foreach (@$result) {
        print "@$_\n";
    }
}
