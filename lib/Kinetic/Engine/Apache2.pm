package Kinetic::Engine::Apache2;

# $Id: Engine.pm 2414 2005-12-22 07:21:05Z theory $

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

use aliased 'Proc::Background';

use Kinetic::Util::Config qw(:all);
use Kinetic::Util::Language;
use Kinetic::Util::Exceptions;
use File::Pid;
use File::Spec;

use Exporter::Tidy manage => [qw( start stop restart )];

use Readonly;
Readonly my $LOG_DIR  => File::Spec->catfile( KINETIC_ROOT, 'logs' );
Readonly my $PID_FILE => File::Spec->catfile( $LOG_DIR,     'kinetic.pid' );
Readonly my $LIB      => File::Spec->catfile( KINETIC_ROOT, 'lib' );

my $LANG = Kinetic::Util::Language->get_handle;
Kinetic::Util::Context->language($LANG);

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

=cut

sub start {
    my $class = shift;
    my $process = Background->new(
        APACHE_HTTPD,
        'start',
        # '-f' . APACHE_HTTPD_CONF
    );
    #unless ( $process->alive ) {
    #    die _localize( "Could not start process: [_1]", $? );
    #}
}

##############################################################################

=head3 stop

  Kinetic::Engine::Apache2->stop;

Stops the Apache2 engine.

=cut

sub stop {
    my $class = shift;
    my $process = Background->new(
        APACHE_HTTPD,
        'stop',
        # '-f' . APACHE_HTTPD_CONF
    );
}

##############################################################################

=head3 restart

  Kinetic::Engine::Apache2->restart;

Restarts the Apache2 engine.

=cut

sub restart {
    my $class = shift;
    my $process = Background->new(
        APACHE_HTTPD,
        'graceful',
        # '-f' . APACHE_HTTPD_CONF
    );
}

sub _localize {
    return $LANG->maketext(@_) . "\n";
}

sub _is_running {
    local $^W;    # force File::Pid to not issue warnings if PID is not found
    return shift->running;
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
