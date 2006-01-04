package Kinetic::UI::Catalyst::V::TT;

use strict;
use base 'Catalyst::View::TT';

use version;
our $VERSION = version->new('0.0.1');

# Disable the TT timer
# http://search.cpan.org/dist/Catalyst/lib/Catalyst/Manual/FAQ.pod#How_can_I_get_rid_of_those_timer_comments_when_using_TT_as_my_view%3F

__PACKAGE__->config->{CONTEXT} = undef;

#sub process : Private {
#    my $self = shift;
#    use Data::Dumper;
#    $_[0]->log->debug(Dumper($self->template));
#    $self->NEXT::process(@_);
#}

=head1 NAME

Kinetic::UI::Catalyst::V::TT - TT View Component

=head1 SYNOPSIS

See L<Kinetic::UI::Catalyst>

=head1 DESCRIPTION

TT View Component.

=head1 AUTHOR

Curtis Poe

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;
