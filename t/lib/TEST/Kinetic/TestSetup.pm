package TEST::Kinetic::TestSetup;

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

use warnings;
use strict;
use File::Spec::Functions;

my $conf;
sub import {
    my $class = shift;
    # Run the setup script.
    return if $ENV{NOSETUP} || !$ENV{KINETIC_SUPPORTED};
    $conf = $ENV{KINETIC_CONF};
    my $script = catfile qw(t bin setup.pl);
    system $^X, $script, @_ and die "# $script failed: ($!)";
}

END {
    # Run the teardown script.
    return if $ENV{NOSETUP};
    $ENV{KINETIC_CONF} = $conf;
    my $script = catfile qw(t bin teardown.pl);
    system $^X, $script and die "# $script failed: ($!)";
}

1;
__END__

=head1 Name

TEST::Kinetic::TestSetup - Setup Kinetic for tests

=head1 Synopsis

  use lib 't/lib';
  use TEST::Kinetic::TestSetup qw(--store-lib t/sample/lib --no-init);

=head1 Description

This module automates setting up Kinetic for tests. It checks the
$KINETIC_SUPPORTED environment variable, and if that variable is set, it knows
that the C<dev_test> build attribute has been set to true. So on loading, it
runs F<t/bin/setup.pl> and when all testing has completed, it runs
F<t/bin/teardown.pl>. Those scripts must be run in a separate process; what
they do is build the Kinetic data store and tear it down, respectively. That
means that during dev testing, the data store is available for the duration of
the test script run.

=head1 Import

Any arguments passed to the use statement when loading this module will be
passed through to F<t/bin/setup.pl>. The supported options to that script are:

=over

=item --source-dir

The value to set the Kinetic::Build C<source_dir> to before instantiating the
setup objects. This affects where the store setup library looks for modules
from which to create the data store. See F<t/store.t> for an example>.

=item --init

=item --no-init

This boolean option indicates whether or not to call the C<init_app()> method
on the build object once the setup is complete. This can be useful if the
Kinetic libraries themselves are not used to build the data store, and so some
necessary bits might be missing (namely the version_info table). Defaults to
true; pass C<--no-init> to make it false.

=back

=head1 See Also

=over

=item F<t/bin/setup.pl>

=item F<t/bin/teardown.pl>

=item F<t/system.t>

=item F<t/store.t>

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


