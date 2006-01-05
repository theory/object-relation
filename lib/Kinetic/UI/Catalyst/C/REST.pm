package Kinetic::UI::Catalyst::C::REST;

use strict;
use warnings;
use base 'Catalyst::Controller';
use aliased 'Kinetic::UI::REST';

use version;
our $VERSION = version->new('0.0.1');

=head1 NAME

Kinetic::UI::Catalyst::C::REST - Catalyst Controller

=head1 SYNOPSIS

See L<Kinetic::UI::Catalyst>

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

##############################################################################

=head2 rest

  $c->forward('Kinetic::UI::Catalyst::C::REST', 'rest');

For a URL in the form C</rest/$rest_parameters>, this method will pull the
appropriate REST information and return it in the form of the first arg after
"rest/" in the URL (currently 'json' or 'xml').

=cut

sub rest : Regex('^rest/(.*)') {
    my ( $self, $c ) = @_;

    # Hello World
    $c->response->body('Kinetic::UI::Catalyst::C::REST is on Catalyst!');
    my $base_url = 'http://localhost:3000/rest/';
    my $rest = REST->new( base_url => $base_url );
    $rest->handle_request( $c->req );
    $c->res->status( $rest->status );
    $c->res->header( 'Content-Type' => 'text/plain' );
    $c->res->content_length( length $rest->response );
    $c->response->body( $rest->response );
}

=head1 AUTHOR

Curtis Poe

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
