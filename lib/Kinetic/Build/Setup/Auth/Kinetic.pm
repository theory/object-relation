package Kinetic::Build::Setup::Auth::Kinetic;

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

use base 'Kinetic::Build::Setup::Auth';

=head1 Name

Kinetic::Build::Setup::Auth::Kinetic - Kinetic authorization builder

=head1 Synopsis

  use Kinetic::Build::Setup::Auth::Kinetic;
  my $kbc = Kinetic::Build::Setup::Auth::Kinetic->new;
  $kbc->setup;

=head1 Description

This module inherits from Kinetic::Build::Setup::Auth to collect configuration
information for the Kinetic authorization architecture. Its interface is
defined entirely by Kinetic::Build::Setup::Auth. The command-line options it
adds are:

=over

=item auth-expires

=back

=cut

##############################################################################

=head1 Class Interface

=head2 Class Methods

=head3 authorization_class

  my $authorization_class
      = Kinetic::Build::Setup::Auth::Kinetic->authorization_class ;

Returns the package name of the Kinetic authorization class.

=cut

sub authorization_class {'Kinetic::Util::Auth::Kinetic'}

##############################################################################

=head3 rules

  my @rules = Kinetic::Build::Setup::Auth::Kinetic->rules;

Returns a list of arguments to be passed to an L<FSA::Rules|FSA::Rules>
constructor. These arguments are rules that will be used to collect
information for the configuration of Kinetic authorization.

=cut

sub rules {
    my $self = shift;
    return (
        start => {
            do => sub {
                my $state   = shift;
                my $builder = $self->builder;
                $self->_ask_for_expires;
                $state->message('Auth configuration collected');
                $state->done(1);
            },
        },
    );
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
