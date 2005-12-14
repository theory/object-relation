package Kinetic::UI::Catalyst::C::Users;

use strict;
use warnings;
use base 'Catalyst::Controller';

=head1 NAME

Kinetic::UI::Catalyst::C::Users - Catalyst Controller

=head1 SYNOPSIS

See L<Kinetic::UI::Catalyst>

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub greet : Local {
    my ( $self, $context ) = @_;

    my $name = $context->user->id;

    if ( !$name ) {
        $context->stash->{message} =
          "Couldn't figure out the name.  session problem?";
    }
    else {
        $context->stash->{message} = "Hello, $name";
    }
    $context->stash->{template} = 'greet.tt';
}

sub end : Private {
    my ( $self, $context ) = @_;
    $context->forward("Kinetic::UI::Catalyst::V::TToolkit");
}

=head1 AUTHOR

Curtis Poe

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
