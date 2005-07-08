package TEST::Kinetic::Interface::REST;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
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
        $REST_SERVER = Kinetic::Interface::REST->new;
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
sub start_server : Test(startup) {
    my $test = shift;
    my $server = Test::Server->new(PORT);
    select undef, undef, undef, 0.2;
    $PID       = $server->background;
    select undef, undef, undef, 0.2;
    my $domain = sprintf "%s:%s" => DOMAIN, PORT;
    $test->{REST} = WWW::REST->new("http://$domain");
    my $dispatch = sub {
        my $REST = shift;
        die $REST->status_line if $REST->is_error;
        return $REST->content;
    };
    $test->{REST}->dispatch($dispatch);
}

sub stop_server : Test(shutdown) {
    kill 9, $PID or warn "Could not kill 9 ($PID)";
}

sub setup : Test(setup) {
    my $test = shift;
    my $store = Store->new;
    $test->{dbh} = $store->_dbh;
    $test->{dbh}->begin_work;
    $test->{dbi_mock} = MockModule->new('DBI::db', no_auto => 1);
    $test->{dbi_mock}->mock(begin_work => 1);
    $test->{dbi_mock}->mock(commit => 1);
    $test->{db_mock} = MockModule->new('Kinetic::Store::DB');
    $test->{db_mock}->mock(_dbh => $test->{dbh});
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
    my $test = shift;
    delete($test->{dbi_mock})->unmock_all;
    $test->{dbh}->rollback unless $test->{dbh}->{AutoCommit};
    delete($test->{db_mock})->unmock_all;
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

sub basic_services : Test(8) {
    my $test = shift;
    my $rest = $test->REST;

    can_ok $rest, 'get';
    throws_ok {$rest->get}
        qr/501 Not Implemented/,
        '... and calling it without a path info should fail';

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

    my $key = One->my_class->key;
    TODO: {
        local $TODO = 'Still working out XML response';
        is $rest->url($key)->get, One,
            'This is a stub test for a clean check in';
    }
}

1;
