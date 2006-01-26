package Kinetic::Build::Cache;

# $Id: SQLite.pm 2493 2006-01-06 01:58:37Z curtis $

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

=head1 Name

Kinetic::Build::Cache - Kinetic cache builder

=head1 Synopsis

This module merely collects the basic information regarding the addresses to
use for C<memcached>.

=head1 Description

XXX

=cut

##############################################################################
# Constructors.
##############################################################################

=head2 Constructors

=head3 new

  my $kbs = Kinetic::Build::Cache->new;
  my $kbs = Kinetic::Build::Cache->new($builder);

Creates and returns a new Cache builder object. Pass in the Kinetic::Build
object being used to validate the cache. If no Kinetic::Build object is
passed, one will be instantiated by a call to C<< Kinetic::Build->resume >>.

=cut

my %private;
sub new {
    my $class = shift;
    my $builder = shift || eval { Kinetic::Build->resume }
      or die "Cannot resume build: $@";

    my $self = bless {actions => []} => $class;
    $private{$self} = {
        builder => $builder,
    };
    return $self;
}

##############################################################################
# Class Methods.
##############################################################################

=head1 Instance Interface

=head2 Instance Methods

##############################################################################

=head3 builder

  my $builder = $kbs->builder;

Returns the C<Kinetic::Build> object used to determine build properties.

=cut

sub builder { $private{shift()}->{builder} ||= Kinetic::Build->resume }

##############################################################################

=head3 validate

  $kbs->validate;

This method will validate the engine. 

=cut

sub validate { die "validate() must be overridden in a subclass" }

##############################################################################

=head3 add_to_config

 $kbc->add_to_conf(\%config); 

Adds the cache configuration information to the build config hash.

=cut

sub add_to_config {
    my ( $self, $conf ) = @_;
    $conf->{cache} = { class => $self->cache_class };
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

