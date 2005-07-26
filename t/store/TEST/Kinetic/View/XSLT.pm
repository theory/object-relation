package TEST::Kinetic::View::XSLT;

# $Id: REST.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Test::XML;

use Kinetic::Util::Constants  qw/GUID_RE/;
use Kinetic::Util::Exceptions qw/sig_handlers/;
use Kinetic::XML;
BEGIN { sig_handlers(0) }

use aliased 'Kinetic::View::XSLT';
use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

__PACKAGE__->SKIP_CLASS(
    __PACKAGE__->any_supported(qw/pg sqlite/)
      ? 0
      : "Not testing Data Stores"
) if caller; # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

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
    $test->{param} = sub {
        my $self = shift;
        my @query_string = @{$test->_query_string || []};
        my %param = @query_string;
        if (@_) {
            return $param{+shift};
        }
        else {
            my $i = 0;
            return grep { ! ($i++ % 2) } @query_string;
        }
    };
}

sub teardown : Test(teardown) {
    my $test = shift;
    delete($test->{dbi_mock})->unmock_all;
    $test->{dbh}->rollback unless $test->{dbh}->{AutoCommit};
    delete($test->{db_mock})->unmock_all;
}

sub constructor : Test(6) {
    my $test = shift;
    can_ok XSLT, 'new';
    throws_ok {XSLT->new}
        'Kinetic::Util::Exception::Fatal::RequiredArguments',
        'Calling new() without a type argument should throw an exception';

    throws_ok {XSLT->new(type => 'no_such_type')}
        'Kinetic::Util::Exception::Fatal::Unsupported',
        'Calling new() with an unknown type should throw an exception';

    ok my $xslt = XSLT->new(type => 'instance'),
        '... and calling it with a known type should succeed';
    isa_ok $xslt, XSLT, '... and the object it returns';
    is $xslt->type, 'instance', '... and it should have the correct XSLT type';
}

sub type : Test(5) {
    my $test = shift;
    my $xslt = XSLT->new(type => 'instance');
    can_ok $xslt, 'type';

    throws_ok {$xslt->type('no_such_type')}
        'Kinetic::Util::Exception::Fatal::Unsupported',
        '... and calling it with an unknown type should throw an exception';
    is $xslt->type, 'instance', 
        '... and it should return the type set in the constructor';
    ok $xslt->type('REST'),
        'Calling type() with a valid XSLT type should succeed';
    is $xslt->type, 'REST','... setting the type to the requested value';
} 

sub stylesheet : Test(3) {
    my $test = shift;
    my $xslt = XSLT->new(type => 'REST');
    can_ok $xslt, 'stylesheet';

    my $xml = $xslt->stylesheet;
    is_well_formed_xml $xml, 
        '... and it should return valid XML for "REST"';
    
    $xslt->type('instance');
    $xml = $xslt->stylesheet;
    is_well_formed_xml $xml, 
        '... and it should return valid XML for "instance"';
}

sub transform : Test(9) {
    my $test = shift;
    my $xslt = XSLT->new(type => 'REST');
    can_ok $xslt, 'transform';

    throws_ok {$xslt->transform}
        'Kinetic::Util::Exception::Fatal::RequiredArguments',
        'Calling transform() without xml should throw an exception';

    throws_ok {$xslt->transform("This ain't xml")}
        'Kinetic::Util::Exception::ExternalLib',
        '... as should calling it with an argument that is not valid XML';

    my $xml = <<'    END_XML';
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="http://somehost.com/rest/?stylesheet=browse"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                       xmlns:xlink="http://www.w3.org/1999/xlink">
      <kinetic:description>Available instances</kinetic:description>
      <kinetic:resource id="XXX" xlink:href="http://somehost.com/rest/one/XXX"/>
      <kinetic:resource id="XXX" xlink:href="http://somehost.com/rest/one/XXX"/>
      <kinetic:resource id="XXX" xlink:href="http://somehost.com/rest/one/XXX"/>
    </kinetic:resources>
    END_XML
    ok my $xhtml = $xslt->transform($xml), 
        'Calling transform() with valid XML should succeed';

    is_xml $xhtml, <<'    END_XHTML', '... and return the correct xhtml';
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:kinetic="http://www.kineticode.com/rest" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <title>Available instances</title>
  </head>
  <body>
    <table bgcolor="#eeeeee" border="1">
      <tr><th>Available instances</th></tr>
      <tr><td><a href="http://somehost.com/rest/one/XXX">XXX</a></td></tr>
      <tr><td><a href="http://somehost.com/rest/one/XXX">XXX</a></td></tr>
      <tr><td><a href="http://somehost.com/rest/one/XXX">XXX</a></td></tr>
    </table>
  </body>
</html>
    END_XHTML
    
    $xml = <<'    END_XML';
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="http://somehost.com/rest/?stylesheet=browse"?>
    <kinetic:resources xmlns:kinetic="http://www.kineticode.com/rest" 
                       xmlns:xlink="http://www.w3.org/1999/xlink">   
      <kinetic:description>Available resources</kinetic:description>
      <kinetic:resource id="one" xlink:href="http://somehost.com/rest/one"/>
      <kinetic:resource id="simple" xlink:href="http://somehost.com/rest/simple"/>
      <kinetic:resource id="two" xlink:href="http://somehost.com/rest/two"/>
    </kinetic:resources>
    END_XML
    
    ok $xhtml = $xslt->transform($xml), 
        'Calling transform() with valid XML should succeed';

    is_xml $xhtml, <<'    END_XHTML', '... and return the correct xhtml';
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:kinetic="http://www.kineticode.com/rest" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <title>Available resources</title>
  </head>
  <body>
    <table bgcolor="#eeeeee" border="1">
      <tr><th>Available resources</th></tr>
      <tr><td><a href="http://somehost.com/rest/one">one</a></td></tr>
      <tr><td><a href="http://somehost.com/rest/simple">simple</a></td></tr>
      <tr><td><a href="http://somehost.com/rest/two">two</a></td></tr>
    </table>
  </body>
</html>
    END_XHTML
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    $xml = Kinetic::XML->new({object => $foo})->dump_xml;

    $xslt->type('instance');
    ok $xhtml = $xslt->transform($xml), 
        'Calling transform() with valid XML should succeed';

    is_xml $xhtml, <<"    END_XHTML", '... and return the correct xhtml';
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:kinetic="http://www.kineticode.com/rest" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <title>one</title>
  </head>
  <body>
    <table bgcolor="#eeeeee" border="1">
      <tr>
        <th colspan="2">one</th>
      </tr>
      <tr>
        <td>bool</td>
        <td>1</td>
      </tr>
      <tr>
        <td>description</td>
        <td></td>
      </tr>
      <tr>
        <td>guid</td>
        <td>@{[$foo->guid]}</td>
      </tr>
      <tr>
        <td>name</td>
        <td>foo</td>
      </tr>
      <tr>
        <td>state</td>
        <td>1</td>
      </tr>
    </table>
  </body>
</html>
    END_XHTML
}

1;
