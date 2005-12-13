package TEST::Kinetic::UI::REST;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Class::Trait qw(
  TEST::Kinetic::Traits::Store
  TEST::Kinetic::Traits::HTML
  TEST::Kinetic::Traits::JSON
);
use Test::More;
use Test::Exception;
use Test::JSON;
use Test::XML;

{
    local $^W;

    # XXX a temporary hack until we get a new
    # WWW::REST version checked in which doesn't warn
    # about a redefined constructor
    require WWW::REST;
}

use Kinetic::Util::Constants qw/:http :rest/;
use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(0) }
use TEST::REST::Server;

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';

use aliased 'Kinetic::UI::REST';
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
    $test->dbh( $store->_dbh );
    $test->clear_database;
    $test->dbh->begin_work;
    $test->create_test_objects;
    $test->desired_attributes( [qw/ state name description bool /] );
    $test->domain('http://localhost:9000')->path('rest')
      ->query_string("$TYPE_PARAM=html");
}

sub teardown : Test(teardown) {
    shift->clear_database;
}

sub server { shift->{REST} }

sub chained_calls : Test(6) {
    my $test = shift;

    my %object_for;
    @object_for{qw/foo bar baz/} = $test->test_objects;
    $_->description( $_->name . " description" )->save foreach
      values %object_for;

    my $rest = REST->new( domain => 'http://foo/', path => 'rest/server/' );
    $test->domain('http://foo/');
    $test->path('rest/server/');

    my $cgi_mock = MockModule->new('CGI');
    $cgi_mock->mock(
        path_info => '/json/one/squery/name EQ "bar",name/rab,save' );

    ok $rest->handle_request( CGI->new ), 'A chained call should succeed';
    is $rest->status, $HTTP_OK, '... with an appropriate status code';
    ok $rest->response, '... and return an entity-body';
    my $expected = <<"    END_JSON";
    [
      {
        "bool" : 1,
        "name" : "rab",
        "Key" : "one",
        "uuid" : "@{[$object_for{bar}->uuid]}",
        "description" : "bar description",
        "state" : 1
      }
    ]
    END_JSON
    is_json $rest->response, $expected, '... and it should be the correct JSON';

    my ( $foo, $bar, $baz ) = $test->test_objects;
    my $class = $bar->my_class;
    my $store = Kinetic::Store->new;
    ok my $iter = $store->squery( $class, 'name EQ "rab"' ),
      '... and searching for the munged object should succeed';
    my $object = $iter->next;
    is $object->uuid, $bar->uuid,
      '... and it should really be the correct object';
}

sub constructor : Test(14) {
    my $test = shift;
    can_ok REST, 'new';
    throws_ok { REST->new }
      'Kinetic::Util::Exception::Fatal::RequiredArguments',
      '... and it should fail if domain and path are not present';

    throws_ok { REST->new( domain => 'http://foo/' ) }
      'Kinetic::Util::Exception::Fatal::RequiredArguments',
      '... or if just domain is present';

    throws_ok { REST->new( path => 'rest/' ) }
      'Kinetic::Util::Exception::Fatal::RequiredArguments',
      '... or if just path is present';

    ok my $rest = REST->new( domain => 'http://foo/', path => 'rest/server/' ),
      'We should be able to create a basic REST object';
    isa_ok $rest, REST, '... and the object';

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

    $rest = REST->new( domain => 'http://foo', path => '/rest/server' ),
      is $rest->domain, 'http://foo/',
      'Domains without a trailing slash should have it appended';

    is $rest->path, 'rest/server/',
'... and paths should have leading slashes removed and trailing slashes added';
}

sub rest_interface_xml : Test(4) {
    my $test = shift;

    my %object_for;
    @object_for{qw/foo bar baz/} = $test->test_objects;
    $_->description( $_->name . " description" )->save foreach
      values %object_for;

    my $rest = REST->new( domain => 'http://foo/', path => 'rest/server/' );
    $test->domain('http://foo/');
    $test->path('rest/server/');

    my $cgi_mock = MockModule->new('CGI');
    $cgi_mock->mock( path_info => '/xml/one/squery/order_by/name' );

    ok $rest->handle_request( CGI->new ), 'An empty squery should succeed';
    is $rest->status, $HTTP_OK, '... with an appropriate status code';
    ok $rest->response, '... and return an entity-body';
    my $expected = <<"    END_XML";
    <opt>
        <anon 
            name="bar" 
            Key="one" 
            bool="1" 
            description="bar description" 
            state="1" 
            uuid="@{[$object_for{bar}->uuid]}" />
        <anon 
            name="foo" 
            Key="one" 
            bool="1" 
            description="foo description" 
            state="1" 
            uuid="@{[$object_for{foo}->uuid]}" />
        <anon 
            name="snorfleglitz" 
            Key="one" 
            bool="1" 
            description="snorfleglitz description" 
            state="1" 
            uuid="@{[$object_for{baz}->uuid]}" />
    </opt>
    END_XML
    is_xml $rest->response, $expected, '... and it should be the correct XML';
}

sub rest_interface : Test(32) {
    my $test = shift;

    my %object_for;
    @object_for{qw/foo bar baz/} = $test->test_objects;
    $_->description( $_->name . " description" )->save foreach
      values %object_for;

    my $rest = REST->new( domain => 'http://foo/', path => 'rest/server/' );
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
    $cgi_mock->mock( path_info => '/json/one/squery' );

    ok $rest->handle_request( CGI->new ), 'An empty squery should succeed';
    is $rest->status, $HTTP_OK, '... with an appropriate status code';
    ok $rest->response, '... and return an entity-body';
    my $expected = <<"    END_JSON";
    [
      {
        "bool" : 1,
        "name" : "foo",
        "Key" : "one",
        "uuid" : "@{[$object_for{foo}->uuid]}",
        "description" : "foo description",
        "state" : 1
      },
      {
        "bool" : 1,
        "name" : "bar",
        "Key" : "one",
        "uuid" : "@{[$object_for{bar}->uuid]}",
        "description" : "bar description",
        "state" : 1
      },
      {
        "bool" : 1,
        "name" : "snorfleglitz",
        "Key" : "one",
        "uuid" : "@{[$object_for{baz}->uuid]}",
        "description" : "snorfleglitz description",
        "state" : 1
      }
    ]
    END_JSON
    my $response = $test->sort_json(
        {
            json   => $rest->response,
            values => [qw(foo bar snorfleglitz)],
        }
    );
    is_json $response, $expected, '... and it should be the correct JSON';

    # Note that because of the way we're mocking up path_info, URL encoding
    # of parameters is *not* necessary

    $cgi_mock->mock(
        path_info => '/json/one/squery/name => "foo"/order_by/name', );

    ok $rest->handle_request( CGI->new ),
      'An squery with a query and constraints should succeed';
    is $rest->status, $HTTP_OK, '... with an appropriate status code';
    ok $rest->response, '... and return an entity-body';
    $expected = <<"    END_JSON";
    [
      {
        "bool" : 1,
        "name" : "foo",
        "Key" : "one",
        "uuid" : "@{[$object_for{foo}->uuid]}",
        "description" : "foo description",
        "state" : 1
      }
    ]
    END_JSON
    is_json $rest->response, $expected, '... and it should be the correct JSON';

    $cgi_mock->mock( path_info => '/json/one/squery/order_by/name', );

    ok $rest->handle_request( CGI->new ),
      'An squery with constraints but no query should succeed';
    is $rest->status, $HTTP_OK, '... with an appropriate status code';
    ok $rest->response, '... and return an entity-body';

    $expected = <<"    END_JSON";
    [
      {
        "bool" : 1,
        "name" : "bar",
        "Key" : "one",
        "uuid" : "@{[$object_for{bar}->uuid]}",
        "description" : "bar description",
        "state" : 1
      },
      {
        "bool" : 1,
        "name" : "foo",
        "Key" : "one",
        "uuid" : "@{[$object_for{foo}->uuid]}",
        "description" : "foo description",
        "state" : 1
      },
      {
        "bool" : 1,
        "name" : "snorfleglitz",
        "Key" : "one",
        "uuid" : "@{[$object_for{baz}->uuid]}",
        "description" : "snorfleglitz description",
        "state" : 1
      }
    ]
    END_JSON
    is_json $rest->response, $expected, '... and it should be the correct JSON';

    $cgi_mock->mock( path_info => '/json/one/squery_uuids/order_by/name/' );
    ok $rest->handle_request( CGI->new ),
      'squery_uuids with constraints but no query should succeed';
    is $rest->status, $HTTP_OK, '... with an appropriate status code';
    ok $rest->response, '... and we should have a response';
    $expected = <<"    END_JSON";
    [
        "@{[$object_for{bar}->uuid]}",
        "@{[$object_for{foo}->uuid]}",
        "@{[$object_for{baz}->uuid]}"
    ]
    END_JSON
    is_json $rest->response, $expected, '... and it should be the correct JSON';

    $cgi_mock->mock(
        path_info => '/json/one/lookup/uuid/' . $object_for{bar}->uuid );
    ok $rest->handle_request( CGI->new ),
      '$class_key/lookup/uuid/$uuid should succeed';
    is $rest->status, $HTTP_OK, '... with an appropriate status code';
    ok $rest->response, '... and we should have a response';

    $expected = <<"    END_JSON";
      {
        "bool" : 1,
        "name" : "bar",
        "Key" : "one",
        "uuid" : "@{[$object_for{bar}->uuid]}",
        "description" : "bar description",
        "state" : 1
      }
    END_JSON
    is_json $rest->response, $expected,
      '... and it should be the correct response';
}

sub rest_faults : Test(11) {
    my $test = shift;

    my %object_for;
    @object_for{qw/foo bar baz/} = $test->test_objects;
    $_->description( $_->name . " description" )->save foreach
      values %object_for;

    my $rest = REST->new( domain => 'http://foo/', path => 'rest/server/' );
    $test->domain('http://foo/');
    $test->path('rest/server/');

    my $cgi_mock = MockModule->new('CGI');
    $cgi_mock->mock( path_info => '/json/one/query' );

    ok $rest->handle_request( CGI->new ),
      'An unavailable method should succeed';
  TODO: {
        local $TODO = 'Not sure of the best way to restrict these methods';
        is $rest->status, $HTTP_NOT_IMPLEMENTED,
          '... with an appropriate status code';
    }
    ok $rest->response, '... and return an entity-body';

    $cgi_mock->mock( path_info => '/json/one/no_such_method/' );

    ok $rest->handle_request( CGI->new ),
      'An unavailable method should succeed';
    is $rest->status, $HTTP_NOT_IMPLEMENTED,
      '... with an appropriate status code';
    ok $rest->response, '... and return an entity-body';
    like $rest->response,
qr{No resource available to handle ./json/one/no_such_method/no_such_method.},
      '... with a reasonable error message';

    $cgi_mock->mock( path_info => '/json/one/squery/name' );
    ok $rest->handle_request( CGI->new ), 'An malformed squery should succeed';
    is $rest->status, $HTTP_INTERNAL_SERVER_ERROR,
      '... with an appropriate status code';
    ok $rest->response, '... and return an entity-body';
    like $rest->response,
qr{\QFatal error handling /json/one/squery/name: Could not parse search request},
      '... with a reasonable error message';
}

1;
