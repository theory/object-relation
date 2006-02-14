package Kinetic::Build::Setup::Cache;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with the
# Kinetic framework, to Kineticode, Inc., you confirm that you are the
# copyright holder for those contributions and you grant Kineticode, Inc.
# a nonexclusive, worldwide, irrevocable, royalty-free, perpetual license to
# use, copy, create derivative works based on those contributions, and
# sublicense and distribute those contributions and any derivatives thereof.

use strict;

use version;
our $VERSION = version->new('0.0.1');
use base 'Kinetic::Build::Setup';

=head1 Name

Kinetic::Build::Setup::Cache - Kinetic cache builder

=head1 Synopsis

  use Kinetic::Build::Setup::Cache;
  my $kbc = Kinetic::Build::Setup::Cache->new;
  $kbc->setup;

=head1 Description

This module is the abstract base class for collecting information for the
Kinetic caching engine. It inherits from
L<Kinetic::Build::Setup|Kinetic::Build::Setup>.

=cut

##############################################################################

=head1 Interface

=head2 Class Methods

=head3 catalyst_cache_class

  my $catalyst_cache_class
      = $Kinetic::Build::Setup::Cache->catalyst_cache_class;

This method returns the engine class responsible for managing the Catalyst UI
session cache. Must be overidden by a subclass.

=cut

sub catalyst_cache_class {
    die 'catalyst_cache_class() must be overridden in a subclass';
}

##############################################################################

=head3 object_cache_class

  my $object_cache_class
      = $Kinetic::Build::Setup::Cache->object_cache_class;

This method returns the engine class responsible for managing the Kinetic
store cache. Must be overidden by a subclass.

=cut

sub object_cache_class {
    die 'object_cache_class() must be overridden in a subclass';
}

##############################################################################

=head2 Instance Methods

=head3 expires

  my $expires = $kbc->expires;
  $kbc->expires($expires);

Returns the minimum number of seconds before items in the cache should be
expired. Defaults to 3600.

=cut

sub expires {
    my $self = shift;
    return $self->{expires} || 3600 unless @_;
    $self->{expires} = shift;
    return $self;
}

##############################################################################

=head3 add_to_config

 $kbc->add_to_conf(\%config);

Adds the cache configuration information to the build config hash. Called
during the build to set up the caching configuration directives to be used by
the Kinetic caching architecture at run time.

=cut

sub add_to_config {
    my ( $self, $conf ) = @_;
    $conf->{cache} = {
        catalyst     => $self->catalyst_cache_class,
        object_class => $self->object_cache_class,
        expires      => $self->expires,
    };
    return $self;
}

sub _ask_for_expires {
    my $self = shift;
    my $builder = $self->builder;
    return $self->expires(
        $builder->args('cache_expires') || $builder->get_reply(
            name     => 'cache-expires',
            message  => 'Please enter cache expiration time in seconds',
            label    => 'Cache expiration time',
            default  => 3600,
            callback => sub { /^\d+$/ },
        )
    );
}

1;
__END__

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
