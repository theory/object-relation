package TEST::Class::Kinetic;

# $Id: SQLite.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'Test::Class';
use File::Spec;
use Cwd;

my $STARTDIR;
BEGIN { $STARTDIR = getcwd }

##############################################################################

=head3 _start_dir

  my $start_dir = $test->_start_dir;

Read only.  Returns absolute path to the directory the tests are run from.

=cut

sub _start_dir { $STARTDIR }

##############################################################################

=head3 _test_lib

  my $test_lib = $test->_test_lib;

Returns absolute path to the test lib directory that Kinetic ojbects will use.
May be overridden.

=cut

sub _test_lib {
    return File::Spec->catfile(shift->_start_dir, qw/t lib/);
}

