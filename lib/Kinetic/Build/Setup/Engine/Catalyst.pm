package Kinetic::Build::Setup::Engine::Catalyst;

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

use base 'Kinetic::Build::Setup::Engine';

=head1 Name

Kinetic::Build::Setup::Engine::Catalyst - Kinetic Catalyst engine builder

=head1 Synopsis

See L<Kinetic::Build::Setup::Engine|Kinetic::Build::Setup::Engine>.

=head1 Description

This module inherits from Kinetic::Build::Setup::Engine to build a Catalyst engine.
Its interface is defined entirely by Kinetic::Build::Setup::Engine. The command-line
options it adds are:

=over

=item catalyst-port

=item catalyst-host

=item catalyst-restart

=back

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 engine_class

  my $engine_class = Kinetic::Build::Setup::Engine::Catalyst->engine_class;

Returns the engine class which C<bin/kineticd> will use to start the engine.

=cut

sub engine_class {'Kinetic::Engine::Catalyst'}

##############################################################################

=head3 rules

  my @rules = Kinetic::Build::Setup::Engine::Catalyst->rules;

Returns a list of arguments to be passed to an L<FSA::Rules|FSA::Rules>
constructor. These arguments are rules that will be used to validate the
installation of Catalyst and to collect information to configure it for use by
TKP.

=cut

sub rules {
    my $self = shift;

    return (
        start => {
            do => sub {
                my $state   = shift;
                my $builder = $self->builder;
                $self->{port} = $builder->args('catalyst_port')
                    || $builder->get_reply(
                    name        => 'catalyst-port',
                    message     => 'Please enter the port on which to run '
                                 . 'the Catalyst server',
                    label       => 'Catalyst port',
                    default     => 3000,
                    config_keys => [qw(engine port)],
                );
                $self->{host} = $builder->args('catalyst_host')
                    || $builder->get_reply(
                    name        => 'catalyst-host',
                    message     => 'Please enter the hostname on which the '
                                 . 'Catalyst server will run',
                    label       => 'Catalyst host',
                    default     => 'localhost',
                    config_keys => [qw(engine host)],
                );
                $self->{restart} = $builder->args('catalyst_restart')
                    || $builder->ask_y_n(
                    name        => 'catalyst-restart',
                    message     => 'Should the Catalyst server automatically '
                                 . 'restart if .pm files change?',
                    label       => 'Catalyst restart',
                    default     => 0,
                    config_keys => [qw(engine restart)],
                );
                $state->message('Catalyst configuration collected');
                $state->done(1);
            },
        },
    );
}

##############################################################################

=head3 conf_engine

  my $engine_type = Kinetic::Build::Setup::Engine::Catalyst->conf_engine;

Returns the engine type corresponding to the config file section ('simple');

=cut

sub conf_engine {'catalyst'}

=head3 conf_sections

  my @conf_sections = Kinetic::Build::Setup::Engine::Catalyst->conf_sections;

Returns the configuration sections to be copied to the config file
C<conf_engine> section.

=cut

sub conf_sections {qw/port host restart/}

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Instance Accessors

=head3 port

  my $port = $catalyst->port;

Returns the port number on which the Catalyst Web server should be run. Set by
C<validate()>. Defaults to 3000.

=cut

sub port { shift->{port} }

##############################################################################

=head3 host

  my $host = $catalyst->host;

Returns the host name for the server on which the Catalyst Web server wiil be
run. Set by C<validate()>. Defaults to "localhost".

=cut

sub host    { shift->{host} }

##############################################################################

=head3 restart

  my $restart = $catalyst->restart;

Returns true if the Catalyst Web server should automatically restart whenever
it detects that a Perl module has been updated, and false if it should not.
Set by C<validate()>. Defaults to false.

=cut

sub restart { shift->{restart} }

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

