package Kinetic::Build::Engine::Apache2;

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

use base 'Kinetic::Build::Engine';

=head1 Name

Kinetic::Build::Engine::Apache2 - Kinetic Apache2 engine builder

=head1 Synopsis

See L<Kinetic::Build::Engine|Kinetic::Build::Engine>.

=head1 Description

This module inherits from Kinetic::Build::Engine to build an Apache2 engine.
Its interface is defined entirely by Kinetic::Build::Engine. The command-line
options it adds are:

=over

=item group

=item httpd

=item port

=item user

=item rest_root

=item engine_root

=back

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 engine_class

  my $engine_class = Kinetic::Build::Engine::Apache2->engine_class;
  
Returns the engine class which C<bin/kineticd> will use to start the engine.

=cut

sub engine_class {'Kinetic::Engine::Apache2'}

##############################################################################

=head3 validate

  Kinetic::Build::Engine::Apache2->validate;

This method validates the requirements necessary to run the selected engine.

=cut

# XXX Eventually we'll convert this to FSA::Rules.  At this time we're not
# doing this as there is no App::Info module for Apache2

sub validate {
    my $self    = shift;
    my $builder = $self->builder;

    $self->_set_httpd;
    $self->_set_httpd_conf;

    $self->{root} = $builder->args('root')
      || $builder->get_reply(
        name    => 'root',
        message => 'Please enter the kinetic app root path',
        label   => 'Server kinetic_root',
        default => '/kinetic'
      );
    $self->{rest} = $builder->args('rest')
      || $builder->get_reply(
        name    => 'rest',
        message => 'Please enter the kinetic app rest path',
        label   => 'Server kinetic_rest',
        default => '/kinetic/rest'
      );
    $self->{static} = $builder->args('static')
      || $builder->get_reply(
        name    => 'static',
        message => 'Please enter the kinetic app static files path',
        label   => 'Server kinetic_static',
        default => '/'
      );

    return $self;
}

##############################################################################

=head3 conf_engine

  my $engine_type = Kinetic::Build::Engine::Catalyst->conf_engine;

Returns the engine type corresponding to the config file section ('simple');

=cut

sub conf_engine {'apache'}

##############################################################################

=head3 conf_sections

  my @conf_sections = Kinetic::Build::Engine::Catalyst->conf_sections;

Returns the configuration sections to be copied to the config file
C<conf_engine> section.

=cut

sub conf_sections {
    qw/
      group
      httpd
      httpd_conf
      port
      rest
      root
      static
      user
      /;
}

sub _set_httpd {
    my $self    = shift;
    my $builder = $self->builder;

    while ( !$self->{httpd} ) {
        $self->{httpd} = $builder->args('httpd')
          || $builder->get_reply(
            name    => 'httpd',
            message =>
              'Please enter the httpd executable for the apache server',
            label   => 'Server httpd',
            default => '/usr/local/apache/bin/httpd'
          );
        if ( !-f $self->{httpd} ) {
            warn "($self->{httpd}) does not appear to exist\n";
            delete $self->{httpd};
        }
    }
    return $self;
}

sub _set_httpd_conf {
    my $self    = shift;
    my $builder = $self->builder;

    while ( !$self->{httpd_conf} ) {
        $self->{httpd_conf} = $builder->args('httpd_conf')
          || $builder->get_reply(
            name    => 'httpd_conf',
            message =>
              'Please enter the httpd.conf for the apache server',
            label   => 'Server httpd_conf',
            default => '/usr/local/apache/conf/httpd.conf'
          );
        if ( !-f $self->{httpd_conf} ) {
            warn "($self->{httpd_conf}) does not appear to exist\n";
            delete $self->{httpd_conf};
        }
    }
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

