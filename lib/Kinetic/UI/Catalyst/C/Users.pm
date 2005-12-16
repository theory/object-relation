package Kinetic::UI::Catalyst::C::Users;

use strict;
use warnings;
use base 'Catalyst::Controller';

use version;
our $VERSION = version->new('0.0.1');

=head1 NAME

Kinetic::UI::Catalyst::C::Users - Catalyst Controller

=head1 SYNOPSIS

See L<Kinetic::UI::Catalyst>

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

##############################################################################

=head2 greet

  $c->forward('Kinetic::UI::Catalyst::C::Users', 'greet');

Greets the users.  This is for testing and will be removed.

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

##############################################################################

=head2 end 

Default 'end' action.

=cut

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
