package Kinetic::Build::Engine;

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

Kinetic::Build::Engine - Kinetic engine builder

=head1 Synopsis

  use Kinetic::Build::Engine;
  my $kbe = Kinetic::Build::Engine->new;
  $kbe->setup;

=head1 Description

This is the base class for setting up Kinetic engines. It inherits from
L<Kinetic::Build::Setup|Kinetic::Build::Setup>.

=cut

##############################################################################

##############################################################################
# Constructors.
##############################################################################

=head1 Interface

=head2 Constructors

=head3 new

  my $kbe = Kinetic::Build::Engine->new;
  my $kbe = Kinetic::Build::Engine->new($builder);

This constructor overrides the one inherited from
L<Kinetic::Build::Setup|Kinetic::Build::Setup> to set the C<base_uri>
attribute to its default value, '/'.

=cut

# XXX This shouldn't be necessary, actually. Apache should be able to
# figure it out.

sub new {
    my $self = shift->SUPER::new(@_);
    $self->{base_uri} = '/';
    return $self;
}

##############################################################################

=head2 Instance Methods

=head3 base_uri

  my $base_uri = $kbe->base_uri;
  $kbe->base_uri($base_uri);

Returns the base URI to be used for all Kinetic applications. Must be set by a
subclass during the execution of C<validate()>.

=cut

sub base_uri {
    my $self = shift;
    return $self->{base_uri} unless @_;
    $self->{base_uri} = shift;
    return $self;
}

##############################################################################

=head3 add_to_config

  $engine->add_to_config(\%conf);

Takes the config hash from C<Kinetic::Build> and adds the necessary
configuration information to run the selected engine.

=cut

sub add_to_config {
    my ( $self, $conf ) = @_;
    my $engine = $self->conf_engine;
    $conf->{$engine}{$_} = $self->$_ for $self->conf_sections;
    $conf->{engine} = { class => $self->engine_class };
    $conf->{kinetic}{base_uri} = $self->base_uri;
    return $self;
}

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
