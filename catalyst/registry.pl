#!/usr/bin/perl

use strict;
use warnings;

use aliased 'Kinetic::UI::Catalyst';

Catalyst->handle_request( Apache2::RequestUtil->request );

__END__

=head1 NAME

C<registry.pl>

=head1 DESCRIPTION

A small Apache::Registry script for testing the Kinetic Catalyst system
