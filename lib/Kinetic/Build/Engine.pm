package Kinetic::Build::Engine;

# $Id: Store.pm 2488 2006-01-04 05:17:14Z theory $

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

Kinetic::Build::Engine - Kinetic engine builder

=head1 Synopsis

  use Kinetic::Build::Engine;
  my $kbe = Kinetic::Build::Engine->new;
  $kbe->build;

=head1 Description

This is the base class for building Kinetic engines.

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 engine_class

  my $engine_class = Kinetic::Build::Engine->engine_class;

Returns the engine class necessary to run the engine.

=cut

sub engine_class { die "engine_class() must be overridden in the subclass" }

##############################################################################
# Constructors.
##############################################################################

=head2 Constructors

=head3 new

  my $kbs = Kinetic::Build::Engine->new;
  my $kbs = Kinetic::Build::Engine->new($builder);

Creates and returns a new Engine builder object. Pass in the Kinetic::Build
object being used to validate the engine. If no Kinetic::Build object is
passed, one will be instantiated by a call to C<< Kinetic::Build->resume >>.
This is a factory constructor; it will return the subclass appropriate to the
currently selected store class as configured in F<kinetic.conf>.

=cut

my %private;
sub new {
    my $class = shift;
    my $builder = shift || eval { Kinetic::Build->resume }
      or die "Cannot resume build: $@";

    my $self = bless {actions => []} => $class;
    $private{$self} = {
        builder => $builder,
        #info    => $class->info_class->new($builder->_app_info_params)
    };
    return $self;
}

##############################################################################

=head3 builder

  my $builder = $kbs->builder;

Returns the C<Kinetic::Build> object used to determine build properties.

=cut

sub builder { $private{shift()}->{builder} ||= Kinetic::Build->resume }

##############################################################################

=head3 add_engine_config_to_conf

  $engine->add_engine_config_to_conf(\%conf);

Takes the config hash from C<Kinetic::Build> and adds the necessary
configuration information to run the selected engine.

=cut

sub add_engine_config_to_conf {
    my ( $self, $conf ) = @_;
    my @conf = $self->conf_sections;
    @{ $conf->{ $self->conf_engine } }{@conf} = @{$self}{@conf};
    $conf->{engine} = { class => $self->engine_class };
    return $self;
}

##############################################################################

=head3 validate

  $kbs->validate;

This method will validate the engine. 

=cut

sub validate { die "validate() must be overridden in a subclass" }

1;
__END__

##############################################################################

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
