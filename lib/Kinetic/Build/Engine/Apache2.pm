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
use App::Info::HTTPD::Apache;

=head1 Name

Kinetic::Build::Engine::Apache2 - Kinetic Apache2 engine builder

=head1 Synopsis

See L<Kinetic::Build::Engine|Kinetic::Build::Engine>.

=head1 Description

This module inherits from Kinetic::Build::Engine to build an Apache2 engine.
Its interface is defined entirely by Kinetic::Build::Engine. The command-line
options it adds are:

=over

=item path-to-httpd

=item path-to-apxs

=item base_uri

=back

=cut

##############################################################################
# Class Methods.
##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 info_class

  my $info_class = Kinetic::Build::Store::Engine::Apache2->info_class

Returns the name of the C<App::Info> class that detects the presences of
SQLite, L<App::Info::HTTPD::Apache|App::Info::HTTPD::Apache>.

=cut

sub info_class { 'App::Info::HTTPD::Apache' }

##############################################################################

=head3 min_version

  my $version = Kinetic::Build::Store::DB::SQLite->min_version

Returns the minimum required version number of SQLite that must be installed.

=cut

sub min_version { '2.0.54' }

##############################################################################

=head3 engine_class

  my $engine_class = Kinetic::Build::Engine::Apache2->engine_class;

Returns the engine class which C<bin/kineticd> will use to start the engine.

=cut

sub engine_class {'Kinetic::Engine::Apache2'}

##############################################################################

=head3 rules

  my @rules = Kinetic::Build::Store::DB::SQLite->rules;

This method returns the rules required by the C<Kinetic::Build::Rules>
state machine.

=cut

sub rules {
    my $self = shift;

    my $fail    = sub {! shift->result };
    my $succeed = sub {  shift->result };

    return (
        start => {
            do => sub {
                my $state = shift;
                my $info = $self->info;
                if ($info->installed) {
                    $self->{httpd} = $info->httpd;
                    $state->result(1);
                }
            },
            rules => [
                fail => {
                    rule    => $fail,
                    message => 'Apache 2 does not appear to be installed',
                },
                check_version => {
                    rule    => $succeed,
                    message => 'Apache is installed',
                },
            ],
        },
        check_version => {
            do => sub {
                my $state = shift;
                return $state->result(1) if $self->is_required_version;
                $state->result(0);
                my $req = version->new($self->min_version);
                my $got = version->new($self->info->version);
                my $exe = $self->info->executable;
                $state->message(
                    "I require Apache $req but found $exe, which is $got.\n"
                  . 'Use --path-to-httpd to specify a different Apache 2 '
                  . 'executable'
                );
            },
            rules  => [
                fail => {
                    rule    => $fail,
                },
                check_mod_perl => {
                    rule    => $succeed,
                    message => 'Apache 2 is the minimum required version',
                }
            ],
        },
        check_mod_perl => {
            do => sub {
                my $state = shift;
                my $info  = $self->info;
                unless ($info->mod_perl) {
                    my $exe = $info->executable;
                    return $state->message(
                        "I found $exe, but it does not appear to include "
                      . "mod_perl support"
                    );
                }

                # mod_perl support is included.
                my $version = eval {
                    require mod_perl2;
                    return version->new($mod_perl2::VERSION_TRIPLET);
                };

                if ($@ || !$version) {
                    # Looks like there was a problem loading mod_perl.
                    return $state->message(
                        "I could not load mod_perl2" . $@ ? ": $@" : ''
                    );
                }

                my $req = version->new('2.0.0');
                return $state->result(1) if $version >= $req;

                # Wrong version of mod_perl.
                $state->message(
                    "I require mod_perl $req but found only $version"
                );
            },
            rules => [
                fail => {
                    rule => $fail,
                },
                httpd_conf => {
                    rule    => $succeed,
                    message => 'mod_perl 2 is the minimum required version',
                },
            ],
        },
        httpd_conf => {
            do => sub {
                my $state   = shift;
                my $builder = $self->builder;
                my $info    = $self->info;
                $self->{conf} = $builder->args('httpd_conf')
                  || $builder->get_reply(
                      name    => 'httpd_conf',
                      message => 'Plese enter path to httpd.conf',
                      label   => 'Path to httpd.conf',
                      default => $info->conf_file,
                );
            },
            rules => [
                httpd_conf => {
                    rule    => sub { ! $self->conf || ! -e $self->conf },
                    message => $self->conf . ' does not exist',
                },
                base_uri => {
                    rule    => sub { $self->conf && -e $self->conf },
                    message => 'Found httpd.conf'
                },
            ],
        },
        base_uri => {
            do => sub {
                my $state   = shift;
                my $builder = $self->builder;
                $self->base_uri(
                    $builder->args('base_uri')
                    || $builder->get_reply(
                        name    => 'base_uri',
                        message => 'Plese enter the root URI for TKP',
                        label   => 'Kinetic Root URI',
                        default => $self->base_uri,
                    )
                );
            },
            rules => [
                base_uri => {
                    rule    => sub { ! $self->base_uri },
                    message => 'No Kinetic root URI',
                },
                Done => {
                    rule    => 1,
                    message => 'We have a Kinetic root URI',
                }
            ],
        },
        # XXX Add something here to offer to configure TKP in httpd.conf. We
        # can get the location of http.conf from $info->conf_file. We would
        # then need to prompt for a vitual host name or Location directive in
        # which to insert the configuration, parse httpd.conf to find it, and
        # then insert our simple configuration.
        Done => {
            do => sub {
                shift->message('Apache 2 configuration detected');
            }
        },
        fail => {
            do => sub {
                $self->builder->_fatal_error(shift->prev_state->message);
            },
        },
    );
}

##############################################################################

=head3 conf_engine

  my $engine_type = Kinetic::Build::Engine::Apache2->conf_engine;

Returns the engine type corresponding to the config file section ('simple');

=cut

sub conf_engine { 'apache' }

##############################################################################

=head3 conf_sections

  my @conf_sections = Kinetic::Build::Engine::Apache2->conf_sections;

Returns the configuration sections to be copied to the config file
C<conf_engine> section.

=cut

sub conf_sections {
    qw(
        httpd
        conf
    );
}

##############################################################################

=head1 Instance Interface

=head2 Accessors

=head3 httpd

Returns the path to the F<httpd> executable, as collected during the execution
of C<validate()>.

=cut

sub httpd { shift->{httpd} }

##############################################################################

=head3 conf

Returns the path to the F<httpd> executable, as collected during the execution
of C<validate()>.

=cut

sub conf { shift->{conf} }

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

