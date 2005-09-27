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
use Kinetic::Util::Constants qw/UUID_RE :xslt :labels/;
use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(1) }

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';
use aliased 'Kinetic::Interface::REST';
use aliased 'Kinetic::Interface::REST::Dispatch';

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
    $test->test_objects([ $foo, $bar, $baz ]);
    $test->{param} = sub {
        my $self         = shift;
        my @query_string = @{ $test->_query_string || [] };
        my %param        = @query_string;
        if (@_) {
            return $param{ +shift };
        }
        else {
            my $i = 0;
            return grep { !( $i++ % 2 ) } @query_string;
        }
    };

    # set up mock cgi and path methods
    my $cgi_mock = MockModule->new('CGI');
    $cgi_mock->mock( path_info => sub { $test->_path_info } );
    $cgi_mock->mock( param => $test->{param} );
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
    $test->{query_string} = undef;
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

sub _query_string {
    my $test = shift;
    return $test->{query_string} unless @_;
    $test->{query_string} = [@_];
    return $test;
}

sub _path_info {
    my $test = shift;
    return $test->{path_info} unless @_;
    $test->{path_info} = shift;
    return $test;
}

sub instance_attributes {
    my $test = shift;
    return $test->{attributes} unless @_;
    $test->{attributes} = shift;
    return $test;
}

sub _url { $DOMAIN . $PATH }

sub method_arg_handling : Test(12) {

    # also test for lookup
    my $dispatch = Dispatch->new;
    can_ok $dispatch, 'args';
    $dispatch->method('lookup');
    is_deeply $dispatch->args, [],
      'Calling lookup args() with no args set should return an empty arg list';
    ok $dispatch->args( [qw/ foo bar /] ),
      '... and setting the arguments should succeed';
    is_deeply $dispatch->args, [qw/ foo bar /],
      '... and we should be able to reset the args';

    $dispatch->method('search');
    ok $dispatch->args( [] ), 'Setting search args should succceed';
    is_deeply $dispatch->args, [ STRING => '', limit => 20, offset => 0 ],
      '... and setting them with no args set should return a default search';
    ok $dispatch->args( [qw/ foo bar /] ),
      '... and setting the arguments should succeed';
    is_deeply $dispatch->args, [qw/ foo bar limit 20 offset 0 /],
      '... but it should return default limit and offset';

    $dispatch->args( [qw/ this that limit 30 offset 0 /] );
    is_deeply $dispatch->args, [qw/ this that limit 30 offset 0 /],
      '... but it should not override a limit that is already supplied';

    $dispatch->args( [qw/ limit 30 this that offset 0 /] );
    is_deeply $dispatch->args, [qw/ limit 30 this that offset 0 /],
      '... regardless of its position in the arg list';

    $dispatch->args( [qw/ this that limit 30 offset 20 /] );
    is_deeply $dispatch->args, [qw/ this that limit 30 offset 20 /],
      '... not should it override an offset already supplied';

    $dispatch->args( [qw/ this that offset 10 limit 30 /] );
    is_deeply $dispatch->args, [qw/ this that offset 10 limit 30 /],
      '... regardless of its position in the list';
}

sub page_set : Test(17) {
    my $test = shift;

    my $dispatch = Dispatch->new;

    for my $age ( 1 .. 100 ) {
        my $object = Two->new;
        $object->name("Name $age");
        $object->one->name("One Name $age");
        $object->age($age);
        $object->save;
    }
    my ( $num_items, $limit, $offset ) = ( 19, 20, 0 );

    # here we are deferring evaluation of the variables so we can
    # later just change their values and have the dispatch method
    # pick 'em up.
    my $pageset_args = sub {
        {
            count    => $num_items,    # number of items
              limit  => $limit,        # items per page
              offset => $offset,       # item we're starting with
        }
    };

    my $result =
      $dispatch->class_key('two')->method('search')->args( [] )
      ->_pageset( $pageset_args->() );
    ok !$result,
      '... and it should return false on first page if $count < $limit';

    $num_items = $limit;
    ok $result = $dispatch->_pageset( $pageset_args->() ),
      'On the first page, &_pageset should return true if $count == $limit';

    isa_ok $result, 'Data::Pageset',
      '... and the result should be a pageset object';

    is $result->current_page,  1, '... telling us we are on the first page';
    is $result->last_page,     5, '... and how many pages there are';
    is $result->pages_per_set, 1, '... and how many pages are in each set';
    is $result->total_entries, 100,
      '... and we should have the correct number of entries';

    $num_items = $limit - 1;
    $offset    = $limit + 1;    # force it to page 2
    ok $result = $dispatch->_pageset( $pageset_args->() ),
      'We should get a pageset if we are not on the first page';

    is $result->current_page,  2, '... telling us we are on the second page';
    is $result->last_page,     5, '... and how many pages there are';
    is $result->pages_per_set, 1, '... and how many pages are in each set';
    is $result->total_entries, 100,
      '... and we should have the correct number of entries';

    $dispatch->args( [ 'STRING', 'age => GT 43' ] );
    ok $result = $dispatch->_pageset( $pageset_args->() ),
      'Pagesets should accept search criteria';

    is $result->current_page,  2, '... telling us we are on the second page';
    is $result->last_page,     3, '... and how many pages there are';
    is $result->pages_per_set, 1, '... and how many pages are in each set';
    is $result->total_entries, 57,
      '... and we should have the correct number of entries';
}

sub class_list : Test(2) {
    my $test = shift;
    my $url  = _url();

    my $dispatch = Dispatch->new;
    can_ok $dispatch, 'class_list';
    my $rest = $test->{rest};
    $rest->xslt('resources');
    $dispatch->rest($rest);
    $dispatch->class_list;
    my $header = $test->header_xml(AVAILABLE_RESOURCES);
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
    my $dispatch = Dispatch->new;
    my $url      = _url();

    can_ok $dispatch, 'handle_rest_request';
    my $rest = $test->{rest};
    my $key  = One->my_class->key;
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
    my @instance_order     = $test->instance_order($response);
    my $expected_instances =
      $test->expected_instance_xml( scalar $test->test_objects, \@instance_order );
    my $header = $test->header_xml(AVAILABLE_INSTANCES);

    my $expected = <<"    END_XML";
$header
        $expected_instances
        <kinetic:class_key>one</kinetic:class_key>
        <kinetic:search_parameters>
            <kinetic:parameter type="search"/>
            <kinetic:parameter type="limit">20</kinetic:parameter>
            <kinetic:parameter type="order_by"/>
        </kinetic:search_parameters>
    </kinetic:resources>
    END_XML
    is_xml( $response, $expected, '... and it should return the correct XML' );

    my $foo_uuid = $foo->uuid;
    $dispatch->method('lookup');
    $dispatch->args( [ 'uuid', $foo_uuid ] );
    $dispatch->handle_rest_request;
    $expected = <<"    END_XML";
<?xml version="1.0"?>
    <?xml-stylesheet type="text/xsl" href="@{[INSTANCE_XSLT]}"?>
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description"></attr>
        <attr name="name">foo</attr>
        <attr name="state">1</attr>
        <attr name="uuid">$foo_uuid</attr>
      </instance>
    </kinetic>
    END_XML
    is_xml $rest->response, $expected,
      '... and $class_key/lookup/uuid/$uuid should return instance XML';

    $dispatch->method('search');
    $dispatch->args( [ 'STRING', 'name => "foo"' ] );
    $dispatch->handle_rest_request;

    my $instance =
      $test->expected_instance_xml( [$foo] );

    $expected = <<"    END_XML";
$header
      $instance
      <kinetic:class_key>one</kinetic:class_key>
      <kinetic:search_parameters>
        <kinetic:parameter type="search">name =&gt; &quot;foo&quot;</kinetic:parameter>   
        <kinetic:parameter type="limit">20</kinetic:parameter>
        <kinetic:parameter type="order_by"></kinetic:parameter>
      </kinetic:search_parameters>
    </kinetic:resources>
    END_XML

    is_xml $rest->response, $expected,
      '$class_key/search/STRING/$search_string should return a list';

    $dispatch->args(
        [
            STRING   => 'name => "foo", OR(name => "bar")',
            order_by => 'name',
        ]
    );

    $expected_instances = $test->expected_instance_xml( [ $bar, $foo ] );
    my $bar_uuid = $bar->uuid;
    $dispatch->handle_rest_request;
    $expected = <<"    END_XML";
$header
      $expected_instances
      <kinetic:class_key>one</kinetic:class_key>
      <kinetic:search_parameters>
        <kinetic:parameter type="search">name =&gt; &quot;foo&quot;, OR(name =&gt; &quot;bar&quot;)</kinetic:parameter>
        <kinetic:parameter type="limit">20</kinetic:parameter>
        <kinetic:parameter type="order_by">name</kinetic:parameter>
      </kinetic:search_parameters>
    </kinetic:resources>
    END_XML
    is_xml $rest->response, $expected,
      '... and complex searches with constraints should also succeed';
}

1;
