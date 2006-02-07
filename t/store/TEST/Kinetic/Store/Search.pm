package TEST::Kinetic::Store::Search;

# $Id$

use strict;
use warnings;

#use base 'TEST::Kinetic';
use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;

use aliased 'Kinetic::Store::Search';

__PACKAGE__->runtests unless caller;

sub constructor : Test(3) {
    my $test = shift;

    throws_ok { Search->new( unknown_attr => 1 ) }
      'Kinetic::Util::Exception::Fatal::Search',
      'new() with unknown attributes should throw an exception';

    my %search = (
        column   => 'first_name',
        operator => 'EQ',
        negated  => 'NOT',
        data     => 'foo',
    );
    ok my $search = Search->new(%search),
      '... and creating a new Search object should succeed';
    isa_ok $search, Search, '... and the object it returns';
}

sub methods : Test(16) {
    my $test = shift;

    my %search = (
        column   => 'first_name',
        operator => 'EQ',
        negated  => 'NOT',
        data     => 'foo',
    );
    ok my $search = Search->new(%search),
      'Creating an EQ search should succeed';

    can_ok $search, 'search_method';
    is $search->search_method, '_EQ_SEARCH',
      '... and it should return the correct search method';
    is $search->search_method, '_EQ_SEARCH',
      '... and we should be able to call it twice in a row';    # bug fix

    can_ok $search, 'operator';
    is $search->operator, '!=', '... and it should return the correct operator';

    can_ok $search, 'negated';
    is $search->negated, 'NOT', '... and it should return the correct value';

    can_ok $search, 'original_operator';
    is $search->original_operator, 'EQ',
      '... and we should be able to get the original search operator';

    can_ok $search, 'formatted_data';
    is $search->formatted_data, 'foo',
      '... and it should return the data we are searching for';

    $search{operator} = 'BETWEEN';
    $search{data}     = [ 21, 42 ];

    ok $search = Search->new(%search),
      'Creating a BETWEEN search should succeed';
    is $search->formatted_data, '(21, 42)',
      '... and formatted_data should return data formatted for a REST request';

    $search{data}     = [ 'alpha', 'omega' ];

    ok $search = Search->new(%search),
      'Creating a BETWEEN search should succeed';
    is $search->formatted_data, "('alpha', 'omega')",
      '... and formatted_data should return data formatted for a REST request';
}

1;
