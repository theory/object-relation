package TEST::Kinetic::Interface::REST;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Test::XML;
use Test::HTTP::Server::Simple;
use Encode qw(is_utf8);
{
    local $^W;
    # XXX a temporary hack until we get a new
    # WWW::REST version checked in which doesn't warn
    # about a redefined constructor
    require WWW::REST;
}

use Kinetic::Util::Exceptions qw/sig_handlers/;

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';

use aliased 'Kinetic::DateTime';
use aliased 'Kinetic::DateTime::Incomplete';
use aliased 'Kinetic::Util::Iterator';
use aliased 'Kinetic::Util::State';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

use constant DOMAIN => 'localhost';
use constant PORT   => '9000';

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
      ? 0
      : "Not testing Data Stores"
) if caller; # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

{
    package Test::Server;
    use base qw(HTTP::Server::Simple::CGI);
    use Kinetic::Interface::REST;

    my $REST_SERVER;
    sub new {
        my ($class, @args) = @_;
        $REST_SERVER = Kinetic::Interface::REST->new(
            domain => 'http://www.example.com/',
            path   => 'rest/'
        );
        $class->SUPER::new(@args);
    }

    sub handle_request {
        my ($self, $cgi) = @_;
        my $NEWLINE = "\r\n";
        $REST_SERVER->handle_request($cgi);
        my $status   = $REST_SERVER->status;
        my $type     = $REST_SERVER->content_type;
        my $response = $REST_SERVER->response;
        print "HTTP/1.0 $status$NEWLINE";
        print "Content-Type: $type${NEWLINE}Content-Length: ";
        print length($response),
              $NEWLINE,
              $NEWLINE,
              $response;
    }

    # supress "can connect" printing from HTTP:Server::Simple (grr ...)
    sub print_banner {}
}

my $PID;
sub start_server : Test(startup => 1) {
    my $test = shift;
    my $server = Test::Server->new(PORT);
    started_ok($server, 'Test REST server started');
    my $domain = sprintf "%s:%s" => DOMAIN, PORT;
    $test->{REST} = WWW::REST->new("http://$domain");
    my $dispatch = sub {
        my $REST = shift;
        die $REST->status_line if $REST->is_error;
        return $REST->content;
    };
    $test->{REST}->dispatch($dispatch);
}

sub setup : Test(setup) {
    # XXX Note that we aren't mocking this up.  Because the REST server
    # is in a different process, mocking up the database methods to
    # prevent accidental commits means the other process will never see
    # these records.  Instead, what we do is the somewhat dubious practice
    # of iterating through the object types and deleting all of them
    # when these tests end.
    my $test = shift;
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
    $test->{test_objects} = [$foo, $bar, $baz];
}

sub teardown : Test(teardown) {
    shift->clear_database;
}

sub clear_database {
    my $test = shift;
    foreach my $key (Kinetic::Meta->keys) {
        next if Kinetic::Meta->for_key($key)->abstract;
        eval { $test->{dbh}->do("DELETE FROM $key") };
        # XXX 'thingy' and 'partof' are not getting cleared out :(
        #diag "Could not delete records from $key: $@" if $@;
    }
}

sub REST { shift->{REST} }

sub _all_items {
    my ($test, $iterator) = @_;
    my @iterator;
    while (my $object = $iterator->next) {
        push @iterator => $test->_force_inflation($object);
    }
    return @iterator;
}

my $should_run;
sub _should_run {
    return $should_run if defined $should_run;
    my $test    = shift;
    my $store   = Store->new;
    my $package = ref $store;
    $should_run = ref $test eq "TEST::$package";
    return $should_run;
}

BEGIN {
    sig_handlers(0);
}

sub rest_interface : Test(37) {
    my $class = 'Kinetic::Interface::REST';
    can_ok $class, 'new';
    throws_ok {$class->new}
        'Kinetic::Util::Exception::Fatal::RequiredArguments',
        '... and it should fail if domain and path are not present';

    throws_ok {$class->new(domain => 'http://foo/')}
        'Kinetic::Util::Exception::Fatal::RequiredArguments',
        '... or if just domain is present';

    throws_ok {$class->new(path => 'rest/')}
        'Kinetic::Util::Exception::Fatal::RequiredArguments',
        '... or if just path is present';

    ok my $rest = $class->new(domain => 'http://foo/', path => 'rest/server/'),
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

    can_ok $rest, '_path';
    is_deeply $rest->_path, [qw/rest server/],
        '... and it should return the path components as an array ref';
    $rest->_path('xxx');
    is_deeply $rest->_path, [qw/rest server/],
        '... but we should not be able to change it';
    
    foreach my $method (qw/cgi status response content_type/) {
        can_ok $rest, $method;
        ok ! $rest->$method, '... and it should be false with a new REST object';
        $rest->$method('xxx');
        is $rest->$method, 'xxx', '... but we should be able to set it to a new value';
    }
    
    # set up necessary mocked packages for handle_request() tests
    my $dispatch_mock = MockModule->new('Kinetic::Interface::REST::Dispatch');
    my $can_sub = undef;
    $dispatch_mock->mock(can => sub { $can_sub });
    my $cgi_mock = MockModule->new('CGI');
    $cgi_mock->mock(path_info => '/foo/bar');
    
    can_ok $rest, 'handle_request';
    ok $rest->handle_request(CGI->new), 
        '... and handling a bad resource should succeed';
    is $rest->status, '501 Not Implemented',
        '... with an appropriate status code';
    is $rest->response, 'No resource available to handle (foo)',
        '... and a human readable response';

    $can_sub = sub { die "woobly" };
    ok $rest->handle_request(CGI->new), 
        'Handling a fatal resource should succeed';
    is $rest->status, '500 Internal Server Error',
        '... with an appropriate status code';
    like $rest->response, qr{Fatal error handling /foo/bar: woobly},
        '... and a human readable response';

    $can_sub = sub { $rest->response('this and that') };
    ok $rest->handle_request(CGI->new),
        'Handling a good resource should succeed';
    is $rest->status, '200 OK',
        '... with an appropriate status code';
    is $rest->response, 'this and that',
        '... and a human readable response';
}

sub basic_services : Test(7) {
    my $test = shift;
    my $rest = $test->REST;

    throws_ok {$rest->url('no_such_resource/')->get}
        qr/501 Not Implemented/,
        '... as should calling it with a non-existent resource';

    is $rest->url('echo/foo/bar/')->get, 'foo.bar', 
        'Calling get() with an echo/ url should return the path info joined by dots';
    is $rest->url('echo/foo/bar/')->get(this => 'that'), 'foo.bar.this.that', 
        '... and it should return the path and query string info joined by dots';

    can_ok $rest, 'post';
    is $rest->url('echo/foo/bar/')->post(this => 'that'), 'foo.bar.this.that', 
        '... and it should return the path and post info joined by dots';

    my $expected = <<'    END_XML';
<?xml version="1.0"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest"
                       xmlns:xlink="http://www.w3.org/1999/xlink">
    <kinetic:description>Available resourcees</kinetic:description>
      <kinetic:resource id="one"     xlink:href="http://www.example.com/rest/one"/>
      <kinetic:resource id="simple"  xlink:href="http://www.example.com/rest/simple"/>
      <kinetic:resource id="two"     xlink:href="http://www.example.com/rest/two"/>
    </kinetic:resources>
    END_XML
    is_xml $rest->get, $expected, 
        'Calling it without a resource should return a list of resources';

    $expected = <<'    END_XML';
<?xml version="1.0"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                       xmlns:xlink="http://www.w3.org/1999/xlink">
      <kinetic:description>Available objects</kinetic:description>
      <kinetic:resource id="XXX" xlink:href="http://www.example.com/rest//one/XXX"/>
      <kinetic:resource id="XXX" xlink:href="http://www.example.com/rest//one/XXX"/>
      <kinetic:resource id="XXX" xlink:href="http://www.example.com/rest//one/XXX"/>
    </kinetic:resources>
    END_XML
    '0AB872E6-F2FC-11D9-9481-D6394B585510';
    my $hex  = qr/[A-F0-9]/;
    my $guid = qr/${hex}{8}-${hex}{4}-${hex}{4}-${hex}{4}-${hex}{12}/;
    my $one_xml = $rest->url('one')->get;
    $one_xml =~ s/$guid/XXX/g;
    is_xml $one_xml, $expected, 
        '... and calling it with a resource should return all instances of that resource';
}

1;
