package Kinetic::UI::Catalyst::Cache::Memcached;

use strict;
use warnings;

use Kinetic::Util::Config qw(MEMCACHED_ADDRESSES);

use version;
our $VERSION = version->new('0.0.1');
use base 'Kinetic::UI::Catalyst::Cache';

=head1 NAME

Kinetic::UI::Catalyst::Cache::Memcached - memcached session configuration

=head1 SYNOPSIS

  my @config = Kinetic::UI::Catalyst::Cache::Memcached->config;

=head1 DESCRIPTION

Returns the C<memcached> configuration for Catalyst.  This is not a Catalyst
component.  This is a helper module called once at compile time.

=head1 METHODS

=head2 config

=cut

sub config {
    return session => {
        memcached_new_args => {
            data => MEMCACHED_ADDRESSES,
        }
    };
}

##############################################################################

=head3 session_class

  my $session_class = Kinetic::UI::Catalyst::Cache::Memcached->session_class;

Returns the Catalyst plugin class which handles sessions.

=cut

sub session_class { 'Session::Store::Memcached' }

=head1 AUTHOR

Curtis Poe

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
