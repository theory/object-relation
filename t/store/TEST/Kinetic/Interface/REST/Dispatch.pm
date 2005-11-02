package TEST::Kinetic::Interface::REST::Dispatch;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Test::XML;

use TEST::Kinetic::Traits::Store qw/:all/;
use TEST::Kinetic::Traits::XML qw/:all/;
use TEST::Kinetic::Traits::HTML qw/:all/;

# we're not using the following until some bugs are fixed.  See the
# 'trait' for more notes

#use Class::Trait 'TEST::Kinetic::Traits::REST';
use Kinetic::Util::Constants qw/UUID_RE :xslt :labels :rest/;
use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(1) }

use aliased 'Test::MockModule';
use aliased 'XML::XPath';
use Array::AsHash;
use XML::XPath::XMLParser;
use HTML::Entities qw/encode_entities/;

use aliased 'Kinetic::Store' => 'Store', ':all';
use aliased 'Kinetic::Interface::REST';
use aliased 'Kinetic::Interface::REST::Dispatch';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';    # contains a TestApp::Simple::One object

use Readonly;
Readonly my $DOMAIN      => 'http://somehost.com/';
Readonly my $PATH        => 'rest/';
Readonly my $SEARCH_TYPE => SEARCH_TYPE;

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
    ? 0
    : "Not testing Data Stores"
  )
  if caller;    # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub setup : Test(setup) {
    my $test  = shift;
    my $store = Store->new;
    $test->{dbh} = $store->_dbh;
    $test->{dbh}->begin_work;
    $test->{dbi_mock} = MockModule->new( 'DBI::db', no_auto => 1 );
    $test->{dbi_mock}->mock( begin_work => 1 );
    $test->{dbi_mock}->mock( commit     => 1 );
    $test->{db_mock} = MockModule->new('Kinetic::Store::DB');
    $test->{db_mock}->mock( _dbh => $test->{dbh} );
    my $foo = One->new;
    $foo->name('foo');
    $store->save($foo);
    my $bar = One->new;
    $bar->name('bar');
    $store->save($bar);
    my $baz = One->new;
    $baz->name('baz');
    $store->save($baz);
    $test->test_objects( [ $foo, $bar, $baz ] );

    # set up mock cgi and path methods
    my $cgi_mock = MockModule->new('CGI');
    $cgi_mock->mock( path_info => sub { $test->_path_info } );
    my $rest_mock = MockModule->new('Kinetic::Interface::REST');
    {
        local $^W;    # because CGI.pm is throwing uninitialized errors :(
        $rest_mock->mock( cgi => CGI->new );
    }
    $test->{cgi_mock}  = $cgi_mock;
    $test->{rest_mock} = $rest_mock;
    $test->{rest}      = REST->new(
        domain => $DOMAIN,
        path   => $PATH
    );
    $test->_path_info('');
    $test->desired_attributes( [qw/ state name description bool /] );
    $test->domain($DOMAIN);
    $test->path($PATH);
}

sub teardown : Test(teardown) {
    my $test = shift;
    delete( $test->{dbi_mock} )->unmock_all;
    $test->{dbh}->rollback unless $test->{dbh}->{AutoCommit};
    delete( $test->{db_mock} )->unmock_all;
    delete( $test->{cgi_mock} )->unmock_all;
    delete( $test->{rest_mock} )->unmock_all;
}

sub _path_info {
    my $test = shift;
    return $test->{path_info} unless @_;
    $test->{path_info} = shift;
    return $test;
}

sub get_desired_attributes : Test(4) {
    my $test = shift;
    my $dispatch = Dispatch->new( { rest => $test->{rest} } );
    $dispatch->class_key('two');
    can_ok $dispatch, '_desired_attributes';
    $dispatch->_max_attribute_index(3);
    is_deeply scalar $dispatch->_desired_attributes,
      [qw/state name description age/],
      '... and _desired_attributes should return the correct attributes';

    can_ok $dispatch, '_all_attributes';
    is_deeply scalar $dispatch->_all_attributes,
      [qw/state name description age date/],
      '... and _all_attributes should return the all attributes';
}

sub add_pagesets : Test(24) {
    my $test = shift;

    my @args = (
        SEARCH_TYPE,    'name EQ "foo"',
        LIMIT_PARAM,    10,
        ORDER_BY_PARAM, 'name',
        SORT_PARAM,     'ASC',
        _current_count => 10,    # number of items on current pages
        _total_objects => 55,    # total which meet search criteria
    );
    $test->_test_pageset( 'test_class', \@args,
        'Normal searches should create pagesets' );
    @args = (
        SEARCH_TYPE,    '',
        LIMIT_PARAM,    5,
        ORDER_BY_PARAM, 'age',
        SORT_PARAM,     'DESC',
        _current_count => 10,    # number of items on current pages
        _total_objects => 55,    # total which meet search criteria
    );
    $test->_test_pageset( 'some_class', \@args,
        'Empty searches should succeed' );

    @args = ( SEARCH_TYPE, '', LIMIT_PARAM, 5, ORDER_BY_PARAM, 'age', );
    $test->_test_pageset( 'some_class', \@args,
        'Leaving off sort_order should succeed' );

    @args = ( SEARCH_TYPE, 'age GT 3', LIMIT_PARAM, 30, );
    $test->_test_pageset( 'some_class', \@args,
        'Leaving off order_by and sort_order should succeed' );

    @args = ( SEARCH_TYPE, '', LIMIT_PARAM, 5, SORT_PARAM, 'ASC', );

    $test->_test_pageset( 'some_class', \@args,
        'Leaving off order_by on pagesets should succeed' );

    @args = (
        SEARCH_TYPE, "description LIKE '%object%'",
        LIMIT_PARAM, 5, SORT_PARAM, 'ASC',
    );

    $test->_test_pageset( 'some_class', \@args,
        'Search terms with percent signs should succeed' );
}

sub _test_pageset {
    my $test = shift;
    my ( $test_class, $args, $description ) = @_;
    my $orig_args = Array::AsHash->new( { array => $args, clone => 1 } );
    ok my ($xml) = $test->_get_pageset_xml(@_), $description;

    my $current = $orig_args->delete('_current_count');
    my $total   = $orig_args->delete('_total_objects');
    $current = $orig_args->get(LIMIT_PARAM)     unless defined $current;
    $total   = $orig_args->get(LIMIT_PARAM) * 2 unless defined $total;
    my $num_pages = $current ? $total / $current : 0;

    $num_pages++ unless int($num_pages) == $num_pages;
    $num_pages = int($num_pages);
    my $xpath      = XPath->new( xml => $xml );
    my $parameters = '/kinetic:resources/kinetic:pages/kinetic:page';
    my $node       =
      $xpath->findnodes_as_string(
        qq{$parameters\[\@id = "[ Page $num_pages ]"]});
    like $node, qr/\Q[ Page $num_pages ]/,
      '... and we should have the correct number of pages';
    my ($url) = $node =~ /xlink:href="([^"]*)/;
    my $search = encode_entities( $orig_args->get(SEARCH_TYPE) || 'null' );
    like $url, qr{/$SEARCH_TYPE/\Q$search\E/},
      '... and the search terms should be properly quoted';

    $node =
      $xpath->findnodes_as_string(
        qq{$parameters\[\@id = "[ Page @{[$num_pages ]}"]});    # "
    ok !$node, '... but no more';
}

sub _get_pageset_xml {
    my ( $test, $test_class, $args, $description ) = @_;
    $description ||= '';
    $args = Array::AsHash->new(
        {
            array => $args,
            clone => 1,
        }
    );

    $args->put( SEARCH_TYPE,    'null' ) unless $args->exists(SEARCH_TYPE);
    $args->put( ORDER_BY_PARAM, 'null' ) unless $args->exists(ORDER_BY_PARAM);
    $args->put( LIMIT_PARAM,    20 )     unless $args->exists(LIMIT_PARAM);
    $args->put( SORT_PARAM,     'ASC' )  unless $args->exists(SORT_PARAM);

    my $current = $args->delete('_current_count');
    $current = $args->get(LIMIT_PARAM) unless defined $current;

    my $dispatch = Dispatch->new( { rest => $test->{rest} } );
    $dispatch->rest( $test->{rest} );
    $dispatch->args($args);
    my $xml = $test->_get_xml(
        $dispatch->_xml,
        'add_pageset',
        {
            args      => $args,
            class_key => $test_class,
            instances => $current,
            total     => 100,
        }
    );
    return $xml;
}

sub _get_xml {
    my ( $test, $object, $method, @args ) = @_;
    my $xml = $object->can('StartDocString') ? $object : $object->_xml;
    $xml->StartDocString;
    $xml->elem('resources')->StartElement;
    $xml->ns('xlink')->AddNamespace;

    my $count = 1;
    $object->$method(@args);
    $xml->EndElement;
    $xml->EndDocument;
    return $xml->GetDocString;
}

sub add_search_data : Test(61) {
    my $test = shift;

    my @args = (
        SEARCH_TYPE, 'name EQ "foo"',
        LIMIT_PARAM, 20, ORDER_BY_PARAM, 'name', SORT_PARAM, 'ASC',
    );
    $test->_test_search_data( 'one', \@args, 'Normal searches should succeed',
        1 );

    @args = (
        SEARCH_TYPE, '', LIMIT_PARAM, 5, ORDER_BY_PARAM, 'age', SORT_PARAM,
        'DESC',
    );
    $test->_test_search_data( 'one', \@args, 'Empty searches should succeed' );

    @args = ( SEARCH_TYPE, '', LIMIT_PARAM, 5, ORDER_BY_PARAM, 'age', );
    $test->_test_search_data( 'one', \@args,
        'Leaving off sort_order should succeed' );

    @args = ( SEARCH_TYPE, 'name GT 3', LIMIT_PARAM, 30, );
    $test->_test_search_data( 'one', \@args,
        'Leaving off order_by and sort_order should succeed', 1 );

    @args = ( SEARCH_TYPE, '', LIMIT_PARAM, 5, SORT_PARAM, 'ASC', );
    $test->_test_search_data( 'one', \@args,
        'Leaving off order_by should succeed' );
}

##############################################################################

=head3 _test_search_data

  $test->_test_search_data($class_key, \@_add_search_data_args, $description);


This functions akes the search class_key and the arguments to
_add_search_data() and knows how to validate the resulting XML.

Performs X tests per run and uses C<$description> as the first test name.

=cut

sub _test_search_data {
    my ( $test, $test_class, $args_aref, $description, $fields ) = @_;
    $fields      ||= 0;
    $description ||= '';

    my $args = Array::AsHash->new(
        {
            array => $args_aref,
            clone => 1,
        }
    );

    $args->put( SEARCH_TYPE,    'null' ) unless $args->exists(SEARCH_TYPE);
    $args->put( ORDER_BY_PARAM, 'null' ) unless $args->exists(ORDER_BY_PARAM);
    $args->put( LIMIT_PARAM,    20 )     unless $args->exists(LIMIT_PARAM);
    $args->put( SORT_PARAM,     'ASC' )  unless $args->exists(SORT_PARAM);

    my $current = $args->delete('_current_count');
    my $total   = $args->delete('_total_objects');
    $current = $args->get(LIMIT_PARAM)     unless defined $current;
    $total   = $args->get(LIMIT_PARAM) * 2 unless defined $total;

    # XXX pull this out when done debugging page sets
    my $dispatch = Dispatch->new( { rest => $test->{rest} } );

    # we need to set this up because the rest class uses search request
    # IR to figure out how the search was performed and build the correct
    # XML
    my $search_request;
    {
        $dispatch->class_key($test_class);
        my $class = $dispatch->class;
        my @search = ( STRING => $args->get(SEARCH_TYPE) );
        @search = () if $search[1] eq 'null';
        my $iterator = Store->new->search( $class, @search );
        $search_request = $iterator->request;
        $dispatch->_search_request($search_request);
        $dispatch->args( $args->clone );
    }

    ok my $xml = $test->_get_xml( $dispatch, '_add_search_data', 1, 10 ),
      $description;

    my $xpath = XPath->new( xml => $xml );
    my $node =
      $xpath->findnodes_as_string('/kinetic:resources/kinetic:class_key');
    is $node, qq{<kinetic:class_key>$test_class</kinetic:class_key>},
      '... and the class key should be set correctly';

    my $parameters =
      '/kinetic:resources/kinetic:search_parameters/kinetic:parameter';

    while ( my ( $arg, $value ) = $args->each ) {
        if ( SORT_PARAM eq $arg || ORDER_BY_PARAM eq $arg ) {
            my $node =
              $xpath->findnodes_as_string(qq{$parameters\[\@type = "$arg"]});
            like $node,
              qr/<kinetic:parameter colspan="3" type="$arg" widget="select">.*/,
              qq'... and the $arg should be identified as a "select" widget';

            my @options =
              SORT_PARAM eq $arg
              ? ( [ ASC => 'Ascending' ], [ DESC => 'Descending' ] )
              : map { [ $_ => ucfirst $_ ] } $test->desired_attributes;

            foreach my $order (@options) {
                my ( $selected, $not ) =
                  $value eq $order->[0]
                  ? ( ' selected="selected"', ' ' )
                  : ( '', ' not ' );
                $node =
                  $xpath->findnodes_as_string(
qq{$parameters\[\@type = "$arg"]/kinetic:option[\@name = "$order->[0]"]}
                  );
                is $node,
qq{<kinetic:option name="$order->[0]"$selected>$order->[1]</kinetic:option>},
qq[... and the "$arg $order->[0]" option should${not}be selected];
            }
        }
        elsif ( $arg =~ /^_/ ) {
            my $node =
              $xpath->findnodes_as_string(qq{$parameters\[\@type = "$arg"]});
            my $expected =
              ( _path_info_segment_has_null_value($value) )
              ? qq{<kinetic:parameter colspan="3" type="$arg" />}
              : qq{<kinetic:parameter colspan="3" type="$arg">$value</kinetic:parameter>};
            is $node, $expected, "... and the $arg should be set correctly";
        }
        else {    # SEARCH_TYPE
            my $request = $dispatch->_search_request;

            while ( my ( $field, $search ) = each %$search_request ) {
                my $parameter = qq{$parameters\[\@type = "$field"]};
                my $node      = $xpath->findnodes_as_string($parameter);
                if ( 'BETWEEN' ne $search->operator ) {
                    my $value = $search->data;
                    like $node,
                      qr{\Q<kinetic:parameter type="$field" value="$value"},
                      "We should have the proper XML built for '$field'";
                }
                my $comparison =
                  qq{$parameter/kinetic:comparisons/kinetic:comparison};
                my $option = 'kinetic:option[@selected = "selected"]';
                $node =
                  $xpath->findnodes_as_string(
                    qq($comparison\[\@type = "_${field}_logical"]/$option));
                my $name = $search->negated ? 'name="NOT"' : 'name=""';
                like $node, qr/$name/,
'... and whether or not the field is negated should be selected';
                $node =
                  $xpath->findnodes_as_string(
                    qq($comparison\[\@type = "_${field}_comp"]/$option));
                $name = 'name="' . $search->operator . '"';
                like $node, qr/$name/,
                  '... and the correct search operator should be selected';
            }
        }
    }
}

sub _path_info_segment_has_null_value {
    my $segment = shift;
    return defined $segment
      && ( 'null' eq $segment || ( !$segment && "0" ne $segment ) );
}

sub method_arg_handling : Test(12) {
    my $test = shift;

    # also test for lookup
    my $dispatch = Dispatch->new( { rest => $test->{rest} } );
    can_ok $dispatch, 'args';
    $dispatch->method('lookup');
    ok $dispatch->args->isa('Array::AsHash'),
'Calling lookup args() with no args set should return an array as hash object';
    ok $dispatch->args( Array::AsHash->new( { array => [qw/ foo bar /] } ) ),
      '... and setting the arguments should succeed';
    is_deeply scalar $dispatch->args->get_array, [qw/ foo bar /],
      '... and we should be able to reset the args';

    $dispatch->method('search');
    ok $dispatch->args( Array::AsHash->new ),
      'Setting search args should succceed';
    is_deeply scalar $dispatch->args->get_array,
      [ SEARCH_TYPE, '', LIMIT_PARAM, 20, OFFSET_PARAM, 0 ],
      '... and setting them with no args set should return a default search';

    ok $dispatch->args( Array::AsHash->new( { array => [qw/ foo bar /] } ) ),
      '... and setting the arguments should succeed';

    is_deeply scalar $dispatch->args->get_array,
      [ SEARCH_TYPE, 'null', LIMIT_PARAM, 20, OFFSET_PARAM, 0 ],
'... but it should return default limit and offset and discard unknown args';

    $dispatch->args(
        Array::AsHash->new(
            { array => [ 'this', 'that', LIMIT_PARAM, 30, OFFSET_PARAM, 0 ] }
        )
    );
    is_deeply scalar $dispatch->args->get_array,
      [ SEARCH_TYPE, 'null', LIMIT_PARAM, 30, OFFSET_PARAM, 0 ],
      '... but it should not override a limit that is already supplied';

    $dispatch->args(
        Array::AsHash->new(
            { array => [ LIMIT_PARAM, 30, 'this', 'that', OFFSET_PARAM, 0 ] }
        )
    );
    is_deeply scalar $dispatch->args->get_array,
      [ SEARCH_TYPE, 'null', LIMIT_PARAM, 30, OFFSET_PARAM, 0 ],
      '... regardless of its position in the arg list';

    $dispatch->args(
        Array::AsHash->new(
            { array => [ 'this', 'that', LIMIT_PARAM, 30, OFFSET_PARAM, 20 ] }
        )
    );
    is_deeply scalar $dispatch->args->get_array,
      [ SEARCH_TYPE, 'null', LIMIT_PARAM, 30, OFFSET_PARAM, 20 ],
      '... not should it override an offset already supplied';

    $dispatch->args(
        Array::AsHash->new(
            { array => [ 'this', 'that', OFFSET_PARAM, 10, LIMIT_PARAM, 30 ] }
        )
    );
    is_deeply scalar $dispatch->args->get_array,
      [ SEARCH_TYPE, 'null', LIMIT_PARAM, 30, OFFSET_PARAM, 10 ],
      '... regardless of its position in the list';
}

sub page_set : Test(17) {
    my $test = shift;

    my $dispatch = Dispatch->new( { rest => $test->{rest} } );

    for my $age ( 1 .. 100 ) {
        my $object = Two->new;
        $object->name("Name $age");
        $object->one->name("One Name $age");
        $object->age($age);
        $object->save;
    }
    my ( $num_items, $limit, $offset, $total ) = ( 19, 20, 0, 100 );

    # here we are deferring evaluation of the variables so we can
    # later just change their values and have the dispatch method
    # pick 'em up.

    my $pageset_args = sub {
        {
            count           => $num_items,
              limit         => $limit,
              offset        => $offset,
              total_entries => $total,
        }
    };

    my $result =
      $dispatch->class_key('two')->method('search')->args( Array::AsHash->new )
      ->_xml->_get_pageset( $pageset_args->() );
    ok !$result,
      '... and it should return false on first page if $count < $limit';

    $num_items = $limit;
    ok $result = $dispatch->_xml->_get_pageset( $pageset_args->() ),
      'On the first page, &_get_pageset should return true if $count == $limit';

    isa_ok $result, 'Data::Pageset',
      '... and the result should be a pageset object';

    is $result->current_page,  1, '... telling us we are on the first page';
    is $result->last_page,     5, '... and how many pages there are';
    is $result->pages_per_set, 1, '... and how many pages are in each set';
    is $result->total_entries, 100,
      '... and we should have the correct number of entries';

    $num_items = $limit - 1;
    $offset    = $limit + 1;    # force it to page 2
    ok $result = $dispatch->_xml->_get_pageset( $pageset_args->() ),
      'We should get a pageset if we are not on the first page';

    is $result->current_page,  2, '... telling us we are on the second page';
    is $result->last_page,     5, '... and how many pages there are';
    is $result->pages_per_set, 1, '... and how many pages are in each set';
    is $result->total_entries, 100,
      '... and we should have the correct number of entries';

    $total = 57;
    $dispatch->args(
        Array::AsHash->new( { array => [ SEARCH_TYPE, 'age => GT 43' ] } ) );
    ok $result = $dispatch->_xml->_get_pageset( $pageset_args->() ),
      'Pagesets should accept search criteria';

    is $result->current_page,  2, '... telling us we are on the second page';
    is $result->last_page,     3, '... and how many pages there are';
    is $result->pages_per_set, 1, '... and how many pages are in each set';
    is $result->total_entries, 57,
      '... and we should have the correct number of entries';
}

sub class_list : Test(2) {
    my $test = shift;
    my $url  = $test->url;

    my $rest = $test->{rest};
    my $dispatch = Dispatch->new( { rest => $rest } );
    can_ok $dispatch, 'class_list';
    $rest->xslt('resources');
    $dispatch->rest($rest);
    $dispatch->class_list;
    my $header   = $test->header_xml(AVAILABLE_RESOURCES);
    my $expected = <<"    END_XML";
$header
        <kinetic:resource id="one"    xlink:href="${url}one/search"/>
        <kinetic:resource id="simple" xlink:href="${url}simple/search"/>
        <kinetic:resource id="two"    xlink:href="${url}two/search"/>
    </kinetic:resources>
    END_XML
    is_xml $rest->response, $expected,
      '... and calling it should return a list of resources';
}

sub handle : Test(6) {
    my $test     = shift;
    my $rest     = $test->{rest};
    my $dispatch = Dispatch->new( { rest => $rest } );
    my $url      = $test->url;

    can_ok $dispatch, 'handle_rest_request';
    my $key = One->my_class->key;
    $dispatch->rest($rest)->class_key($key);

    # The error message used path info
    $test->_path_info("/$key/");
    $dispatch->handle_rest_request;
    is $rest->response, "No resource available to handle (/$key/)",
      'Calling _handle_rest_request() with no method should fail';

    $dispatch->method('search');
    $dispatch->handle_rest_request;
    my $response = $rest->response;

    my ( $foo, $bar, $baz ) = $test->test_objects;

    is_well_formed_xml $response, '... and it should return well-formed XML';

    my $foo_uuid = $foo->uuid;
    $dispatch->method('lookup');
    $dispatch->args( Array::AsHash->new( { array => [ 'uuid', $foo_uuid ] } ) );
    $dispatch->handle_rest_request;
    is_well_formed_xml $rest->response,
      '... and $class_key/lookup/uuid/$uuid should return well-formed XML';

    $dispatch->method('search');
    my $args =
      Array::AsHash->new( { array => [ SEARCH_TYPE, 'name => "foo"' ] } );
    $dispatch->args( $args->clone );
    $dispatch->handle_rest_request;

    is_well_formed_xml $rest->response,
      '$class_key/search/STRING/$search_string should return well-formed xml';

    my $search_string = 'name => "foo", OR(name => "bar")';
    $args =
      Array::AsHash->new(
        { array => [ SEARCH_TYPE, $search_string, ORDER_BY_PARAM, 'name' ] } );
    $dispatch->args( $args->clone );

    $dispatch->handle_rest_request;
    is_well_formed_xml $rest->response,
      '... and complex searches with constraints should also succeed';
}

1;
