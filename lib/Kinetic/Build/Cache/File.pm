package Kinetic::Build::Cache::File;

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

use base 'Kinetic::Build::Cache';

=head1 Name

Kinetic::Build::Cache::File - Kinetic file cache builder

=head1 Synopsis

  use Kinetic::Build::Cache::File;
  my $kbc = Kinetic::Build::Cache::File->new;
  $kbc->setup;

=head1 Description

See L<Kinetic::Build::Cache|Kinetic::Build::Cache>.

=cut

##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 catalyst_cache_class

  my $cache = Kinetic::Build::Cache->catalyst_cache_class;

Returns the package name of the Kinetic caching class to be used for caching.

=cut

sub catalyst_cache_class {'Kinetic::UI::Catalyst::Cache::File'}

##############################################################################

=head3 kinetic_cache_class

  my $cache = Kinetic::Build::Cache->kinetic_cache_class;

Returns the package name of the Kinetic caching class to be used for caching.

=cut

sub kinetic_cache_class {'Kinetic::Util::Cache::File'}

##############################################################################

=head1 Instance Interface

=head2 Instance Method

=head3 validate

  Kinetic::Build::Cache->validate;

This method overrides the parent implementation to simply return true, since
no data needs to be collected for file caching.

=cut

sub validate {
    my $self    = shift;
    my $builder = $self->builder;

    my $root = $builder->get_reply(
        name    => 'cache_root',
        message => 'Please enter the root directory for caching',
        label   => 'Cache root',
        default => '/tmp/session',
    );
    $self->{cache_root} = $root;

    my $expires = $builder->get_reply(
        name    => 'cache_expires',
        message => 'Please enter cache expiration time in seconds',
        label   => 'Cache expiration time',
        default => 3600,
    );
    $self->{cache_expires} = $expires;
    return $self;
}

##############################################################################

=head3 add_to_config

 $kbc->add_to_config(\%config);

Adds the cache configuration information to the build config hash. It
overrides the parent implementation to add the file cache expiration time and
root directory.

=cut

sub add_to_config {
    my ( $self, $conf ) = @_;
    $self->SUPER::add_to_config($conf);
    $conf->{cache_file} = {
        root    => $self->{cache_root},
        expires => $self->{cache_expires},
    };
    return $self;
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

