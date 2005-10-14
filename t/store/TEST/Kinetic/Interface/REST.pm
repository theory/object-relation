package TEST::Kinetic::Interface::REST;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use TEST::Kinetic::Traits::Store qw/:all/;
use TEST::Kinetic::Traits::XML qw/:all/;
use TEST::Kinetic::Traits::HTML qw/:all/;
use Test::More;
use Test::Exception;
use Test::WWW::Mechanize;
use Test::XML;
use XML::Parser;
{
    local $^W;

    # XXX a temporary hack until we get a new
    # WWW::REST version checked in which doesn't warn
    # about a redefined constructor
    require WWW::REST;
}

use Kinetic::Util::Constants qw/:rest UUID_RE :xslt :labels/;
use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(1) }
use TEST::REST::Server;

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';

use aliased 'Kinetic::DateTime';
use aliased 'Kinetic::DateTime::Incomplete';
use aliased 'Kinetic::Util::Iterator';
use aliased 'Kinetic::Util::State';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';    # contains a TestApp::Simple::One object

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
    ? 0
    : "Not testing Data Stores"
  )
  if caller;    # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

my $PID;

sub start_server : Test(startup) {
    my $test   = shift;
    my $port   = '9000';
    my $domain = "http://localhost:$port/";
    my $path   = 'rest/';

    my $server = TEST::REST::Server->new(
        {
            domain => $domain,
            path   => $path,
            args   => [$port]
        }
    );
    $PID = $server->background;
    $test->{REST} = WWW::REST->new($domain);
    my $dispatch = sub {
        my $REST = shift;
        die $REST->status_line, "\n\n", $REST->content if $REST->is_error;
        return $REST->content;
    };
    $test->{REST}->dispatch($dispatch);
    $test->domain($domain);
    $test->path($path);
}

sub shutdown_server : Test(shutdown) {
    kill 9, $PID if $PID;
    sleep 2;
}

sub setup : Test(setup) {

    # XXX Note that we aren't mocking this up.  Because the REST server
    # is in a different process, mocking up the database methods to
    # prevent accidental commits means the other process will never see
    # these records.  Instead, what we do is the somewhat dubious practice
    # of iterating through the object types and deleting all of them
    # when these tests end.
    my $test  = shift;
    my $store = Store->new;
    $test->{dbh} = $store->_dbh;
    $test->_clear_database;
    $test->{dbh}->begin_work;
    my $foo = One->new;
    $foo->name('foo');
    $foo->save;
    my $bar = One->new;
    $bar->name('bar');
    $bar->save;
    my $baz = One->new;
    $baz->name('snorfleglitz');
    $baz->save;
    $test->test_objects( [ $foo, $bar, $baz ] );
    $test->desired_attributes( [qw/ state name description bool /] );
    $test->domain('http://localhost:9000')->path('rest')
      ->query_string("@{[TYPE_PARAM]}=html");
}

sub teardown : Test(teardown) {
    shift->_clear_database;
}

sub _clear_database {
    my $test = shift;
    foreach my $key ( Kinetic::Meta->keys ) {
        next if Kinetic::Meta->for_key($key)->abstract;
        eval { $test->{dbh}->do("DELETE FROM $key") };
        diag "Could not delete records from $key: $@" if $@;
    }
}

sub REST { shift->{REST} }

sub search_by_query_string : Test(8) {
    my $test = shift;
    my $mech = Test::WWW::Mechanize->new;
    my $url  = $test->url;

    my ( $foo, $bar, $baz ) = $test->test_objects;
    $test->query_string('');

    $mech->get_ok(
"${url}?@{[CLASS_KEY_PARAM]}=one;search=;order_by=name;limit=2;sort_order=",
        'We should be able to search by query string'
    );

    my $foo_uuid           = $foo->uuid;
    my $bar_uuid           = $bar->uuid;
    my $header             = $test->header_xml(AVAILABLE_INSTANCES);
    my $response           = $mech->content;
    my @instance_order     = $test->instance_order($response);
    my $expected_instances =
      $test->expected_instance_xml( [ $foo, $bar, $baz ], \@instance_order );
    my $resources = $test->resource_list_xml;
    my $search    =
      $test->search_data_xml(
        { key => 'one', limit => 2, order_by => 'name' } );
    my $sort_info_xml =
      $test->column_sort_xml( 'one',
        Array::AsHash->new( { array => [ order_by => 'name', limit => 2 ] } ) );
    my $expected = <<"    END_XML";
$header
      $resources
      $sort_info_xml
      $expected_instances
      <kinetic:pages>
        <kinetic:page id="[ Page 1 ]" xlink:href="@{[CURRENT_PAGE]}" />
        <kinetic:page id="[ Page 2 ]" xlink:href="${url}one/search/STRING/null/limit/2/offset/2/order_by/name/sort_order/ASC" />
      </kinetic:pages>
      $search
    </kinetic:resources>
    END_XML

    is_xml $response, $expected, '... and have the correct data returned';

    $mech->get_ok(
"${url}one/search?@{[CLASS_KEY_PARAM]}=one;search=;order_by=name;limit=2;sort_order=",
        'We should be able to search with a query string and partial path info'
    );
    is_xml $response, $expected, '... and have the correct data returned';

    $test->query_string("@{[TYPE_PARAM]}=html");
    $mech->get_ok(
"${url}?@{[CLASS_KEY_PARAM]}=one;search=;order_by=name;limit=2;sort_order=;@{[TYPE_PARAM]}=html",
        'We should be able to fetch and limit the searches'
    );

    my $html_header    = $test->header_html(AVAILABLE_INSTANCES);
    my $html_resources = $test->resource_list_html;
    my $search_form    =
      $test->search_form( { key => 'one', limit => 2, order_by => 'name' } );
    my $instances = $test->instance_table(
        {
            args => Array::AsHash->new(
                { array => [ limit => 2, order_by => 'name' ] }
            ),
            objects => [ $bar, $foo ]
        }
    );
    my $footer = $test->footer_html;

    $expected = <<"    END_XHTML";
$html_header
    $html_resources
    $search_form
    $instances
    <div class="pages">
      <p>
        [ Page 1 ]
        <a href="${url}one/search/STRING/null/limit/2/offset/2/order_by/name/sort_order/ASC?@{[TYPE_PARAM]}=html">[ Page 2 ]</a>
      </p>
    </div>
    $footer
    END_XHTML
    is_xml $mech->content, $expected,
      '... ordering and limiting searches should work';

    $mech->get_ok(
"${url}?@{[CLASS_KEY_PARAM]}=one;search=;order_by=name;limit=2;sort_order=;offset=2;@{[TYPE_PARAM]}=html",
        '... as should paging through result sets'
    );
    $instances = $test->instance_table(
        {
            args =>
              Array::AsHash->new( { array => [ limit => 2, offset => 2, order_by => 'name' ] } ),
            objects => [$baz]
        }
    );
    $html_header    = $test->header_html(AVAILABLE_INSTANCES);
    $html_resources = $test->resource_list_html;

    $expected = <<"    END_XHTML";
$html_header
    $html_resources
    $search_form
    $instances
    <div class="pages">
      <p>
        <a href="${url}one/search/STRING/null/limit/2/offset/0/order_by/name/sort_order/ASC?@{[TYPE_PARAM]}=html">[ Page 1 ]</a>
        [ Page 2 ]
      </p>
    </div>
    $footer
    END_XHTML
    is_xml $mech->content, $expected,
      '... ordering and limiting searches should work';
}

sub web_test_paging : Test(15) {
    my $test = shift;
    my $mech = Test::WWW::Mechanize->new;
    my $url  = $test->url;

    my ( $foo, $bar, $baz ) = $test->test_objects;
    $test->query_string('');

    $mech->get_ok(
        "${url}one/search/STRING/null/order_by/name/limit/2",
        'We should be able to fetch and limit the searches'
    );

    my $foo_uuid       = $foo->uuid;
    my $bar_uuid       = $bar->uuid;
    my $header         = $test->header_xml(AVAILABLE_INSTANCES);
    my $response       = $mech->content;
    my @instance_order = $test->instance_order($response);
    my $sort_info_xml  =
      $test->column_sort_xml( 'one',
        Array::AsHash->new( { array => [ order_by => 'name', limit => 2 ] } ) );
    my $expected_instances =
      $test->expected_instance_xml( [ $foo, $bar, $baz ], \@instance_order );
    my $resources = $test->resource_list_xml;
    my $search    =
      $test->search_data_xml(
        { key => 'one', limit => 2, order_by => 'name' } );
    my $expected = <<"    END_XML";
$header
      $resources
      $sort_info_xml
      $expected_instances
      <kinetic:pages>
        <kinetic:page id="[ Page 1 ]" xlink:href="@{[CURRENT_PAGE]}" />
        <kinetic:page id="[ Page 2 ]" xlink:href="${url}one/search/STRING/null/limit/2/offset/2/order_by/name/sort_order/ASC" />
      </kinetic:pages>
      $search
    </kinetic:resources>
    END_XML

    is_xml $response, $expected,
      '... and have appropriate pages added, if available';

    $test->query_string("@{[TYPE_PARAM]}=html");
    $mech->get_ok(
"${url}one/search/STRING/null/order_by/name/limit/2?@{[TYPE_PARAM]}=html",
        'We should be able to fetch and limit the searches'
    );

    my $html_header    = $test->header_html(AVAILABLE_INSTANCES);
    my $html_resources = $test->resource_list_html;
    my $search_form    =
      $test->search_form( { key => 'one', limit => 2, order_by => 'name' } );
    my $instances = $test->instance_table(
        {
            args => Array::AsHash->new(
                { array => [ limit => 2, order_by => 'name' ] }
            ),
            objects => [ $bar, $foo ]
        }
    );
    my $footer = $test->footer_html;

    $expected = <<"    END_XHTML";
$html_header
    $html_resources
    $search_form
    $instances
    <div class="pages">
      <p>
        [ Page 1 ]
        <a href="${url}one/search/STRING/null/limit/2/offset/2/order_by/name/sort_order/ASC?@{[TYPE_PARAM]}=html">[ Page 2 ]</a>
      </p>
    </div>
    $footer
    END_XHTML
    is_xml $mech->content, $expected,
      '... ordering and limiting searches should work';

    $mech->get_ok(
"${url}one/search/STRING/null/order_by/name/limit/2/offset/2?@{[TYPE_PARAM]}=html",
        '... as should paging through result sets'
    );
    $instances = $test->instance_table(
        {
            args => Array::AsHash->new(
                { array => [ offset => 2, limit => 2, order_by => 'name' ] }
            ),
            objects => [$baz]
        }
    );
    $html_header    = $test->header_html(AVAILABLE_INSTANCES);
    $html_resources = $test->resource_list_html;

    $expected = <<"    END_XHTML";
$html_header
    $html_resources
    $search_form
    $instances
    <div class="pages">
      <p>
        <a href="${url}one/search/STRING/null/limit/2/offset/0/order_by/name/sort_order/ASC?@{[TYPE_PARAM]}=html">[ Page 1 ]</a>
        [ Page 2 ]
      </p>
    </div>
    $footer
    END_XHTML
    is_xml $mech->content, $expected,
      '... ordering and limiting searches should work';

    $mech->get_ok(
"${url}one/search/STRING/null/order_by/name/limit/2/offset/2?@{[TYPE_PARAM]}=html",
        '... as should paging through result sets'
    );

    $test->_clear_database;
    for ( 'A' .. 'Z' ) {
        my $object = One->new;
        $object->name($_);
        $object->save;
    }

    # now that we have 26 "One" objects in the database, let's make sure
    # that the default max list is 20
    # We should also get two pages listed, but the current page is not linked
    $mech->get_ok(
        "${url}one/search?@{[TYPE_PARAM]}=html",
        '... as should paging through result sets'
    );
    my @links = $mech->links;
    is @links, 88,
'We should receive 80 instance links, 1 page link, 3 resource links and 4 header links';

    $mech->get_ok( "${url}one/search/STRING/null/limit/30?@{[TYPE_PARAM]}=html",
        'Asking for more than the limit should work' );
    @links = $mech->links;
    is @links, 111, '... and return only instance links';

    $mech->get_ok( "${url}one/search/STRING/null/limit/10?@{[TYPE_PARAM]}=html",
        'Asking for fewer than the limit should work' );
    @links = $mech->links;
    is @links, 49, '... and return the correct number of links';

    $mech->get_ok(
        "${url}one/search/STRING/null/limit/26?@{[TYPE_PARAM]}=html",
        'Asking for exactly the number of links that exist should work'
    );
    @links = $mech->links;
    is @links, 111, '... and return no page links';
}

sub web_test : Test(12) {
    my $test = shift;
    my $mech = Test::WWW::Mechanize->new;
    my $url  = $test->url;

    $mech->get_ok( $url, 'Gettting the main page should succeed' );
    ok !$mech->is_html, '... but it should not return HTML';
    $mech->get_ok( "$url?@{[TYPE_PARAM]}=html",
        'We should be able to fetch the main page and ask for HTML' );
    ok $mech->is_html, '... and get HTML back';
    $mech->title_is( AVAILABLE_RESOURCES,
        '... and fetching the root should return a list of resources' );

    $mech->follow_link_ok(
        { url_regex => qr/simple/ },
        '... and fetching a class link should succeed',
    );
    $mech->title_is( AVAILABLE_INSTANCES,
        '... and fetching the a class should return a list of instances' );

    my ( $foo, $bar, $baz ) = $test->test_objects;
    my $foo_uuid = $foo->uuid;

    $mech->follow_link_ok(
        { url_regex => qr/$foo_uuid/ },
        '... and fetching an instance link should succeed',
    );
    $mech->title_is( 'simple',
        '... and fetching an instance of a class should return the html for it'
    );
    $mech->content_like( qr/$foo_uuid/,
        '... and it should be able to identify the object' );

    $mech->get_ok(
        qq'${url}one/search/STRING/name => "foo"?@{[TYPE_PARAM]}=html',
        'We should be able to fetch via a search' );

    $foo_uuid = $foo->uuid;
    my $html_header    = $test->header_html(AVAILABLE_INSTANCES);
    my $html_resources = $test->resource_list_html;
    my $search_form    =
      $test->search_form( { key => 'one', search => 'name => "foo"' } );
    my $instances = $test->instance_table(
        {
            args =>
              Array::AsHash->new( { array => [ STRING => 'name => "foo"' ] } ),
            objects => [$foo]
        }
    );
    my $footer = $test->footer_html;

    my $expected = <<"    END_XHTML";
$html_header
    $html_resources
    $search_form
    $instances
    $footer
    END_XHTML
    use TEST::Kinetic::Traits::Debug;
    is_xml $mech->content, $expected,
'REST strings searches with HTML type specified should return the correct HTML';
}

sub constructor : Test(14) {
    my $class = 'Kinetic::Interface::REST';
    can_ok $class, 'new';
    throws_ok { $class->new }
      'Kinetic::Util::Exception::Fatal::RequiredArguments',
      '... and it should fail if domain and path are not present';

    throws_ok { $class->new( domain => 'http://foo/' ) }
      'Kinetic::Util::Exception::Fatal::RequiredArguments',
      '... or if just domain is present';

    throws_ok { $class->new( path => 'rest/' ) }
      'Kinetic::Util::Exception::Fatal::RequiredArguments',
      '... or if just path is present';

    ok my $rest =
      $class->new( domain => 'http://foo/', path => 'rest/server/' ),
      'We should be able to create a basic REST object';
    isa_ok $rest, $class, '... and the object';

    can_ok $rest, 'domain';
    is $rest->domain, 'http://foo/',
      '... and it should return the domain we set in the constructor';
    $rest->domain('xxx');
    is $rest->domain, 'http://foo/',
      '... but we should not be able to change it';

    can_ok $rest, 'path';
    is $rest->path, 'rest/server/',
      '... and it should return the path we set in the constructor';
    $rest->path('xxx');
    is $rest->path, 'rest/server/',
      '... but we should not be able to change it';

    $rest = $class->new( domain => 'http://foo', path => '/rest/server' ),
      is $rest->domain, 'http://foo/',
      'Domains without a trailing slash should have it appended';

    is $rest->path, 'rest/server/',
'... and paths should have leading slashes removed and trailing slashes added';
}

sub rest_interface : Test(19) {
    my $test  = shift;
    my $class = 'Kinetic::Interface::REST';
    my $rest  = $class->new( domain => 'http://foo/', path => 'rest/server/' );
    $test->domain('http://foo/');
    $test->path('rest/server/');

    foreach my $method (qw/cgi status response content_type/) {
        can_ok $rest, $method;
        ok !$rest->$method, '... and it should be false with a new REST object';
        $rest->$method('xxx');
        is $rest->$method, 'xxx',
          '... but we should be able to set it to a new value';
    }

    my $cgi_mock = MockModule->new('CGI');
    $cgi_mock->mock( path_info => '/one/search' );

    ok $rest->handle_request( CGI->new ),
      'Handling a good resource should succeed';
    is $rest->status, '200 OK', '... with an appropriate status code';
    ok $rest->response, '... and return an entity-body';

    # Note that because of the way we're mocking up path_info, URL encoding
    # of parameters is *not* necessary
    $cgi_mock->mock(
        path_info => '/one/search/STRING/name => "foo"/order_by/name', );

    $test->query_string('');
    ok $rest->handle_request( CGI->new ),
      'Searching for resources should succeed';
    is $rest->status, '200 OK', '... with an appropriate status code';
    ok $rest->response, '... and return an entity-body';

    my ( $foo, $bar, $baz ) = $test->test_objects;
    my $header        = $test->header_xml(AVAILABLE_INSTANCES);
    my $sort_info_xml = $test->column_sort_xml(
        'one',
        Array::AsHash->new(
            { array => [ STRING => 'name => "foo"', order_by => 'name' ] }
        )
    );
    my $instances = $test->expected_instance_xml( [$foo] );
    my $resources = $test->resource_list_xml;
    my $search    =
      $test->search_data_xml(
        { key => 'one', search => 'name => "foo"', order_by => 'name' } );

    my $expected = <<"    END_XML";
$header
      $resources
      $sort_info_xml
      $instances
      $search
    </kinetic:resources>
    END_XML

    is_xml $rest->response, $expected,
      '$class_key/search/STRING/$search_string should return a list';
}

sub rest_faults : Test(7) {
    my $test  = shift;
    my $class = 'Kinetic::Interface::REST';
    my $rest  = $class->new( domain => 'http://foo/', path => 'rest/server/' );
    $test->domain('http://foo/');
    $test->path('rest/server/');

    # set up necessary mocked packages for handle_request() tests
    can_ok $rest, 'handle_request';
    my $cgi_mock = MockModule->new('CGI');
    $cgi_mock->mock( path_info => '/foo/bar' );

    ok $rest->handle_request( CGI->new ),
      '... and handling a bad resource should succeed';
    is $rest->status, '501 Not Implemented',
      '... with an appropriate status code';
    is $rest->response, 'No resource available to handle (/foo/bar)',
      '... and a human readable response';

    my $dispatch_mock = MockModule->new('Kinetic::Interface::REST::Dispatch');
    $dispatch_mock->mock( _handle_rest_request => sub { die "woobly" } );
    ok $rest->handle_request( CGI->new ),
      'Handling a fatal resource should succeed';
    is $rest->status, '501 Not Implemented',
      '... with an appropriate status code';
    is $rest->response, 'No resource available to handle (/foo/bar)',
      '... and a human readable response';
}

sub basic_services : Test(3) {
    my $test = shift;
    my $rest = $test->REST;
    my $url  = $test->url;

    throws_ok { $rest->url('no_such_resource/')->get } qr/501 Not Implemented/,
      '... as should calling it with a non-existent resource';

    $test->query_string('');
    my $header    = $test->header_xml(AVAILABLE_RESOURCES);
    my $resources = $test->resource_list_xml;
    my $expected  = <<"    END_XML";
$header
    $resources
    </kinetic:resources>
    END_XML
    is_xml $rest->get, $expected,
      'Calling it without a resource should return a list of resources';

    my $key     = One->my_class->key;
    my $one_xml = $rest->url("$key/search")->get;

    # XXX Yuck.  Fix this later
    my @order         = $test->instance_order($one_xml);
    my $sort_info_xml = $test->column_sort_xml('one');
    my $instances     =
      $test->expected_instance_xml( scalar $test->test_objects, \@order );
    $header = $test->header_xml(AVAILABLE_INSTANCES);
    my $search = $test->search_data_xml( { key => 'one' } );
    $expected = <<"    END_XML";
$header
      $resources
      $sort_info_xml
      $instances
      $search
    </kinetic:resources>
    END_XML
    is_xml $one_xml, $expected,
      'Calling it with a resource/search should return a list of instances';

    $key = Two->my_class->key;
    my $two_xml = $rest->url("$key/search")->get;
    $two_xml =~ s/@{[UUID_RE]}/XXX/g;
}

sub xslt : Test(3) {
    my $test = shift;
    my $rest = $test->REST;

    is_well_formed_xml $rest->get( stylesheet => 'instance' ),
      'Requesting an "instance" stylesheet should return valid xml';

    is_well_formed_xml $rest->get( stylesheet => 'search' ),
      'Requesting a "search" stylesheet should return valid xml';

    is_well_formed_xml $rest->get( stylesheet => 'resources' ),
      'Requesting a "resources" stylesheet should return valid xml';
}

1;
