package TEST::Kinetic::TestSetup;

# $Id$

use warnings;
use strict;
use File::Spec::Functions;

my $conf;
sub import {
    my $class = shift;
    # Run the setup script.
    return unless $ENV{KS_CLASS};
    my $script = catfile qw(t bin setup.pl);
    system $^X, $script, @_ and die "# $script failed: ($!)";
}

END {
    # Run the teardown script.
    return unless $ENV{KS_CLASS};
    my $script = catfile qw(t bin teardown.pl);
    system $^X, $script and die "# $script failed: ($!)";
}

1;
__END__

=head1 Name

TEST::Kinetic::TestSetup - Setup Kinetic for tests

=head1 Synopsis

  use lib 't/lib';
  use TEST::Kinetic::TestSetup qw(--store-lib t/sample/lib);

=head1 Description

This module automates setting up Kinetic for tests. It checks the $KS_CLASS
environment variable, and if that variable is set, it knows that the
C<dev_test> build attribute has been set to true. So on loading, it runs
F<t/bin/setup.pl> and when all testing has completed, it runs
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

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut


