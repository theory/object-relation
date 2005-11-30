package TEST::Kinetic::UI::REST::Dispatch;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Test::JSON;
use Test::XML;

use Class::Trait qw(
  TEST::Kinetic::Traits::Store
  TEST::Kinetic::Traits::HTML
  TEST::Kinetic::Traits::JSON
);

use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(1) }

use aliased 'Test::MockModule';
use aliased 'Kinetic::Format';
use aliased 'Kinetic::UI::REST';
use aliased 'Kinetic::UI::REST::Dispatch';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';    # contains a TestApp::Simple::One object

use Readonly;
Readonly my $DOMAIN => 'http://somehost.com/';
Readonly my $PATH   => 'rest/';

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
    ? 0
    : "Not testing Data Stores"
  )
  if caller;    # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub setup : Test(setup) {
    my $test = shift;
    $test->mock_dbh;
    $test->create_test_objects;

    # set up mock cgi and path methods
    my $cgi_mock = MockModule->new('CGI');
    $cgi_mock->mock( path_info => sub { $test->_path_info } );
    my $rest_mock = MockModule->new(REST);
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
    $test->unmock_dbh;
    delete( $test->{cgi_mock} )->unmock_all;
    delete( $test->{rest_mock} )->unmock_all;
}

sub _path_info {
    my $test = shift;
    return $test->{path_info} unless @_;
    $test->{path_info} = shift;
    return $test;
}

sub handle_rest_request_xml : Test(7) {
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

    my $formatter = Format->new( { format => 'xml' } );
    $dispatch->formatter($formatter);

    #
    # testing a non-existent method
    #

    ok $dispatch->handle_rest_request(['no_such_method']),
      '... and we should be able to handle a non-existent method';
    is $rest->response, 'No resource available to handle (/one/no_such_method)',
      '... and get an appropriate error message';

    #
    # let's test squery
    #

    my %object_for;
    @object_for{qw/foo bar baz/} = $test->test_objects;
    $_->description( $_->name . " description" )->save foreach
      values %object_for;

    ok $dispatch->handle_rest_request(['squery', '', 'order_by', 'name']),
      'Calling handle_rest_request("squery") should succeed';
    ok my $response = $rest->response, '... and we should have a response';

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

    is_xml $response, $expected, '... and it should be the correct XML';
}

sub handle_rest_request : Test(19) {
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

    my $formatter = Format->new( { format => 'json' } );
    $dispatch->formatter($formatter);

    #
    # testing a non-existent method
    #

    ok $dispatch->handle_rest_request(['no_such_method']),
      '... and we should be able to handle a non-existent method';
    is $rest->response, 'No resource available to handle (/one/no_such_method)',
      '... and get an appropriate error message';

    #
    # let's test squery
    #

    my %object_for;
    @object_for{qw/foo bar baz/} = $test->test_objects;
    $_->description( $_->name . " description" )->save foreach
      values %object_for;

    ok $dispatch->handle_rest_request(['squery']),
      'Calling handle_rest_request("squery") should succeed';
    ok my $response = $rest->response, '... and we should have a response';

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

    $response =
      $test->sort_json(
        { json => $response, values => [qw/foo bar snorfleglitz/] } );
    is_json $response, $expected, '... and it should be the correct JSON';

    ok $dispatch->handle_rest_request([ 'squery', 'name => "foo"' ]),
      'Calling handle_rest_request("squery", \'name => "foo"\') should succeed';
    ok $response = $rest->response, '... and we should have a response';

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
    is_json $response, $expected, '... and it should be the correct JSON';

    ok $dispatch->handle_rest_request([ 'squery', '', order_by => 'name' ]),
'Calling handle_rest_request("squery", "", order_by => "name") should succeed';
    ok $response = $rest->response, '... and we should have a response';

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
    is_json $response, $expected, '... and it should be the correct JSON';

    #
    # let's test squery_uuids
    #

    ok $dispatch->handle_rest_request([ 'squery_uuids', '', order_by => 'name' ]),
'Calling handle_rest_request("squery_uuids", "", order_by => "name") should succeed';
    ok $response = $rest->response, '... and we should have a response';
    $expected = <<"    END_JSON";
    [
        "@{[$object_for{bar}->uuid]}",
        "@{[$object_for{foo}->uuid]}",
        "@{[$object_for{baz}->uuid]}"
    ]
    END_JSON
    is_json $response, $expected, '... and it should be the correct JSON';

    #
    # testing lookup
    #

    ok $dispatch->handle_rest_request( ['lookup',
        uuid => $object_for{bar}->uuid ]),
      'Calling handle_rest_request("lookup", uuid => $uuid) shoud succed';

    ok $response = $rest->response, '... and we should have a response';
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
    is_json $response, $expected, '... and it should be the correct response';
}

1;
