package Kinetic::Engine::Apache2;

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
use warnings;

use version;
our $VERSION = version->new('0.0.1');

use Kinetic::Util::Config qw(:apache);
use Kinetic::Util::Exceptions 'throw_fatal';

{
    my %commands = (
        start   => 'start',
        stop    => 'stop',
        restart => 'graceful',
    );
    while ( my ( $arg, $command ) = each %commands ) {
        no strict 'refs';
        *$arg = sub {
            my $class = shift;
            my @args  = (
                APACHE_HTTPD,
                '-k', $command,    # start, stop, or graceful
                '-f', APACHE_CONF, # httpd.conf
            );
            system(@args) == 0 or throw_fatal [
                q{system('[_1]') failed: [_2]},
                join( q{' '}, @args ), $?
            ];
        };
    }
}

##############################################################################

=head1 NAME

Kinetic::Engine::Apache2

=head1 DESCRIPTION

This class controls starting, stopping, and restarting the Apache2 engine.

=head1 ENGINE INTERFACE

=head2 Class methods

=head3 start

  Kinetic::Engine::Apache2->start;

Starts the Apache2 engine in a background process.

=head3 stop

  Kinetic::Engine::Apache2->stop;

Stops the Apache2 engine.

=head3 restart

  Kinetic::Engine::Apache2->restart;

Restarts the Apache2 engine.

=cut

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
