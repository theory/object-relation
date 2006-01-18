package Kinetic::UI::Catalyst::Log;

use strict;
use warnings;
use File::Spec;
use Kinetic::Util::Config ':all';
use Kinetic::Util::Exceptions 'throw_stat';
use LockFile::Simple;

# $Id: Kinetic.pm 2508 2006-01-11 01:54:06Z theory $

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

use base 'Catalyst::Log';

=head1 NAME

Kinetic::UI:::Catalyst::Log - Control where Catalyst sends the logfile info.

=head1 SYNOPSIS

 # In your Catalyst application:
 __PACKAGE__->log( Kinetic::UI::Catalyst::Log->new );
 __PACKAGE__->setup;

=head1 DESCRIPTION

No user serviceable parts (yet).  This class merely controls where the
Catalyst log information gets sent.

=cut

##############################################################################

=head3 new

  Kinetic::UI::Catalyst::Log->new;

Returns a new log object for Catalyst.  If we're running under Apache, we go
ahead and use the default Apache error log.  Otherwise, log output redirected
to C<logs/error_log>.

=cut

sub new {
    my $class = shift;
    if ( $class->can('APACHE_HTTPD') ) {
        return Catalyst::Log->new;
    }
    return $class->SUPER::new;
}

my $ERROR_LOG = File::Spec->catfile( KINETIC_ROOT, 'logs', 'error_log' );
my $LOCK_MGR = LockFile::Simple->make(
    -max   => 5,
    -delay => 1,
);

sub _flush {
    my $self = shift;
    if ( $self->abort || !$self->body ) {
        $self->abort(undef);
    }
    else {
        $self->_send_to_log( $self->body );
    }
    $self->body(undef);
}

# XXX Should I just open the file and leave it open?
sub _send_to_log {
    my $self = shift;
    if ( $ENV{HARNESS_ACTIVE} ) {
        print STDERR @_;
    }
    else {
        $LOCK_MGR->trylock($ERROR_LOG);
        open my $log, '>>', $ERROR_LOG
          or throw_stat [
            'Could not open file "[_1]" for [_2]: [_3]',
            $ERROR_LOG, 'appending', $!
          ];
        print $log @_;
        close $log;
    }
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
