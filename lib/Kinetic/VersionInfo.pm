package Kinetic::VersionInfo;

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

use base 'Kinetic';

=head1 Name

Kinetic::VersionInfo - Version information for Kinetic Applications

=head1 Synopsis

  use Kinetic::VersionInfo;
  my $app_name = 'Kinetic';
  my $version_info = Kinetic::VersionInfo->lookup( app_name => $app_name );
  print "$app_name version number ", $version_info->version;

=head1 Description

This class manages version information for Kinetic applications as well as the
Kinetic Platform itself. The version information is stored in the data store,
but can be retrieved and updated for installations and upgrades. It inherits
from L<Kinetic|Kinetic>, so it works just like any other Kinetic class that
stores data in the data store.

=cut

# XXX We might want to set up Database permissions to allow only the admin
# user to INSERT, UPDATE, or DELETE into this view. But not right now; wait
# till it becomes an issue.

BEGIN {
    my $km = Kinetic::Meta->new(
        key         => 'version_info',
        name        => 'Version Information',
        plural_name => 'Version Information',
    );

##############################################################################
# Instance Interface.
##############################################################################

=head1 Instance Interface

In addition to the interface inherited from L<Kinetic|Kinetic>, this class
offers a number of its own attributes.

=head2 Accessors

=head3 app_name

  my $name = $version_info->app_name;
  $version_info->app_name($app_name);

The name of the Kinetic application.

=cut

    $km->add_attribute(
        name     => 'app_name',
        label    => 'Application Name',
        type     => 'string',
        required => 1,
        unique   => 1,
    );

##############################################################################

=head3 version

  my $name = $version_info->version;
  $version_info->version($version);

The version of the Kinetic application.

=cut

    $km->add_attribute(
        name     => 'version',
        label    => 'Version',
        type     => 'version',
        required => 1,
    );

##############################################################################

=head3 note

  my $name = $note_info->note;
  $note_info->note($note);

Optional note about the application or the current version.

=cut

    $km->add_attribute(
        name   => 'note',
        label  => 'Note',
        type   => 'string',
        unique => 1,
    );

    $km->build;
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

