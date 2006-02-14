package Kinetic::AppBuild;

# $Id$

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or derivatives to
# this work, or any other work intended for use with the Kinetic framework, to
# Kineticode, Inc., you confirm that you are the copyright holder for those
# contributions and you grant Kineticode, Inc.  a nonexclusive, worldwide,
# irrevocable, royalty-free, perpetual license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute those
# contributions and any derivatives thereof.

use strict;
use base 'Module::Build';
use Class::Trait 'Kinetic::Build::Trait';
use Config::Std;
use File::Spec;

use version;
our $VERSION = version->new('0.0.1');

=head1 Name

Kinetic::AppBuild - Builds and Installs Kinetic Applications

=head1 Synopsis

In F<Build.PL>:

  use strict;
  use Kinetic::AppBuild;

  my $build = Kinetic::AppBuild->new(
      module_name => 'MyApp',
  );

  $build->create_build_script;

=head1 Description

This module subclasses L<Module::Build|Module::Build> to provide added
functionality for installing Kinetic applications into an existing Kinetic
Platform intstallation. The added functionality includes database building and
library, view, and Web file installation.

=cut

##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $cm = Kinetic::AppBuild->new(%init);

Overrides Module::Build's constructor to add Kinetic-specific build elements
and to run methods that collect data necessary to install a Kinetic
appliaction.

=cut

sub new {
    my $self = shift->SUPER::new(
        # Set up new default values for parent class properties.
        install_base =>
            File::Spec->catdir( $Config::Config{installprefix}, 'kinetic' ),
        @_    # User-set properties.
    );

    # Does the base directory exist?
    my $base = $self->install_base;
    die qq{Directory "$base" does not exist; use --install-base to }
        . 'specify the Kinetic base directory'
        unless -d $base;

    # Is Kinetic installed there?
    my $kinetic_conf = File::Spec->catfile($base, 'conf', 'kinetic.conf');
    die qq{Kinetic does not appear to be installed in "$base"; use }
        . '--install-base to specify the Kinetic base directory'
        unless -e $kinetic_conf;

    # Add www element and install path.
    $self->add_build_element('www');
    $self->install_path->{www} ||= $self->install_base . '/www';

    return $self;
}

1;
__END__

##############################################################################

=head1 See Also

=over

=item L<Kinetic::Build|Kinetic::Build>

Builds and installs the Kinetic Platform itself.

=item L<Kinetic::Build::Trait|Kinetic::Build::Trait>

Defines methods common to Kinetic::Build and Kinetic::AppBuild.

=back

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
