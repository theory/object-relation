package Kinetic::Build::Setup::Cache::Memcached;

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

use Regexp::Common qw/net/;
use List::MoreUtils qw(any);
use version;
our $VERSION = version->new('0.0.1');

use base 'Kinetic::Build::Setup::Cache';

=head1 Name

Kinetic::Build::Setup::Cache::Memcached - Kinetic Memcached cache builder

=head1 Synopsis

  use Kinetic::Build::Setup::Cache::Memcached;
  my $kbc = Kinetic::Build::Setup::Cache::Memcached->new;
  $kbc->setup;

=head1 Description

This module inherits from Kinetic::Build::Setup::Cache to collect
configuration information for the Kinetic Memcached caching architecture. Its
interface is defined entirely by Kinetic::Build::Setup::Cache. The
command-line options it adds are:

=over

=item memcached-address

=item cache-expires

=back

=cut

##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 catalyst_cache_class

  my $catalyst_cache_class
      = Kinetic::Build::Setup::Cache::Memcached->catalyst_cache_class;

Returns the package name of the Kinetic caching class to be used for caching.

=cut

sub catalyst_cache_class {'Kinetic::UI::Catalyst::Cache::Memcached'}

##############################################################################

=head3 object_cache_class

  my $object_cache_class
      = Kinetic::Build::Setup::Cache::Memcached->object_cache_class;

Returns the package name of the Kinetic caching class to be used for object
caching.

=cut

sub object_cache_class {'Kinetic::Util::Cache::Memcached'}

##############################################################################

=head3 rules

  my @rules = Kinetic::Build::Setup::Cache::Memcached->rules;

Returns a list of arguments to be passed to an L<FSA::Rules|FSA::Rules>
constructor. These arguments are rules that will be used to validate
connectivity to one or more memcached servers, and to collect information for
the configuration of Kinetic caching.

=cut

sub rules {
    my $self = shift;
    return (
        addresses => {
            do => sub {
                my $state    = shift;
                my $builder  = $self->builder;
                my $default  = '127.0.0.1:11211';
                my $check_re = qr/^$RE{net}{IPv4}:\d+$/;

                # Prompt for the addresses.
                my %prompt_params = (
                    name        => 'memcached-address',
                    message     => 'Please enter IP:port for a memcached '
                                 . 'server',
                    label       => 'memcached addresses',
                    default     => $default,
                    callback    => sub { /$check_re/ },
                    config_keys => [qw(cache address)],
                );

                my @addrs;
                my $configured = $builder->accept_defaults
                    || $builder->args( 'memcached-address' );
                ADDR_LOOP: while (1) {
                    if (my $addr = $builder->get_reply(%prompt_params)) {
                        # Can be a scalar or an array reference.
                        $addr = [$addr] unless ref $addr;
                        for my $ad (@$addr) {
                            push @addrs, $ad unless any { $_ eq $ad } @addrs;
                        }
                        last ADDR_LOOP if $configured;
                        $prompt_params{message} =~ s/a\s+mem/another mem/;
                        $prompt_params{default} = '';
                        next ADDR_LOOP;
                    }
                    last ADDR_LOOP
                }
                $self->{addresses} = \@addrs;
            },
            rules => [
                expires => {
                    rule    => 1,
                    message => 'Memcached addresses collected',
                }
            ],
        },

        expires => {
            do => sub {
                $self->_ask_for_expires;
            },
            rules => [
                Done => {
                    rule    => 1,
                    message => 'Cache configuration collected',
                }
            ],
        },

        Done => {
            do => sub {
                shift->done(1);
            }
        },
    );
}

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 add_to_config

 $kbc->add_to_config(\%config);

Adds the cache configuration information to the build config hash. It
overrides the parent implementation to add the memcached address information.

=cut

sub add_to_config {
    my ( $self, $conf ) = @_;
    $self->SUPER::add_to_config($conf);
    $conf->{cache}{address} = $self->addresses;
    return $self;
}

##############################################################################

=head3 addresses

  my $addresses = $kbc->addresses;

Returns an array reference of the addresses to put into F<kinetic.conf>
specifying the addresses for Memcached servers.

=cut

sub addresses { shift->{addresses} }

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
