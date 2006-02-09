#!/usr/bin/perl -w

# $Id$

use strict;

use Test::More tests => 34;
#use Test::More 'no_plan';

use Test::NoWarnings;    # Adds an extra test.

my $WORKFLOW;

BEGIN {
    $WORKFLOW = 'Kinetic::UI::Email::Workflow';
    use_ok $WORKFLOW or die;
}

can_ok $WORKFLOW, 'new';
ok my $wf = $WORKFLOW->new(
    {   key_name => 'some_wf',
        job      => 'some_job',
        user     => 'user@some.email.com',
        org      => 'some_org',
    }
  ),
  '... and we should be able to create a new workflow object';
isa_ok $wf, $WORKFLOW, '... and the object it returns';

can_ok $wf, 'workflow';
is $wf->workflow, 'some_wf', '... and it should return the correct workflow';
can_ok $wf, 'job';
is $wf->job, 'some_job',
  '... and it should return the correct job in the workflow';
can_ok $wf, 'org';
is $wf->org, 'some_org',
  '... and it should return the correct organization in the workflow';
can_ok $wf, 'user';
is $wf->user, 'user@some.email.com',
  '... and it should return the correct user';

ok $wf = $WORKFLOW->new(
    'user@some.email.com',
    'some_job+some_wf@some_org.workflow.com'
  ),
  'We should be able to create a new workflow object from email addresses';
isa_ok $wf, $WORKFLOW, '... and the object it returns';

can_ok $wf, 'workflow';
is $wf->workflow, 'some_wf', '... and it should return the correct workflow';
can_ok $wf, 'job';
is $wf->job, 'some_job',
  '... and it should return the correct job in the workflow';
can_ok $wf, 'org';
is $wf->org, 'some_org',
  '... and it should return the correct organization in the workflow';
can_ok $wf, 'user';
is $wf->user, 'user@some.email.com',
  '... and it should return the correct user';

can_ok $wf, 'handle';
my $result = $wf->handle('> [ ] {Did not check the box}');
ok !$result, '... and the email body had no actionable commands';

$result = $wf->handle('> [ X] {Did check the box}');
ok $result, '... and the email body did have an actionable command';

can_ok $WORKFLOW, 'host';
ok my $host = $WORKFLOW->host, '... and calling it should succeed';

can_ok $WORKFLOW, 'is_workflow_address';
ok !$WORKFLOW->is_workflow_address('not@home.com'),
  '... and non-workflow addresses should return false';

# missing workflow
ok !$WORKFLOW->is_workflow_address( 'job+@some_org.' . $host ),
  '... and workflow addresses without a workflow should fail';

# missing job
ok !$WORKFLOW->is_workflow_address( '+wf@some_org.' . $host ),
  '... and workflow addresses without a job should fail';

# missing job
ok !$WORKFLOW->is_workflow_address( 'job+wf@' . $host ),
  '... and workflow addresses without an organization should fail';

ok $WORKFLOW->is_workflow_address( 'job+wf@some_org.' . $host ),
  '... and workflow addresses should return true';
__END__
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

