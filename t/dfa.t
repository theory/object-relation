#!/usr/bin/perl -w

# $Id$

use strict;
#use Test::More 'no_plan';
use Test::More tests => 20;
use Test::Exception;

my $DFA;
BEGIN { 
    $DFA = 'Kinetic::Util::DFA';
    use_ok $DFA or die;
};

my $flag;
my ($enter, $action, $leave);
my %state_machine = (
    first => {
        enter => sub {$enter = "Enter Action 1"},
        leave => sub {$leave = "Leave Action 1"},
        goto => [
            first  => [sub { $flag == 1 }, sub { $action = "Action 1" }],
            second => [sub { $flag == 2 }, sub { $action = "Action 2" }],
            third  => [sub { $flag == 3 }, sub { $action = "Action 3" }],
        ],
    },
    second => {
        enter => sub {$enter = "Enter Action 2"},
        leave => sub {$leave = "Leave Action 2"},
        goto => [
            first => [sub { $flag == 1 }, sub { $action = "Action 1" }],
            third => [sub { $flag == 3 }, sub { $action = "Action 3" }],
        ],
    },
    third => {
        enter => sub {$enter = "Enter Action 3"},
        leave => sub {$leave = "Leave Action 3"},
        goto => [
            first  => [sub { $flag == 1 }, sub { $action = "Action 1" }],
            second => [sub { $flag == 2 }, sub { $action = "Action 2" }],
        ],
    },
);

$flag = 0;

can_ok $DFA, 'new';
my $fsm = $DFA->new(\%state_machine, 'first', sub{ 'dummy' });
isa_ok $fsm, $DFA => '... and the result';
is $enter, 'Enter Action 1',
    '... and we should enter the first action';
ok !$action,
    '... but no action should be taken yet';
ok !$leave, 
    '... nor should we have left the state';

$flag = 2;
can_ok $fsm, 'next_state';
$fsm->next_state;
is $leave, 'Leave Action 1',
    '... and we should be able to leave the first state';
is $enter, 'Enter Action 2',
    '... and enter the second state';
is $action, 'Action 2',
    '... and perform the desired action';

$flag = 3;
$fsm->next_state;
is $leave, 'Leave Action 2',
    'We should be able to leave the next state';
is $enter, 'Enter Action 3',
    '... and properly enter the next one';
is $action, 'Action 3',
    '... while still performing the appropriate action';

$flag = 1;
$fsm->next_state;
is $leave, 'Leave Action 3',
    'We should be able to leave a state ...';
is $enter, 'Enter Action 1',
    '... for one we have already been in';
is $action, 'Action 1',
    '... and perform the appropriate action';

$flag = 17;
throws_ok {$fsm->next_state}
    qr/Cannot determine state transition from state 'first'/,
    'An illegal state transition should croak';

my ($goto, $count) = ('', 0);
%state_machine = (
    first => {
        enter => sub { $goto = 'last' },
        goto => [
            last => [sub {'last' eq $goto}, sub {$count++}],
        ],
    },
    last => {
        enter => sub { $goto = 'first' },
        goto  => [
            first => [sub {'first' eq $goto}, sub {$count++}],
        ]
    }
);

$fsm = $DFA->new(\%state_machine, 'first', sub { $count >= 20 });

can_ok $fsm, 'done';
$fsm->next_state while ! $fsm->done;
cmp_ok $count, '>=', 20,
    '... and it should be able to tell when the machine is done';
    
%state_machine = (
    first => {
        enter => sub { $goto = 'last' },
        goto => [
            unknown_state_name => [sub {'last' eq $goto}, sub {$count++}],
        ],
    },
);

throws_ok {$fsm = $DFA->new(\%state_machine, 'first', sub { $count >= 20 })}
    qr/Unknown state 'unknown_state_name' referenced in state 'first'/,
    'Attempting to goto an unknown state name should die';
