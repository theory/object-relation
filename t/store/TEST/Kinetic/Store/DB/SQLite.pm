package TEST::Kinetic::Store::DB::SQLite;

# $Id: SQLite.pm 1099 2005-01-12 06:17:57Z theory $

use strict;
use warnings;

use base 'TEST::Kinetic::Store';
#use base 'TEST::Kinetic::Store::DB';
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

sub full_text_search : Test(1) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Kinetic::Store->new;
    throws_ok {$store->search($class => 'full text search string')}
        qr/SQLite does not support full-text searches/,
        'SQLite should die if a full text search is attempted';
}

sub search_match : Test(1) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $store = Kinetic::Store->new;
    throws_ok {$store->search( $foo->my_class, name => MATCH '(a|b)%' ) }
        qr/MATCH:  SQLite does not support regular expressions/,
        'SQLite should croak() if a MATCH search is attempted';
}

1;
