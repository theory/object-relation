#!/usr/bin/perl

use strict;
use warnings;

use Kinetic::Build::Test;
use Test::More qw/no_plan/;
use Test::Exception;
use aliased 'Test::MockModule';

use CGI;
use Apache::FakeRequest;

# need to implement methods from:
# http://search.cpan.org/~pgollucci/mod_perl-2.0.2/docs/api/Apache2/RequestRec.pod
# http://search.cpan.org/~stas/libapreq-1.33/Request/Request.pm 

my $REQUEST;

use Readonly;
Readonly my %default_values => (
    sports => [qw/football baseball/],
    name   => ['Ovid'],
);

{

    # this if for the mocked Apache::Request object
    my %value_for = %default_values;

    sub param {
        my $self = shift;
        return sort keys %value_for unless @_;
        if ( 1 == @_ ) {
            my $param = shift;
            return unless exists $value_for{$param};
            my $value = $value_for{$param};
            return wantarray ? @$value : $value->[0];
        }
        my ( $param, $value ) = @_;
        unless ( 'ARRAY' eq ref $value ) {
            require Carp;
            Carp::croak "Value for '$param' must be an array ref";
        }
        $value_for{$param} = $value;
    }
}

BEGIN {
    chdir 't' if -d 't';
    use lib '../lib';
    $REQUEST = 'Kinetic::Engine::Request';
    use_ok $REQUEST or die;
}
use Kinetic::Engine;

my $mock_engine = MockModule->new('Kinetic::Engine');
$mock_engine->mock( type => 'Unknown::Type' );

can_ok $REQUEST, 'new';
throws_ok { $REQUEST->new } 'Kinetic::Util::Exception::Fatal',
  '... and trying to fetch a request for an unknown engine type should fail';

# test Apache::Request2

$mock_engine->mock( type => 'Apache2::Request' );
sub set_handler {
    my $req = shift;

    # Mock up the apr param() method so the request object can delegate to it.
    my $apr = Apache::FakeRequest->new;
    $req->engine->handler($apr);
    my $mock_handler = MockModule->new("Apache::FakeRequest");
    $mock_handler->mock( param => \&param );
    return $mock_handler;
}

my $req = test_shared_behavior( 'Kinetic::Engine::Request::Apache2',
    \&set_handler );
my $req2 = $REQUEST->new;
is $req, $req2, '... calling new again should return the same request';
$req->_clear_singleton;

# test CGI

my $cgi = new CGI( {%default_values} );    # must copy as it's Readonly
$mock_engine->mock( type => 'CGI' );

$req = test_shared_behavior(
    'Kinetic::Engine::Request::CGI', 
    sub {
        my $req = shift;
        $req->engine->handler(CGI->new({%default_values}));
    }
);
$req->_clear_singleton;

sub test_shared_behavior {
    my ( $factory_class, $mock_handler ) = @_;
    ok my $req = $REQUEST->new,
      'Fetching a request for a known engine type should succeed';
    isa_ok $req, $REQUEST, '... and the object it returns';
    ok $req->isa($factory_class),
      '... and it should be the proper factory class';

    my $mock = $mock_handler->($req);

    can_ok $req, 'param';
    ok !defined $req->param('foo'),
      '... and non-existent params should return undefined';
    my @vals = $req->param('foo');
    ok !@vals, '... even in list context';

    my $sport = $req->param('sports');
    is $sport, 'football',
      'Calling a param in scalar context should return the first value';
    my @sports = $req->param('sports');
    is_deeply \@sports, [qw/football baseball/],
      '... and in list context it should return all values';
    is_deeply [ $req->param('name') ], ['Ovid'],
      '... or just a single value if that is all there is';
    $req->param( sports => [qw/hockey limbo/] );
    is_deeply [ $req->param('sports') ], [qw/hockey limbo/],
      'We should be able to set new param values';

    return $req;
}
