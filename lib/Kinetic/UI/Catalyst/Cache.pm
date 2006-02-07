package Kinetic::UI::Catalyst::Cache;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or derivatives to
# this work, or any other work intended for use with the Kinetic framework, to
# Kineticode, Inc., you confirm that you are the copyright holder for those
# contributions and you grant Kineticode, Inc.  a nonexclusive, worldwide,
# irrevocable, royalty-free, perpetual license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute those
# contributions and any derivatives thereof.

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

1;

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This work is made available under the terms of Version 2 of the GNU General
Public License. You should have received a copy of the GNU General Public
License along with this program; if not, download it from
L<http://www.gnu.org/licenses/gpl.txt> or write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

This work is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License Version 2 for more
details.

=cut
