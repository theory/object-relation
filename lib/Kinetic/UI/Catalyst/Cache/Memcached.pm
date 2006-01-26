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

See L<Kinetic::UI::Catalyst::Cache|Kinetic::UI::Catalyst::Cache>.

=head1 OVERRIDDEN METHODS

This methods are described in 
L<Kinetic::UI::Catalyst::Cache|Kinetic::UI::Catalyst::Cache>.  The are listed
her to shut up the pod coverage tests.

=over 4

=item * C<config>

=item * C<session_class>

=back

=cut

sub config {
    return session => {
        memcached_new_args => {
            data => MEMCACHED_ADDRESSES,
        }
    };
}

sub session_class { 'Session::Store::Memcached' }

=head1 AUTHOR

Curtis Poe

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
