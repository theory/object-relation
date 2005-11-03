package TEST::Kinetic::Interface::REST;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use lib 't/lib';
use Test::More qw/no_plan/;
use Kinetic::Interface::REST;
use Test::Exception;
use Test::WWW::Mechanize;
use Test::XML;
use Kinetic::Util::Constants qw/:rest UUID_RE :xslt :labels/;
use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(1) }
use TEST::REST::Server;

use WWW::REST;
use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';

my $PID;

    my $test   = bless {}, 'TEST';
    my $port   = '9000';
    my $domain = "http://localhost:$port/";
    my $path   = 'rest/';

{
	package TEST;
    sub domain { $domain }
    sub port   { $port }
    sub path   { $path }
    sub REST   { shift->{REST} }
}
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


    my $mech = Test::WWW::Mechanize->new;
    my $url  = $test->domain . $test->path;

    #my ( $foo, $bar, $baz ) = $test->test_objects;
    sub TEST::query_string {''}

    $mech->get_ok(
"${url}?@{[CLASS_KEY_PARAM]}=one;search=;_order_by=name;_limit=2;_sort_order=",
        'We should be able to search by query string'
    );

    my $response           = $mech->content;

    is_well_formed_xml $response, '... and should return well-formed XML';

    $test->query_string("@{[TYPE_PARAM]}=html");
    $mech->get_ok(
"${url}?@{[CLASS_KEY_PARAM]}=one;search=;_order_by=name;_limit=2;_sort_order=;@{[TYPE_PARAM]}=html",
        'We should be able to fetch and limit the searches'
    );

    is_well_formed_xml $mech->content,
      '... ordering and limiting searches should return well-formed xml';

    $mech->get_ok(
"${url}?@{[CLASS_KEY_PARAM]}=one;search=;_order_by=name;_limit=2;_sort_order=;_offset=2;@{[TYPE_PARAM]}=html",
        '... as should paging through result sets'
    );

    is_well_formed_xml $mech->content, 
      '... ordering and limiting searches should return well-formed xml';
    my $rest = $test->REST;

    is_well_formed_xml $rest->get( stylesheet => 'instance' ),
      'Requesting an "instance" stylesheet should return valid xml';

    is_well_formed_xml $rest->get( stylesheet => 'search' ),
      'Requesting a "search" stylesheet should return valid xml';

    is_well_formed_xml $rest->get( stylesheet => 'resources' ),
      'Requesting a "resources" stylesheet should return valid xml';

    kill 9, $PID if $PID;
    sleep 2;
1;
