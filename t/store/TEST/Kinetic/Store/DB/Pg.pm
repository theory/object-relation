package TEST::Kinetic::Store::DB::Pg;

# $Id: Pg.pm 1099 2005-01-12 06:17:57Z theory $

use strict;
use warnings;

use base 'TEST::Kinetic::Store';
use Test::More;
use Test::Exception;

use Kinetic::Store qw/:all/;

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

# Skip all of the tests in this class if Postgres isn't supported.
__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->supported('pg')
      ? 0
      : "Not testing Postgresql"
) if caller; # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub full_text_search : Test(1) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $class = $foo->my_class;
    my $store = Kinetic::Store->new;
    TODO: {
        local $TODO  = 'Full text search is not yet implemented.';
        my $iterator = $store->search($class => 'oo');
        my @results;
        eval {@results = $test->_all_items($iterator)};
        is @results, 1, '... and we should have the correct number of results';
        #is_deeply $results[0], $foo, '... and they should be the correct results';
    }
}

sub search_match : Test(6) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $store = Kinetic::Store->new;
    my $iterator = $store->search( $foo->my_class, 
        name => MATCH '^(f|ba)',
        { order_by => 'name' }
    );
    my @items = $test->_all_items($iterator);
    is @items, 2, 'Searches should accept regular expressions';
    is_deeply \@items, [$bar, $foo], 'and should include the correct items';

    $iterator = $store->search( $foo->my_class, 
        name => NOT MATCH '^(f|ba)',
        { order_by => 'name' }
    );
    @items = $test->_all_items($iterator);
    is @items, 1, 'and regexes should return the correct number of items';
    is_deeply \@items, [$baz], 'and should include the correct items';

    $iterator = $store->search($foo->my_class, name => MATCH 'z$');
    @items = $test->_all_items($iterator);
    is @items, 1, 'and regexes should return the correct number of items';
    is_deeply \@items, [$baz], 'and should include the correct items';
}

1;
