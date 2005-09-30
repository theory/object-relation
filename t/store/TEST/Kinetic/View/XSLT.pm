package TEST::Kinetic::View::XSLT;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Test::XML;

use Kinetic::XML;
use TEST::Kinetic::Traits::Store qw/:all/;
use TEST::Kinetic::Traits::HTML qw/:all/;
use TEST::Kinetic::Traits::XML qw/:all/;
use Kinetic::Util::Constants qw/UUID_RE CURRENT_PAGE :labels/;
use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(0) }

use aliased 'Kinetic::View::XSLT';
use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';

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
    $test->desired_attributes( [qw/ state name description bool /] );
    $test->domain('http://www.example.com/');
    $test->path('rest/');
    $test->query_string('');
}

sub teardown : Test(teardown) {
    my $test = shift;
    delete( $test->{dbi_mock} )->unmock_all;
    $test->{dbh}->rollback unless $test->{dbh}->{AutoCommit};
    delete( $test->{db_mock} )->unmock_all;
}

sub build_search_form : Test(no_plan) {
    my $test = shift;
    my $xslt = XSLT->new( type => 'search' );

    $test->domain('http://www.example.com/');
    $test->path('rest');

    my $search = 'name =&gt; &quot;foo&quot;, OR(name =&gt; &quot;bar&quot;)';

    my $header     = $test->header_xml(AVAILABLE_INSTANCES);
    my $resources  = $test->resource_list_xml;
    my $instances  = $test->expected_instance_xml( scalar $test->test_objects );
    my $search_xml = $test->search_data_xml({key => 'one', search => $search, order_by => 'name'});

    my $xml = <<"    END_XML";
$header
      $resources
      $instances
      $search_xml
    </kinetic:resources>
    END_XML
    ok my $xhtml = $xslt->transform($xml),
      'Calling transform() with valid XML should succeed';

    my $html_header    = $test->header_html(AVAILABLE_INSTANCES);
    my $html_resources = $test->resource_list_html('');;
    my $search_form    = $test->search_form( 'one', $search, 20, 'name' );
    my $instance_table = $test->instance_table( $test->test_objects );

    my $expected = <<"    END_XHTML";
$html_header
    $html_resources
    $search_form
    $instance_table
  </body>
</html>
    END_XHTML
    is_xml $xhtml, $expected, '... and return the correct xhtml';
}

sub constructor : Test(6) {
    my $test = shift;
    can_ok XSLT, 'new';
    throws_ok { XSLT->new }
      'Kinetic::Util::Exception::Fatal::RequiredArguments',
      'Calling new() without a type argument should throw an exception';

    throws_ok { XSLT->new( type => 'no_such_type' ) }
      'Kinetic::Util::Exception::Fatal::Unsupported',
      'Calling new() with an unknown type should throw an exception';

    ok my $xslt = XSLT->new( type => 'instance' ),
      '... and calling it with a known type should succeed';
    isa_ok $xslt, XSLT, '... and the object it returns';
    is $xslt->type, 'instance', '... and it should have the correct XSLT type';
}

sub type : Test(5) {
    my $test = shift;
    my $xslt = XSLT->new( type => 'instance' );
    can_ok $xslt, 'type';

    throws_ok { $xslt->type('no_such_type') }
      'Kinetic::Util::Exception::Fatal::Unsupported',
      '... and calling it with an unknown type should throw an exception';
    is $xslt->type, 'instance',
      '... and it should return the type set in the constructor';
    ok $xslt->type('search'),
      'Calling type() with a valid XSLT type should succeed';
    is $xslt->type, 'search', '... setting the type to the requested value';
}

sub stylesheet : Test(3) {
    my $test = shift;
    my $xslt = XSLT->new( type => 'search' );
    can_ok $xslt, 'stylesheet';

    my $xml = $xslt->stylesheet;
    is_well_formed_xml $xml, '... and it should return valid XML for "search"';

    $xslt->type('instance');
    $xml = $xslt->stylesheet;
    is_well_formed_xml $xml,
      '... and it should return valid XML for "instance"';
}

sub transform : Test(9) {
    my $test = shift;
    my $xslt = XSLT->new( type => 'search' );
    can_ok $xslt, 'transform';

    throws_ok { $xslt->transform }
      'Kinetic::Util::Exception::Fatal::RequiredArguments',
      'Calling transform() without xml should throw an exception';

    throws_ok { $xslt->transform("This ain't xml") }
      'Kinetic::Util::Exception::ExternalLib',
      '... as should calling it with an argument that is not valid XML';

    $test->domain('http://www.example.com/')->path('rest');
    my $header    = $test->header_xml(AVAILABLE_INSTANCES);
    my $resources = $test->resource_list_xml;
    my $expected_instances =
      $test->expected_instance_xml( scalar $test->test_objects );

    my $search     = 'name =&gt; &quot;foo&quot;, OR(name =&gt; &quot;bar&quot;)';
    my $search_xml = $test->search_data_xml({key => 'one', search => $search, order_by => 'name'});

    my $xml = <<"    END_XML";
$header
      $resources
      $expected_instances
      $search_xml
    </kinetic:resources>
    END_XML
    ok my $xhtml = $xslt->transform($xml),
      'Calling transform() with valid XML should succeed';

    my $html_header    = $test->header_html(AVAILABLE_INSTANCES);
    my $html_resources = $test->resource_list_html;
    my $search_form    = $test->search_form( 'one', $search, 20, 'name' );
    my $instance_table = $test->instance_table( $test->test_objects );

    my $expected       = <<"    END_XHTML";
$html_header
  $html_resources
  $search_form
  $instance_table
  </body>
</html>
    END_XHTML
    is_xml $xhtml, $expected, '... and return the correct xhtml';

    $header = $test->header_xml(AVAILABLE_RESOURCES);
    $xml = <<"    END_XML";
$header
      <kinetic:resource id="one" xlink:href="http://somehost.com/rest/one"/>
      <kinetic:resource id="simple" xlink:href="http://somehost.com/rest/simple"/>
      <kinetic:resource id="two" xlink:href="http://somehost.com/rest/two"/>
    </kinetic:resources>
    END_XML

    $xslt->type('resources');
    ok $xhtml = $xslt->transform($xml),
      'Calling transform() with valid XML should succeed';

    $html_header = $test->header_html(AVAILABLE_RESOURCES);
    is_xml $xhtml, <<"    END_XHTML", '... and return the correct xhtml';
$html_header
    <div class="listing">
      <table>
        <tr><th class="header">@{[AVAILABLE_RESOURCES]}</th></tr>
        <tr class="row_1"><td><a href="http://somehost.com/rest/one">one</a></td></tr>
        <tr class="row_0"><td><a href="http://somehost.com/rest/simple">simple</a></td></tr>
        <tr class="row_1"><td><a href="http://somehost.com/rest/two">two</a></td></tr>
      </table>
    </div>
  </body>
</html>
    END_XHTML

    my ( $foo, $bar, $baz ) = $test->test_objects;
    $xml = Kinetic::XML->new( { 
        object        => $foo,
        resources_url => $test->url,
    } )->dump_xml;

    $xslt->type('instance');
    ok $xhtml = $xslt->transform($xml),
      'Calling transform() with valid XML should succeed';

    $html_header  = $test->header_html('one');
    $resources = $test->resource_list_html;
    
    is_xml $xhtml, <<"    END_XHTML", '... and return the correct xhtml';
$html_header
    $resources
    <div class="listing">
      <table>
        <tr>
          <th class="header" colspan="2">one</th>
        </tr>
        <tr class="row_1">
          <td>bool</td>
          <td>1</td>
        </tr>
        <tr class="row_0">
          <td>description</td>
          <td></td>
        </tr>
        <tr class="row_1">
          <td>name</td>
          <td>foo</td>
        </tr>
        <tr class="row_0">
          <td>state</td>
          <td>1</td>
        </tr>
        <tr class="row_1">
          <td>uuid</td>
          <td>@{[$foo->uuid]}</td>
        </tr>
      </table>
    </div>
  </body>
</html>
    END_XHTML
}

sub transform_pages : Test(3) {
    my $test = shift;
    my $xslt = XSLT->new( type => 'search' );

    my $header = $test->header_xml(AVAILABLE_RESOURCES);
    my $xml = <<"    END_XML";
$header
      <kinetic:resource xlink:href="one/search" id="one"/>
      <kinetic:resource xlink:href="two/search" id="two"/>
      <kinetic:instance id="XXX" xlink:href="http://domain/rest/one/lookup/uuid/XXX">
        <kinetic:attribute name="name">foo</kinetic:attribute>
        <kinetic:attribute name="rank">General</kinetic:attribute>
      </kinetic:instance>
      <kinetic:instance id="XXX" xlink:href="http://domain/rest/one/lookup/uuid/XXX">
        <kinetic:attribute name="name">bar</kinetic:attribute>
        <kinetic:attribute name="rank">Private</kinetic:attribute>
      </kinetic:instance>
      <kinetic:pages>
        <kinetic:page id="[ Page 1 ]" xlink:href="http://domain/rest/one/search/STRING/NULL/order_by/name/limit/2/offset/0" />
        <kinetic:page id="[ Page 2 ]" xlink:href="http://domain/rest/one/search/STRING/NULL/order_by/name/limit/2/offset/2" />
      </kinetic:pages>
    </kinetic:resources>
    END_XML
    ok my $xhtml = $xslt->transform($xml),
      'Calling transform() with XML that has pages should succeed';

    my $html_header    = $test->header_html(AVAILABLE_RESOURCES);

    is_xml $xhtml, <<"    END_XHTML", '... and return xml with pages';
$html_header
        <div id="sidebar">
          <ul>
            <li><a href="one/search">one</a></li>
            <li><a href="two/search">two</a></li>
          </ul>
        </div>
        <div class="listing">
          <table>
            <tr>
              <th class="header">name</th>
              <th class="header">rank</th>
            </tr>
            <tr class="row_1">
              <td><a href="http://domain/rest/one/lookup/uuid/XXX">foo</a></td>
              <td><a href="http://domain/rest/one/lookup/uuid/XXX">General</a></td>
            </tr>
            <tr class="row_0">
              <td><a href="http://domain/rest/one/lookup/uuid/XXX">bar</a></td>
              <td><a href="http://domain/rest/one/lookup/uuid/XXX">Private</a></td>
            </tr>
          </table>
        </div>
        <div class="pages">
          <p>
            <a href="http://domain/rest/one/search/STRING/NULL/order_by/name/limit/2/offset/0">[ Page 1 ]</a>
            <a href="http://domain/rest/one/search/STRING/NULL/order_by/name/limit/2/offset/2">[ Page 2 ]</a>
          </p>
        </div>
      </body>
    </html>
    END_XHTML

    $xml = <<"    END_XML";
$header
      <kinetic:resource id="XXX" xlink:href="http://domain/rest/one/lookup/uuid/XXX"/>
      <kinetic:resource id="XXX" xlink:href="http://domain/rest/one/lookup/uuid/XXX"/>
      <kinetic:pages>
        <kinetic:page id="[ Page 1 ]" xlink:href="@{[CURRENT_PAGE]}" />
        <kinetic:page id="[ Page 2 ]" xlink:href="http://domain/rest/one/search/STRING/NULL/order_by/name/limit/2/offset/2" />
      </kinetic:pages>
    </kinetic:resources>
    END_XML
    ok $xhtml = $xslt->transform($xml),
      'Calling transform() with XML that has pages should succeed';
}

1;
