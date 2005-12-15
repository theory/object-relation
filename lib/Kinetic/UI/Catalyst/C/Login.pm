package Kinetic::UI::Catalyst::C::Login;

use strict;
use warnings;
use base 'Catalyst::Controller';

=head1 NAME

Kinetic::UI::Catalyst::C::Login - Catalyst Controller

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

sub login : Local {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'login.tt';
    $c->session->{referer} ||= $c->req->path;
    if ( !$c->login() ) {
        $c->log->debug('login failed');
        $c->stash->{message} = 'Login failed.';
        $c->forward('Kinetic::UI::Catalyst::V::TToolkit');
    }
    else {
        if ( $c->session->{referer} =~ m{^/?login} ) {
            $c->session->{referer} = '/';
        }
        $c->log->debug('login succeeded');
        $c->res->redirect( $c->session->{referer} || '/' );
    }
}

=head1 AUTHOR

Curtis Poe

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
