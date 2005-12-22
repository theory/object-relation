package Kinetic::UI::Catalyst::C::Search;

use strict;
use warnings;
use base 'Catalyst::Controller';

# XXX the following is a temporary cheat, approved by David.  We need the
# Dispatch class's ability to handle arbitrary method calls.  Rather than
# break this into a separate class, we're assuming that Catalyst will
# eventually rely on REST calls and we won't be using a traditional interface.
use aliased 'Kinetic::UI::REST::Dispatch';
use URI::Escape qw/uri_unescape/;

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

sub search : Regex('^search/([[:alpha:]]\w*)(?:/(squery|slookup)(?:/(.*))?)?$') {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'search.tt';
    my $key = $c->request->snippets->[0];
    my @results;
    if ( my $method = $c->request->snippets->[1] ) {
        my @args;
        if ( defined( my $args = $c->request->snippets->[2] ) ) {
            @args = map { uri_unescape($_) } split /\/_?/ => $args;
        }
        push @results => {
            method => $method,
            args   => \@args,
        };
        my $dispatch = Dispatch->new; # XXX see the comment at the top
        $dispatch->class_key($key);
        my $iterator = $dispatch->_execute_method( $method, @args );
        while ( my $result = $iterator->next ) {
            push @results => $result;
        }
    }
    $c->stash->{key}  = $key;
    $c->stash->{path} = '/';    # XXX just for now ...
    if ( my $class = Kinetic::Meta->for_key($key) ) {
        $c->stash->{class} = $class;
    }
    $c->stash->{mode} = 'search';
    $c->stash->{debug} = [ $c->request->snippets, \@results ];
    $c->forward('Kinetic::UI::Catalyst::V::TToolkit');
}

=head1 AUTHOR

Curtis Poe

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
