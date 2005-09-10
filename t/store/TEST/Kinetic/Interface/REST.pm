package TEST::Kinetic::Interface::REST;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use lib 't/store';
use TEST::Kinetic::Traits::Common qw/:all/;
use TEST::Kinetic::Traits::REST qw/:all/;
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

use Kinetic::Util::Constants qw/UUID_RE :xslt/;
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

use Readonly;
Readonly my $PORT   => '9000';
Readonly my $DOMAIN => "http://localhost:$PORT/";
Readonly my $PATH   => 'rest/';

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
    my $server = TEST::REST::Server->new(
        {
            domain => $DOMAIN,
            path   => $PATH,
            args   => [$PORT]
        }
    );
    $PID = $server->background;
    $test->{REST} = WWW::REST->new($DOMAIN);
    my $dispatch = sub {
        my $REST = shift;
        die $REST->status_line, "\n\n", $REST->content if $REST->is_error;
        return $REST->content;
    };
    $test->{REST}->dispatch($dispatch);
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
    $test->{test_objects} = [ $foo, $bar, $baz ];
    $test->desired_attributes( [qw/ state name description bool /] );
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

sub _xml_header {
    my $title  = shift;
    my $xslt   = $title =~ /resources/ ? RESOURCES_XSLT: SEARCH_XSLT;
    my $server = shift || 'http://localhost:9000/rest/';
    return <<"    END_XML";
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="$xslt"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                       xmlns:xlink="http://www.w3.org/1999/xlink">
      <kinetic:description>$title</kinetic:description>
    END_XML
}

sub _html_header {
    my $title = shift;
    return <<"    END_HTML";
<?xml version="1.0"?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:kinetic="http://www.kineticode.com/rest" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fo="http://www.w3.org/1999/XSL/Format">
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <title>$title</title>
      </head>
      <body>
    END_HTML
}

sub _search_form {
    my ( $search, $limit, $order_by ) = @_;
    return <<"    END_FORM";
    <form method="GET">
        <input type="hidden" name="class_key" value="one" />
        <table>
        <tr>
            <td>Search:</td>
            <td>
            <input type="text" name="search" value="$search" />
            </td>
        </tr>
        <tr>
            <td>Limit:</td>
            <td>
            <input type="text" name="limit" value="$limit" />
            </td>
        </tr>
        <tr>
            <td>Order by:</td>
            <td>
            <input type="text" name="order_by" value="$order_by" />
            </td>
        </tr>
        </table>
    </form>
    END_FORM
}

sub _url { $DOMAIN . $PATH }

sub web_test_paging : Test(14) {
    my $test = shift;
    my $mech = Test::WWW::Mechanize->new;
    my $url  = _url();

    my ( $foo, $bar, $baz ) = @{ $test->{test_objects} };

    $mech->get_ok(
        "${url}one/search/STRING/null/order_by/name/limit/2",
        'We should be able to fetch and limit the searches'
    );

    my $foo_uuid = $foo->uuid;
    my $bar_uuid = $bar->uuid;
    my $header   = _xml_header('Available instances');
    my %instance_for;
    @instance_for{qw/foo bar baz/} =
      map { $test->instance_data($_) } ( $foo, $bar, $baz );
    my $response           = $mech->content;
    my @instance_order     = $test->instance_order($response);
    my $expected_instances =
      $test->expected_instance_xml( $url, 'one', \%instance_for,
        \@instance_order );

    my $expected = <<"    END_XML";
$header
      <kinetic:domain>http://localhost:9000/</kinetic:domain>
      <kinetic:path>rest/</kinetic:path>
      $expected_instances
      <kinetic:pages>
        <kinetic:page id="[ Page 1 ]" xlink:href="@{[CURRENT_PAGE]}" />
        <kinetic:page id="[ Page 2 ]" xlink:href="${url}one/search/STRING/null/order_by/name/limit/2/offset/2" />
      </kinetic:pages>
      <kinetic:class_key>one</kinetic:class_key>
      <kinetic:search_parameters>
        <kinetic:parameter type="search"></kinetic:parameter>
        <kinetic:parameter type="limit">2</kinetic:parameter>
        <kinetic:parameter type="order_by">name</kinetic:parameter>
      </kinetic:search_parameters>
    </kinetic:resources>
    END_XML

    #is_well_formed_xml $response, 'The response should be well-formed xml';
    #diag $response;
    #return;
    is_xml $response, $expected,
      '... and have appropriate pages added, if available';

    $mech->get_ok(
        "${url}one/search/STRING/null/order_by/name/limit/2?type=html",
        'We should be able to fetch and limit the searches'
    );

    my $html_header = _html_header('Available instances');
    my $search_form = _search_form( '', 2, 'name' );

    my $instances = $test->instance_table( $bar, $foo );
    $expected = <<"    END_XHTML";
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:kinetic="http://www.kineticode.com/rest" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <title>Available instances</title>
    <script language="JavaScript1.2" type="text/javascript" src="/js/search.js"></script>
  </head>
  <body onload="document.search_form.search.focus()">
    <form method="get" name="search_form" onsubmit="javascript:do_search(this); return false" id="search_form">
      <input type="hidden" name="class_key" value="one" />
      <input type="hidden" name="domain" value="http://localhost:9000/" />
      <input type="hidden" name="path" value="rest/" />
      <table>
        <tr>
          <td>Search:</td>
          <td><input type="text" name="search" value="" /></td>
        </tr>
        <tr>
          <td>Limit:</td>
          <td><input type="text" name="limit" value="2" /></td>
        </tr>
        <tr>
          <td>Order by:</td>
          <td><input type="text" name="order_by" value="name" /></td>
        </tr>
        <tr>
          <td>Sort order:</td>
          <td>
            <select name="sort_order">
              <option value="ASC">Ascending</option>
              <option value="DESC">Descending</option>
            </select>
          </td>
        </tr>
        <tr>
          <td colspan="2">
            <input type="submit" value="Search" onclick="javascript:do_search(this)" />
          </td>
        </tr>
      </table>
    </form>
    $instances
    <p>
      [ Page 1 ]
      <a href="${url}one/search/STRING/null/order_by/name/limit/2/offset/2?type=html">[ Page 2 ]</a>
    </p>
  </body>
</html>
    END_XHTML
    is_xml $mech->content, $expected,
      '... ordering and limiting searches should work';

    $mech->get_ok(
        "${url}one/search/STRING/null/order_by/name/limit/2/offset/2?type=html",
        '... as should paging through result sets'
    );
    $instances = $test->instance_table($baz);
    $expected  = <<"    END_XHTML";
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:kinetic="http://www.kineticode.com/rest" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <title>Available instances</title>
    <script language="JavaScript1.2" type="text/javascript" src="/js/search.js"></script>
  </head>
  <body onload="document.search_form.search.focus()">
    <form method="get" name="search_form" onsubmit="javascript:do_search(this); return false" id="search_form">
      <input type="hidden" name="class_key" value="one" />
      <input type="hidden" name="domain" value="http://localhost:9000/" />
      <input type="hidden" name="path" value="rest/" />
      <table>
        <tr>
        <td>Search:</td>
          <td><input type="text" name="search" value="" /></td>
        </tr>
        <tr>
          <td>Limit:</td>
          <td><input type="text" name="limit" value="2" /></td>
        </tr>
        <tr>
          <td>Order by:</td>
          <td><input type="text" name="order_by" value="name" /></td>
        </tr>
        <tr>
          <td>Sort order:</td>
          <td>
            <select name="sort_order">
              <option value="ASC">Ascending</option>
              <option value="DESC">Descending</option>
            </select>
          </td>
        </tr>
        <tr>
          <td colspan="2">
            <input type="submit" value="Search" onclick="javascript:do_search(this)" />
          </td>
        </tr>
      </table>
    </form>
    $instances
    <p>
      <a href="${url}one/search/STRING/null/order_by/name/limit/2/offset/0?type=html">[ Page 1 ]</a>
      [ Page 2 ]
    </p>
  </body>
</html>
    END_XHTML
    is_xml $mech->content, $expected,
      '... ordering and limiting searches should work';

    $test->_clear_database;
    for ( 'A' .. 'Z' ) {
        my $object = One->new;
        $object->name($_);
        $object->save;
    }

    # now that we have 26 "One" objects in the database, let's make sure
    # that the default max list is 20
    # We should also get two pages listed, but the current page is not linked
    $mech->get_ok( "${url}one/search?type=html",
        '... as should paging through result sets' );
    my @links = $mech->links;
    is @links, 81, 'We should receive 80 instance links and 1 page links';

    $mech->get_ok(
        "${url}one/search/STRING/null/limit/30?type=html",
        'Asking for more than the limit should work'
    );
    @links = $mech->links;
    is @links, 104, '... and return only instance links';

    $mech->get_ok(
        "${url}one/search/STRING/null/limit/10?type=html",
        'Asking for fewer than the limit should work'
    );
    @links = $mech->links;
    is @links, 42, '... and return the correct number of links';

    $mech->get_ok(
        "${url}one/search/STRING/null/limit/26?type=html",
        'Asking for exactly the number of links that exist should work'
    );
    @links = $mech->links;
    is @links, 104, '... and return no page links';
}

sub web_test : Test(12) {
    my $test = shift;
    my $mech = Test::WWW::Mechanize->new;
    my $url  = _url();

    $mech->get_ok( $url, 'Gettting the main page should succeed' );
    ok !$mech->is_html, '... but it should not return HTML';
    $mech->get_ok( "$url?type=html",
        'We should be able to fetch the main page and ask for HTML' );
    ok $mech->is_html, '... and get HTML back';
    $mech->title_is( 'Available resources',
        '... and fetching the root should return a list of resources' );

    $mech->follow_link_ok(
        { url_regex => qr/simple/ },
        '... and fetching a class link should succeed',
    );
    $mech->title_is( 'Available instances',
        '... and fetching the a class should return a list of instances' );

    my ( $foo, $bar, $baz ) = @{ $test->{test_objects} };
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
        qq'${url}one/search/STRING/name => "foo"?type=html',
        'We should be able to fetch via a search'
    );

    $foo_uuid = $foo->uuid;
    my $html_header = _html_header('Available instances');
    my $search_form = _search_form( 'name =&gt; &quot;foo&quot;', 20, '' );
    my $instances   = $test->instance_table($foo);
    my $expected    = <<"    END_XHTML";
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:kinetic="http://www.kineticode.com/rest" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <title>Available instances</title>
    <script language="JavaScript1.2" type="text/javascript" src="/js/search.js"></script>
  </head>
  <body onload="document.search_form.search.focus()">
    <form method="get" name="search_form" onsubmit="javascript:do_search(this); return false" id="search_form">
      <input type="hidden" name="class_key" value="one" />
      <input type="hidden" name="domain" value="http://localhost:9000/" />
      <input type="hidden" name="path" value="rest/" />
      <table>
        <tr>
          <td>Search:</td>
          <td>
            <input type="text" name="search" value="name =&gt; &quot;foo&quot;" />
          </td>
        </tr>
        <tr>
          <td>Limit:</td>
          <td><input type="text" name="limit" value="20" /></td>
        </tr>
        <tr>
          <td>Order by:</td>
          <td><input type="text" name="order_by" value="" /></td>
        </tr>
        <tr>
          <td>Sort order:</td>
          <td>
            <select name="sort_order">
              <option value="ASC">Ascending</option>
              <option value="DESC">Descending</option>
            </select>
          </td>
        </tr>
        <tr>
          <td colspan="2">
            <input type="submit" value="Search" onclick="javascript:do_search(this)" />
          </td>
        </tr>
      </table>
    </form>
    $instances
  </body>
</html>
    END_XHTML
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

    ok $rest->handle_request( CGI->new ),
      'Searching for resources should succeed';
    is $rest->status, '200 OK', '... with an appropriate status code';
    ok $rest->response, '... and return an entity-body';

    my ( $foo, $bar, $baz ) = @{ $test->{test_objects} };
    my $foo_uuid = $foo->uuid;
    my $header   =
      _xml_header( 'Available instances', 'http://foo/rest/server/' );
    my %instance_for;
    @instance_for{qw/foo bar baz/} =
      map { $test->instance_data($_) } ( $foo, $bar, $baz );
    my $expected_instances =
      $test->expected_instance_xml( 'http://foo/rest/server/', 'one',
        \%instance_for, ['foo'] );

    my $expected = <<"    END_XML";
$header
      <kinetic:domain>http://foo/</kinetic:domain>
      <kinetic:path>rest/server/</kinetic:path>
      $expected_instances
      <kinetic:class_key>one</kinetic:class_key>
      <kinetic:search_parameters>
        <kinetic:parameter type="search">name =&gt; &quot;foo&quot;</kinetic:parameter>
        <kinetic:parameter type="limit">20</kinetic:parameter>
        <kinetic:parameter type="order_by">name</kinetic:parameter>
      </kinetic:search_parameters>
    </kinetic:resources>
    END_XML

    is_xml $rest->response, $expected,
      '$class_key/search/STRING/$search_string should return a list';
}

sub rest_faults : Test(7) {
    my $class = 'Kinetic::Interface::REST';
    my $rest  = $class->new( domain => 'http://foo/', path => 'rest/server/' );

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
    my $url  = _url();

    throws_ok { $rest->url('no_such_resource/')->get } qr/501 Not Implemented/,
      '... as should calling it with a non-existent resource';

    my $header   = _xml_header('Available resources');
    my $expected = <<"    END_XML";
$header
      <kinetic:domain>http://localhost:9000/</kinetic:domain>
      <kinetic:path>rest/</kinetic:path>
      <kinetic:resource id="one"     xlink:href="${url}one/search"/>
      <kinetic:resource id="simple"  xlink:href="${url}simple/search"/>
      <kinetic:resource id="two"     xlink:href="${url}two/search"/>
    </kinetic:resources>
    END_XML
    is_xml $rest->get, $expected,
      'Calling it without a resource should return a list of resources';

    my $key     = One->my_class->key;
    my $one_xml = $rest->url("$key/search")->get;
    my %instance_for;
    @instance_for{qw/foo bar baz/} =
      map { $test->instance_data($_) } ( @{ $test->{test_objects} } );

    # XXX Yuck.  Fix this later
    my @order = map { s/snorfleglitz/baz/; $_ } $test->instance_order($one_xml);
    my $expected_instances =
      $test->expected_instance_xml( 'http://localhost:9000/rest/', 'one',
        \%instance_for, \@order );
    $header   = _xml_header('Available instances');
    $expected = <<"    END_XML";
$header
      <kinetic:domain>http://localhost:9000/</kinetic:domain>
      <kinetic:path>rest/</kinetic:path>
      $expected_instances
      <kinetic:class_key>one</kinetic:class_key>
      <kinetic:search_parameters>
        <kinetic:parameter type="search"></kinetic:parameter>
        <kinetic:parameter type="limit">20</kinetic:parameter>
        <kinetic:parameter type="order_by"></kinetic:parameter>
      </kinetic:search_parameters>
    </kinetic:resources>
    END_XML
    is_xml $one_xml, $expected,
      'Calling it with a resource/search should return a list of instances';

    $key = Two->my_class->key;
    my $two_xml = $rest->url("$key/search")->get;
    $two_xml =~ s/@{[UUID_RE]}/XXX/g;
    diag "Clean up xml for which we have no resources";
}

sub xslt : Test(2) {
    my $test = shift;
    my $rest = $test->REST;

    is_well_formed_xml $rest->get( stylesheet => 'instance' ),
      'Requesting an instance stylesheet should return valid xml';

    is_well_formed_xml $rest->get( stylesheet => 'REST' ),
      'Requesting a REST stylesheet should return valid xml';
}

1;
