package TEST::Object::Relation::TestSetup;

# $Id: TestSetup.pm 3069 2006-07-24 20:59:25Z theory $

use warnings;
use strict;
use File::Spec::Functions;

my $ARGS;
sub import {
    my $class = shift;
    $ARGS = \@_;
    # Run the setup script.
    my $script = catfile qw(t bin setup.pl);
    system $^X, $script, @_ and die "# $script failed: ($!)";
}

END {
    # Run the teardown script.
    my $script = catfile qw(t bin teardown.pl);
    system $^X, $script, @$ARGS and die "# $script failed: ($!)";
}

1;
__END__

=head1 Name

TEST::Object::Relation::TestSetup - Setup Object::Relation for tests

=head1 Synopsis

  use lib 't/lib';
  use TEST::Object::Relation::TestSetup (
      class => 'DB::SQLite',
      dsn   => 'dbi:SQLite:/tmp/obj_rel.db',
  );

=head1 Description

This module automates setting up Object::Relation for tests. On loading, it runs
F<t/bin/setup.pl> and when all testing has completed, it runs
F<t/bin/teardown.pl>. Those scripts must be run in a separate process; what
they do is build the Object::Relation data store and tear it down, respectively. That
means that during dev testing, the data store is available for the duration of
the test script run.

=head1 Import

Any arguments passed to the use statement when loading this module will be
passed through to F<t/bin/setup.pl> and, in an C<END> block, to
F<t/bin/teardown.pl>. These scripts will both pass their arguments to
C<< Object::Relation::Setup->new >>>.

=head1 See Also

=over

=item F<t/bin/setup.pl>

=item F<t/bin/teardown.pl>

=item F<t/system.t>

=item F<t/store.t>

=back

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@obj_relode.com>

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut


