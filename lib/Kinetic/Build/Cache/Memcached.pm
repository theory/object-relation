package Kinetic::Build::Cache::Memcached;

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
use version;
our $VERSION = version->new('0.0.1');

use base 'Kinetic::Build::Cache';

=head1 Name

Kinetic::Build::Cache::Memcached - Kinetic cache builder

=head1 Synopsis

This module merely collects the basic information regarding the addresses to
use for C<memcached>.

=head1 Description

See L<Kinetic::Build::Cache|Kinetic::Build::Cache>.

=cut

##############################################################################
# Constructors.
##############################################################################

=head2 Constructors

=head3 new

  my $kbc = Kinetic::Build::Cache->new;
  my $kbc = Kinetic::Build::Cache->new($builder);

Creates and returns a new Cache builder object. Pass in the Kinetic::Build
object being used to validate the cache. If no Kinetic::Build object is
passed, one will be instantiated by a call to C<< Kinetic::Build->resume >>.

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Instance Interface

=head2 Instance Methods

##############################################################################

=head3 validate

  $kbc->validate;

This method collects the various address/port combinations on which
C<memcached> runs.

=cut

sub validate {
    my $self    = shift;
    my $builder = $self->builder;

    if ( $builder->accept_defaults ) {

        # If we don't add this, the build will hang.
        # If they didn't accept defaults, don't assume the IP address of a
        # memcached server because there could be multiple servers and we want
        # them to be able to choose.
        $self->{memcached} = ['127.0.0.1:11211'];
        return $self;
    }

    my %address = (
        name    => 'address',
        message =>
          'Please enter an IP/port in form "$IP:$port" for memcached',
        label => 'memcached address',
    );

    my %memcached;
    while (1) {
        my $address = $builder->get_reply(%address);
        if ($address) {
            unless ( $address =~ /^$RE{net}{IPv4}:\d+$/ ) {
                print STDERR $builder->_bold_red(
                    qq{memcached address must be in the form "\$ip_address:\$port"\n}
                );
                next;
            }
        }
        else {
            last if keys %memcached;    # we have at least one server
            print STDERR $builder->_bold_red(
                "You must enter at least one IP address of a memcached server\n"
            );
            next;
        }
        $memcached{$address} = 1;
    }
    $self->{memcached} = [ keys %memcached ];
    return $self;
}

##############################################################################

=head3 add_to_config

 $kbc->add_to_conf(\%config); 

Adds the cache configuration information to the build config hash.

=cut

sub add_to_config {
    my ( $self, $conf ) = @_;
    $self->SUPER::add_to_config($conf);
    $conf->{memcached} = { addresses => $self->{memcached} };
    return $self;
}

##############################################################################

=head3 cache_class

  my $cache = Kinetic::Build::Cache->cache_class;

Returns the caching class used by the servers.

=cut

sub cache_class {'Kinetic::UI::Catalyst::Cache::Memcached'}

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
