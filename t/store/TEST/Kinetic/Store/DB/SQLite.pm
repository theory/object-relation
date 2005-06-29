package TEST::Kinetic::Store::DB::SQLite;

# $Id: SQLite.pm 1099 2005-01-12 06:17:57Z theory $

use strict;
use warnings;

use base 'TEST::Kinetic::Store::DB';
use Test::More;
use Test::Exception;

use Kinetic::Store qw/:all/;

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

# Skip all of the tests in this class if SQLite isn't supported.
__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->supported('sqlite')
      ? 0
      : "Not testing SQLite"
) if caller; # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

=end

# Looks like you failed 13 tests of 237.
dubious
        Test returned status 13 (wstat 3328, 0xd00)
DIED. FAILED tests 46, 82, 93, 102, 142-143, 145-146, 148-149, 152-153, 216
        Failed 13/237 tests, 94.51% okay (less 45 skipped tests: 179 okay, 75.53%)
Failed Test                       Stat Wstat Total Fail  Failed  List of Failed
-------------------------------------------------------------------------------
t/store/TEST/Kinetic/Store/DB/SQL   13  3328   237   13   5.49%  46 82 93 102
                                                                 142-143 145-
                                                                 146 148-149
                                                                 152-153 216
45 subtests skipped.

Failed 1/1 test scripts, 0.00% okay. 13/237 subtests failed, 94.51% okay.
 Looks like you failed 9 tests of 237.
dubious
        Test returned status 9 (wstat 2304, 0x900)
DIED. FAILED tests 93, 102, 142-143, 145-146, 152-153, 216
        Failed 9/237 tests, 96.20% okay (less 39 skipped tests: 189 okay, 79.75%)
Failed Test                       Stat Wstat Total Fail  Failed  List of Failed
-------------------------------------------------------------------------------
t/store/TEST/Kinetic/Store/DB/SQL    9  2304   237    9   3.80%  93 102 142-143
                                                                 145-146 152-
                                                                 153 216
39 subtests skipped.
Failed 1/1 test scripts, 0.00% okay. 9/237 subtests failed, 96.20% okay.

# Looks like you failed 9 tests of 237.
dubious
        Test returned status 9 (wstat 2304, 0x900)
DIED. FAILED tests 142-143, 145-146, 152, 174-177
        Failed 9/237 tests, 96.20% okay
Failed Test                       Stat Wstat Total Fail  Failed  List of Failed
-------------------------------------------------------------------------------
t/store/TEST/Kinetic/Store/DB/SQL    9  2304   237    9   3.80%  142-143 145-
                                                                 146 152 174-
                                                                 177
Failed 1/1 test scripts, 0.00% okay. 9/237 subtests failed, 96.20% okay.

=cut

sub full_text_search : Test(1) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Kinetic::Store->new;
    throws_ok {$store->search($class => 'full text search string')}
        'Kinetic::Util::Exception::Fatal::Unsupported',
        'SQLite should die if a full text search is attempted';
}

sub search_match : Test(1) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $store = Kinetic::Store->new;
    throws_ok {$store->search( $foo->my_class, name => MATCH '(a|b)%' ) }
        'Kinetic::Util::Exception::Fatal::Unsupported',
        'SQLite should croak() if a MATCH search is attempted';
}

1;
