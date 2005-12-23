package Kinetic::UI::Catalyst::C::View;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Kinetic::Util::Constants qw/$UUID_RE/;
use Kinetic::Meta;

use version;
our $VERSION = version->new('0.0.1');

=head1 NAME

Kinetic::UI::Catalyst::C::View - Catalyst Controller

=head1 SYNOPSIS

See L<Kinetic::UI::Catalyst>

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 view

Displays a given Kinetic object

=cut

sub view : Regex('^view/([[:alpha:]]\w*)/(.*)$') {
    my ( $self, $c ) = @_;

    my $key  = $c->request->snippets->[0];
    my $uuid = $c->request->snippets->[1];
    my $class = Kinetic::Meta->for_key($key);
    my $object = $class->package->new->lookup( uuid => $uuid );

    my @attributes;
    foreach my $attr ( $class->attributes ) {
        #next if $attr->acts_as || $attr->references;
        push @attributes => $attr->name;
    }

    $c->stash->{template}   = 'view.tt';
    $c->stash->{class}      = $class;
    $c->stash->{key}        = $key;
    $c->stash->{mode}       = 'view';
    $c->stash->{object}     = $object;
    $c->forward('Kinetic::UI::Catalyst::V::TT');
}

=head1 AUTHOR

Curtis Poe

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
