package Kinetic::UI::Catalyst::Cache;

use strict;
use warnings;

use Kinetic::Util::Config qw(CACHE_CLASS);
use Kinetic::Util::Exceptions qw/throw_unknown_class throw_unimplemented/;

use version;
our $VERSION = version->new('0.0.1');

=head1 NAME

Kinetic::UI::Catalyst::Cache - Catalyst caching for the Kinetic Platform

=head1 SYNOPSIS

  my $cache         = Kinetic::UI::Catalyst::Cache->new;
  my $session_class = $cache->session_class;
  my $config        = $cache->config;

=head1 DESCRIPTION

Returns a cache configuration object for managing sessions in Catalyst.

=head1 METHODS

=head2 new

  my $cache = Kinetic::UI::Catalyst::Cache->new;

Returns a new cache object for whatever caching style was selected by the
user.

=cut

sub new {
    my $class       = shift;
    my $cache_class = CACHE_CLASS;
    eval "require $cache_class"
      or throw_unknown_class [
        'I could not load the class "[_1]": [_2]',
        $cache_class,
        $@
      ];
    bless {}, $cache_class;
}

##############################################################################

=head3 config

  my $config = $cache->config;

Returns the configuration information needed for the
L<Kinetic::UI::Catalyst|Kinetic::UI::Catalyst> configuration.

=cut

sub config {
    throw_unimplemented [
        '"[_1]" must be overridden in a subclass',
        'config'
    ];
}

##############################################################################

=head3 session_class

  my $session_class = $cache->session_class;

Returns the name of the Catalyst plugin class which handles sessions.

=cut

sub session_class { 
    throw_unimplemented [
        '"[_1]" must be overridden in a subclass',
        'session_class'
    ];
}

=head1 AUTHOR

Curtis Poe

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
