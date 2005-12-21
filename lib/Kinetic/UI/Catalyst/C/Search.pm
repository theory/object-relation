package Kinetic::UI::Catalyst::C::Search;

use strict;
use warnings;
use base 'Catalyst::Controller';

use version;
our $VERSION = version->new('0.0.1');

=head1 NAME

Kinetic::UI::Catalyst::C::Search - Catalyst Controller

=head1 SYNOPSIS

See L<Kinetic::UI::Catalyst>

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

##############################################################################

=head2 search

  $c->forward('Kinetic::UI::Catalyst::C::Search', 'search');

For a URL in the form C</search/$class_key>, this method will set the search
template and class key.

=cut

sub search : Regex('^search/([[:alpha:]][[:word:]]*)$') {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'search.tt';
    my $key = $c->request->snippets->[0];
    $c->stash->{key}  = $key;
    $c->stash->{path} = '/';    # XXX just for now ...
    if ( my $class = Kinetic::Meta->for_key($key) ) {
        $c->stash->{class} = $class;
    }
    $c->stash->{mode} = 'search';
    $c->forward('Kinetic::UI::Catalyst::V::TToolkit');
}

=head1 AUTHOR

Curtis Poe

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
