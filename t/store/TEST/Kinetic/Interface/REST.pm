package TEST::Kinetic::Interface::REST;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
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

use Kinetic::Util::Constants qw/GUID_RE/;
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

use constant DOMAIN => 'localhost';
use constant PORT   => '9000';

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
            domain => 'http://localhost:9000/',
            path   => 'rest/',
            args   => [PORT]
        }
    );
    $PID = $server->background;
    my $domain = sprintf "%s:%s" => DOMAIN, PORT;
    $test->{REST} = WWW::REST->new("http://$domain");
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
    $test->clear_database;
    $test->{dbh}->begin_work;
    my $foo = One->new;
    $foo->name('foo');
    $store->save($foo);
    my $bar = One->new;
    $bar->name('bar');
    $store->save($bar);
    my $baz = One->new;
    $baz->name('snorfleglitz');
    $store->save($baz);
    $test->{test_objects} = [ $foo, $bar, $baz ];
}

sub teardown : Test(teardown) {
    shift->clear_database;
}

sub clear_database {
    my $test = shift;
    foreach my $key ( Kinetic::Meta->keys ) {
        next if Kinetic::Meta->for_key($key)->abstract;
        eval { $test->{dbh}->do("DELETE FROM $key") };
        diag "Could not delete records from $key: $@" if $@;
    }
}

sub REST { shift->{REST} }

sub web_test : Test(no_plan) {
    my $test = shift;
    my $mech = Test::WWW::Mechanize->new;
    $mech->get_ok(
        sprintf('http://%s:%d?type=html', DOMAIN, PORT),
        'We should be able to fetch the main page'
    );
    $mech->title_is(
        'Available resources',
        '... and fetching the root should return a list of resources'
    );
    $mech->follow_link_ok( 
        {url_regex => qr/simple/},
        '... and fetching a class link should succeed',
    );
    $mech->title_is(
        'Available instances',
        '... and fetching the a class should return a list of instances'
    );

    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    my $foo_guid = $foo->guid;

    $mech->follow_link_ok( 
        {url_regex => qr/$foo_guid/},
        '... and fetching an instance link should succeed',
    );
    $mech->title_is(
        'simple',
        '... and fetching an instance of a class should return the html for it'
    );
    $mech->content_like(
        qr/$foo_guid/,
        '... and it should be able to identify the object'
    );
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

sub rest_interface : Test(no_plan) {
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

    my $dispatch_mock = MockModule->new('Kinetic::Interface::REST::Dispatch');

    ok $rest->handle_request( CGI->new ),
      'Handling a good resource should succeed';
    is $rest->status, '200 OK', '... with an appropriate status code';
    ok $rest->response, '... and return an entity-body';
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
    is $rest->status, '500 Internal Server Error',
      '... with an appropriate status code';
    like $rest->response, qr{Fatal error handling /foo/bar: woobly},
      '... and a human readable response';
}

sub basic_services : Test(no_plan) {
    my $test = shift;
    my $rest = $test->REST;

    throws_ok { $rest->url('no_such_resource/')->get } qr/501 Not Implemented/,
      '... as should calling it with a non-existent resource';

    my $expected = <<'    END_XML';
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="http://localhost:9000/rest/?stylesheet=REST"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest"
                       xmlns:xlink="http://www.w3.org/1999/xlink">
    <kinetic:description>Available resources</kinetic:description>
      <kinetic:resource id="one"     xlink:href="http://localhost:9000/rest/one/search"/>
      <kinetic:resource id="simple"  xlink:href="http://localhost:9000/rest/simple/search"/>
      <kinetic:resource id="two"     xlink:href="http://localhost:9000/rest/two/search"/>
    </kinetic:resources>
    END_XML
    is_xml $rest->get, $expected,
      'Calling it without a resource should return a list of resources';

    $expected = <<'    END_XML';
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="http://localhost:9000/rest/?stylesheet=REST"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                       xmlns:xlink="http://www.w3.org/1999/xlink">
      <kinetic:description>Available instances</kinetic:description>
      <kinetic:resource id="XXX" xlink:href="http://localhost:9000/rest/one/lookup/guid/XXX"/>
      <kinetic:resource id="XXX" xlink:href="http://localhost:9000/rest/one/lookup/guid/XXX"/>
      <kinetic:resource id="XXX" xlink:href="http://localhost:9000/rest/one/lookup/guid/XXX"/>
    </kinetic:resources>
    END_XML
    my $key     = One->my_class->key;
    my $one_xml = $rest->url("$key/search")->get;
    $one_xml =~ s/@{[GUID_RE]}/XXX/g;
    is_xml $one_xml, $expected,
      'Calling it with a resource/search should return a list of instances';

    $key = Two->my_class->key;
    my $two_xml = $rest->url("$key/search")->get;
    $two_xml =~ s/@{[GUID_RE]}/XXX/g;
    diag "Clean up xml for which we have no resources";
}

sub xslt : Test(no_plan) {
    my $test = shift;
    my $rest = $test->REST;

    is_well_formed_xml $rest->get( stylesheet => 'instance' ),
      'Requesting an instance stylesheet should return valid xml';

    is_well_formed_xml $rest->get( stylesheet => 'REST' ),
      'Requesting a REST stylesheet should return valid xml';
}

1;
