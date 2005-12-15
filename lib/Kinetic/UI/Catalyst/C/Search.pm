package Kinetic::UI::Catalyst::C::Search;

use strict;
use warnings;
use base 'Catalyst::Controller';

=head1 NAME

Kinetic::UI::Catalyst::C::Search - Catalyst Controller

=head1 SYNOPSIS

See L<Kinetic::UI::Catalyst>

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

#
# Uncomment and modify this or add new actions to fit your needs
#
#=head2 default
#
#=cut
#
#sub default : Private {
#    my ( $self, $c ) = @_;
#
#    # Hello World
#    $c->response->body('Kinetic::UI::Catalyst::C::Search is on Catalyst!');
#}

sub search : Regex('^search/([[:alpha:]][[:word:]]*)$') {
    my ( $self, $c ) = @_;

    $c->stash->{template}   = 'search.tt';
    my $key = $c->request->snippets->[0];
    $c->stash->{search_key} = $key;
    if (my $class = Kinetic::Meta->for_key($key)) {
        $c->stash->{class} = $class;
    }
    $c->forward('Kinetic::UI::Catalyst::V::TToolkit');
}

=head1 AUTHOR

Curtis Poe

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
