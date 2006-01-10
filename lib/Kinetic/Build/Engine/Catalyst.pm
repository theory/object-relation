package Kinetic::Build::Engine::Catalyst;

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

Kinetic::Build::Engine::Catalyst - Kinetic Catalyst engine builder

=head1 Synopsis

See L<Kinetic::Build::Engine|Kinetic::Build::Engine>.

=head1 Description

This module inherits from Kinetic::Build::Engine to build a Catalyst server.
Its interface is defined entirely by Kinetic::Build::Engine. The command-line
options it adds are:

=over

=item port

=item host

=item restart

=back

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 server_class

  my $server_class = Kinetic::Build::Engine::Catalyst->server_class;
  
Returns the server class which C<bin/kineticd> will use to start the server.

=cut

sub server_class {'Kinetic::Engine::Catalyst'}

##############################################################################

=head3 validate

  Kinetic::Build::Engine::Catalyst->validate;

This method validates the requirements necessary to run the selected engine.

=cut

sub validate {
    my $self    = shift;
    my $builder = $self->builder;

    $self->{port} = $builder->args('port')
      || $builder->get_reply(
        name    => 'port',
        message => 'Please enter the port to run the server on',
        label   => 'Server port',
        default => 3000
      );
    $self->{host} = $builder->args('host')
      || $builder->get_reply(
        name    => 'host',
        message => 'Please enter the hostname for the server',
        label   => 'Server host',
        default => 'localhost'
      );
    $self->{restart} = $builder->args('restart')
      || $builder->get_reply(
        name    => 'restart',
        message =>
          'Should the server automatically restart if .pm files change?',
        label   => 'Server restart',
        default => 'no'
      );

    $self->{restart} ||= 0;
    $self->{restart} = ( 'y' eq lc substr $self->{restart}, 0, 1 ) ? 1 : 0;
    return $self;
}

##############################################################################

=head3 conf_server

  my $server_type = Kinetic::Build::Engine::Catalyst->conf_server;

Returns the server type corresponding to the config file section ('simple');

=cut

sub conf_server {'simple'}

##############################################################################

=head3 conf_sections

  my @conf_sections = Kinetic::Build::Engine::Catalyst->conf_sections;

Returns the configuration sections to be copied to the config file
C<conf_server> section.

=cut

sub conf_sections {qw/port host restart/}

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Instance Accessors

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

