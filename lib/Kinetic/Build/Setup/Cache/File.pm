package Kinetic::Build::Setup::Cache::File;

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
use File::Spec::Functions qw(tmpdir catdir);

use base 'Kinetic::Build::Setup::Cache';

=head1 Name

Kinetic::Build::Setup::Cache::File - Kinetic file cache builder

=head1 Synopsis

  use Kinetic::Build::Setup::Cache::File;
  my $kbc = Kinetic::Build::Setup::Cache::File->new;
  $kbc->setup;

=head1 Description

This module inherits from Kinetic::Build::Setup::Cache to collect
configuration information for the Kinetic file-based caching architecture. Its
interface is defined entirely by Kinetic::Build::Setup::Cache. The
command-line options it adds are:

=over

=item cache-root

=item cache-expires

=back

=cut

##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 catalyst_cache_class

  my $catalyst_cache_class
      = Kinetic::Build::Setup::Cache::File->catalyst_cache_class;

Returns the package name of the Kinetic caching class to be used for catalyst
sessions.

=cut

sub catalyst_cache_class {'Kinetic::UI::Catalyst::Cache::File'}

##############################################################################

=head3 object_cache_class

  my $object_cache_class
      = Kinetic::Build::Setup::Cache::File->object_cache_class;

Returns the package name of the Kinetic caching class to be used for object
caching.

=cut

sub object_cache_class {'Kinetic::Util::Cache::File'}

##############################################################################

=head3 rules

  my @rules = Kinetic::Build::Setup::Cache::File->rules;

Returns a list of arguments to be passed to an L<FSA::Rules|FSA::Rules>
constructor. These arguments are rules that will be used to collect
information for the configuration of Kinetic caching.

=cut

sub rules {
    my $self = shift;
    return (
        start => {
            do => sub {
                my $state   = shift;
                my $builder = $self->builder;
                $self->{root} = $builder->args('cache_root')
                    || $builder->get_reply(
                    name        => 'cache-root',
                    message     => 'Please enter the root directory for '
                                 . 'caching',
                    label       => 'Cache root',
                    default     => catdir(tmpdir(), qw(kinetic cache)),
                    callback    => sub { -d },
                    config_keys => [qw(cache root)],
                );
                $self->_ask_for_expires;
                $state->message('Cache configuration collected');
                $state->done(1);
            },
        },
    );
}

##############################################################################

=head1 Instance Interface

=head2 Instance Method

=head3 add_to_config

 $kbc->add_to_config(\%config);

Adds the cache configuration information to the build config hash. It
overrides the parent implementation to add the file cache expiration time and
root directory.

=cut

sub add_to_config {
    my ( $self, $conf ) = @_;
    $self->SUPER::add_to_config($conf);
    $conf->{cache}{root} = $self->root,
    return $self;
}

##############################################################################

=head3 root

  my $root = $kbc->root;

Returns the root directory to use for the cache files. Set by C<validadate()>.

=cut

sub root { shift->{root} }

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
