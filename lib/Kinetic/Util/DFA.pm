package Kinetic::Util::DFA;
use strict;
use warnings;
use Carp qw/croak/;
use Sub::Override;

our $VERSION = '0.01';


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
        my $state = $states[$index];
        $rules[$index] = [];
        my @goto = @{ $state_machine->{$state}{goto} };
        while (my ($rule_state, $actions) = splice @goto => 0, 2) {
            push @{$rules[$index]} => [$name_to_index{$rule_state}, @$actions];
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

sub done { $_[0]->{finish}->() }

1;
