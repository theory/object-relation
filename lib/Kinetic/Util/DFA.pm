package Kinetic::Util::DFA;
# $Id$


# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or derivatives to
# this work, or any other work intended for use with the Kinetic framework, to
# Kineticode, Inc., you confirm that you are the copyright holder for those
# contributions and you grant Kineticode, Inc.  a nonexclusive, worldwide,
# irrevocable, royalty-free, perpetual license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute those
# contributions and any derivatives thereof.

use strict;
use warnings;
use Carp qw/croak/;
use Sub::Override;

our $VERSION = '0.01';

=head1 Name

Kinetic::Util::DFA - Kinetic DFA Engine

=head1 Synopsis

  use Kinetic::Util::DFA;
  my $dfa = Kinetic::Util::DFA->new(
    \%state_machine, 
    $initial_state,
    sub { $finish },
  );

  $dfa->next_state while ! $dfa->done;
  
=head1 Description

This module provides an easy to use DFA engine.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $dfa = Kinetic::Util::DFA->new(
    \%state_machine, 
    $initial_state,
    sub { $finish },
  );

This method takes a hash of states, the name of the initial state and an
anonymous sub defining the terminal condition.

The hash keys are the names of the states.  Each state must have, at an entry
subroutine and a "goto" key with a list of rules for state transitions.  Each
item in the list must have a valid state name as the first argument and an
arrayref with the first argument being a subroutine that must evaluate as true
for that state to be entered and a second subroutine that defines an action to
be taken when the sub exits.  A "leave" condition may also be specified for the
state.

See the L<EXAMPLE|"EXAMPLE"> to understand the data structure.

=cut

sub new {
    my ($class, $state_machine, $start, $finish) = @_;
    return $class->_init($state_machine, $start, $finish);
}

sub _init {
    my ($class, $state_machine, $start, $finish) = @_;
    my @states = keys %$state_machine;
    unless (exists $state_machine->{$start}) {
        croak "Start state ($start) not defined in states: ".join ',' => @states;
    }
    unless ('CODE' eq ref $finish) {
        croak "Your finish condition is not a subroutine.";
    }
    my @transitions;
    my (%index_to_name, %name_to_index);
    foreach my $index (0 .. $#states) {
        my $state = $states[$index];
        $transitions[$index] = [
            $state_machine->{$state}{enter},
            $state_machine->{$state}{leave}
        ];
        $name_to_index{$state} = $index;
        $index_to_name{$index} = $state;
    }
    my @rules;
    foreach my $index (0 .. $#states) {
        my $current_state = $states[$index];
        $rules[$index] = [];
        my @goto = @{ $state_machine->{$current_state}{goto} || [] };
        while (my ($goto_state, $actions) = splice @goto => 0, 2) {
            unless (exists $state_machine->{$goto_state}) {
                croak "Unknown state '$goto_state' referenced in state '$current_state'";
            }
            push @{$rules[$index]} => [$name_to_index{$goto_state}, @$actions];
        }
    }

    require DFA::Simple;
    my $self = bless {
        dfa    => DFA::Simple->new(\@transitions, \@rules),
        finish => $finish,
        names  => \%index_to_name,
    } => $class;
    my $start_index = $name_to_index{$start};
    $self->{dfa}->State($start_index);
    return $self;
}

##############################################################################

=head1 Instance Interface

=head2 next_state

Takes no arguments.  Attempts to transform machine to the next state.  If it 
cannot determine the state, it will C<croak()> with an error message listing
the state it was attempting to leave.

=cut

sub next_state {
    my $self = shift;
    # I am not happy with the author of DFA::Simple
    my $sub;
    $sub = Sub::Override->new(
        'DFA::Simple::croak' => sub {
            my $message = shift;
            if ($message =~ /unusual circumstances/i) {
                my $state_index = $self->{dfa}[0];
                my $state = $self->{names}{$state_index};
                $message = "Cannot determine state transition from state '$state'";
            }
            croak $message;
        }
    );
    $self->{dfa}->Check_For_NextState;
}

##############################################################################

=head2 done

Takes no arguments.  This merely executes the anonymous sub passed to the
constructor and returns the result.

=cut

sub done { $_[0]->{finish}->() }

1;

__END__

=head1 EXAMPLE

The following defines a state machine with two nodes that keep calling each
other.  It will "hit" the ball 20 times before terminating.

 my ($goto, $count) = ('', 0);
 %state_machine = (
     ping => {
         enter => sub { $goto = 'pong' },
         leave => sub { warn "leaving state 'ping'" },
         goto => [
             pong => [sub {'pong' eq $goto}, sub {$count++}],
         ],
     },
     pong => {
         enter => sub { $goto = 'ping' },
         leave => sub { warn "leaving state 'pong'" },
         goto  => [
             ping => [sub {'ping' eq $goto}, sub {$count++}],
         ]
     }
 );
 my $dfa = Kinetic::Util::DFA->new(\%state_machine, 'ping', sub {$count >= 20);
 $dfa->next_state while ! $dfa->done;

=cut
