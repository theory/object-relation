package TEST::Kinetic::Interface::REST::Dispatch;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Test::XML;

use Kinetic::Util::Constants qw/GUID_RE/;
use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(1) }

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';
use aliased 'Kinetic::Interface::REST';
use aliased 'Kinetic::Interface::REST::Dispatch';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';    # contains a TestApp::Simple::One object

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
    $baz->name('snorfleglitz');
    $store->save($baz);
    $test->{test_objects} = [ $foo, $bar, $baz ];
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
        domain => 'http://somehost.com/',
        path   => 'rest/'
    );
    $test->_path_info('');
    $test->{query_string} = undef;
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

sub message_arg_handling : Test(8) {
    my $dispatch = Dispatch->new;
    can_ok $dispatch, 'args';
    is_deeply $dispatch->args, [ STRING => '', limit => 20, offset => 0 ],
      '... and calling it with no args set should return an empty search';

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

    # we don't use can_ok because of the way &can is overridden
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
      $dispatch->class_key('two')->args( [] )->_pageset( $pageset_args->() );
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

    # we don't use can_ok because of the way &can is overridden
    my $dispatch = Dispatch->new;
    can_ok $dispatch, 'class_list';
    my $rest = $test->{rest};
    $dispatch->rest($rest);
    $dispatch->class_list;
    my $expected = <<'    END_XML';
<?xml version="1.0"?>
    <?xml-stylesheet type="text/xsl" href="http://somehost.com/rest/?stylesheet=REST"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                       xmlns:xlink="http://www.w3.org/1999/xlink">
    <kinetic:description>Available resources</kinetic:description>
          <kinetic:resource id="one" xlink:href="http://somehost.com/rest/one/search"/>
          <kinetic:resource id="simple" xlink:href="http://somehost.com/rest/simple/search"/>
          <kinetic:resource id="two" xlink:href="http://somehost.com/rest/two/search"/>
    </kinetic:resources>
    END_XML
    is_xml $rest->response, $expected,
      '... and calling it should return a list of resources';
}

sub handle : Test(6) {
    my $test     = shift;
    my $dispatch = Dispatch->new;
    can_ok $dispatch, 'handle_rest_request';
    my $rest = $test->{rest};
    my $key  = One->my_class->key;
    $dispatch->rest($rest)->class_key($key);

    # The error message used path info
    $test->_path_info("/$key/");
    $dispatch->handle_rest_request;
    is $rest->response, "No resource available to handle (/$key/)",
      'Calling _handle_rest_request() no message should fail';

    $dispatch->message('search');
    $dispatch->handle_rest_request;
    ( my $response = $rest->response ) =~ s/@{[GUID_RE]}/XXX/g;
    my $expected = <<'    END_XML';
<?xml version="1.0"?>
    <?xml-stylesheet type="text/xsl" href="http://somehost.com/rest/?stylesheet=REST"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                    xmlns:xlink="http://www.w3.org/1999/xlink">
    <kinetic:description>Available instances</kinetic:description>
        <kinetic:resource 
            id="XXX" 
            xlink:href="http://somehost.com/rest/one/lookup/guid/XXX"/>
        <kinetic:resource 
            id="XXX" 
            xlink:href="http://somehost.com/rest/one/lookup/guid/XXX"/>
        <kinetic:resource 
            id="XXX" 
            xlink:href="http://somehost.com/rest/one/lookup/guid/XXX"/>
    </kinetic:resources>
    END_XML
    is_xml $response, $expected,
      '... but calling it with /$key/search should succeed';

    my ( $foo, $bar, $baz ) = @{ $test->{test_objects} };
    my $foo_guid = $foo->guid;
    $dispatch->message('lookup');
    $dispatch->args( [ 'guid', $foo_guid ] );
    $dispatch->handle_rest_request;
    $expected = <<"    END_XML";
    <?xml-stylesheet type="text/xsl" href="http://somehost.com/rest/?stylesheet=instance"?>
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description"></attr>
        <attr name="guid">$foo_guid</attr>
        <attr name="name">foo</attr>
        <attr name="state">1</attr>
      </instance>
    </kinetic>
    END_XML
    is_xml $rest->response, $expected,
      '... and $class_key/lookup/guid/$guid should return instance XML';

    $dispatch->message('search');
    $dispatch->args( [ 'STRING', 'name => "foo"' ] );
    $dispatch->handle_rest_request;

    $expected = <<"    END_XML";
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="http://somehost.com/rest/?stylesheet=REST"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                       xmlns:xlink="http://www.w3.org/1999/xlink">
      <kinetic:description>Available instances</kinetic:description>
      <kinetic:resource id="$foo_guid" xlink:href="http://somehost.com/rest/one/lookup/guid/$foo_guid"/>
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

    my $bar_guid = $bar->guid;
    $dispatch->handle_rest_request;
    $expected = <<"    END_XML";
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="http://somehost.com/rest/?stylesheet=REST"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                     xmlns:xlink="http://www.w3.org/1999/xlink">
      <kinetic:description>Available instances</kinetic:description>
      <kinetic:resource id="$bar_guid" xlink:href="http://somehost.com/rest/one/lookup/guid/$bar_guid"/>
      <kinetic:resource id="$foo_guid" xlink:href="http://somehost.com/rest/one/lookup/guid/$foo_guid"/>
    </kinetic:resources>
    END_XML
    is_xml $rest->response, $expected,
      '... and complex searches with constraints should also succeed';
}

sub normalize_args : Test(7) {
    my $test = shift;
    ok my $normalize =
      *Kinetic::Interface::REST::Dispatch::_normalize_args{CODE},
      '&_normalize_args is defined in the Dispatch package';

    our $method_name = 'lookup';
    {

        package Faux::Method;
        local $^W;
        sub name { return $method_name }
    }
    my $method = bless {}, 'Faux::Method';
    ok my $args = $normalize->( $method, [] ),
      '... and calling it should succeed';
    is ref $args, 'ARRAY', '... returning an array reference';
    is_deeply $args, [], '... which should be empty if we pass no args';

    $args = $normalize->( $method, [qw/foo null/] );
    is_deeply $args, [ 'foo', '' ],
      '"null" should be converted to the empty string';

    $method_name = 'search';
    $args = $normalize->( $method, [] );
    is_deeply $args, [ 'STRING', '', 'limit', 20 ],
      'search methods should default to a limit of 20 objects';

    $args = $normalize->( $method, [qw/STRING null limit 10/] );
    is_deeply $args, [ 'STRING', '', 'limit', 10 ],
      '... unless we explicitly override it';
}

1;
