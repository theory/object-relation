package TEST::Kinetic::Store::Search;

# $Id: Store.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

#use base 'TEST::Kinetic';
use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;

use aliased 'Kinetic::Store::Search';

__PACKAGE__->runtests unless caller;

sub constructor : Test(no_plan) {
    my $test   = shift;
    
    throws_ok { Search->new( unknown_attr => 1 ) }
        'Kinetic::Util::Exception::Fatal::Search',
        'new() with unknown attributes should throw an exception'; 

    #my $search = Search->new(
    #    column       => $column,
    #    operator     => $operator,
    #    negated      => $negated,
    #    place_holder => $place_holder,
    #    data         => $data,
    #    search_class => $search_class,
    #);
}

1;
