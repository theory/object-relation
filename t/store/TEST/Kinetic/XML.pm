package TEST::Kinetic::XML;

# $Id: XML.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Test::XML;

use Encode qw(is_utf8);

use aliased 'Kinetic::DateTime';
use aliased 'Kinetic::Store';
use aliased 'Test::MockModule';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

use aliased 'Kinetic::XML';

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
}

sub teardown : Test(teardown) {
    my $test = shift;
    delete($test->{dbi_mock})->unmock_all;
    $test->{dbh}->rollback;
    delete($test->{db_mock})->unmock_all;
}

sub shutdown : Test(shutdown) {
    my $test = shift;
    $test->{dbh}->disconnect;
}

sub update_from_xml : Test(3) {
    my $test = shift;
    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    can_ok XML, 'update_from_xml';
    my $updated_object = One->new;
    $updated_object->{guid} = $foo->{guid};
    $updated_object->name($foo->name);
    $updated_object->state($foo->state);
    $updated_object->bool($foo->bool);
    $updated_object->description('This is not the same description');
    my $xml = XML->new($updated_object); # note that one does not have an id
    my $xml_string = $xml->dump_xml;
    my $object = $test->_force_inflation(XML->update_from_xml($xml_string));
    ok exists $object->{id}, '... and an existing guid should provide its ID for the update';

    $updated_object->{guid} = 'No such guid';
    $xml = XML->new($updated_object); 
    $xml_string = $xml->dump_xml;
    throws_ok {XML->update_from_xml($xml_string)}
        qr/Could not find guid 'No such guid' in the store/,
        '... but a non-existing guid should throw an exception';
}

sub new_from_xml : Test(5) {
    my $test = shift;
    can_ok XML, 'new_from_xml';
    throws_ok { XML->new_from_xml }
        qr/You must supply valid XML to new_from_xml\(\)/,
        '... and calling it without an argument should fail';

    my $no_version = <<'    END_XML';
    <kinetic>
      <one guid="Fake guid">
        <name>some name</name>
        <description>some description</description>
        <state>1</state>
        <bool>1</bool>
      </one>
    </kinetic>
    END_XML

    throws_ok { XML->new_from_xml($no_version) }
        qr/No version supplied in XML/,
        '... and calling it with kinetic XML without a version should fail';

    my $one = One->new;
    $one->name('some name');
    $one->description('some description');
    my $xml = XML->new($one);
    my $xml_string = $xml->dump_xml;
    my $object = $test->_force_inflation(XML->new_from_xml($xml_string));
    is_deeply $object, $one, '... and it should return a valid object';

    my $two = Two->new;
    $two->name('june17');
    $two->date(DateTime->new(
        year  => 1968,
        month => 6,
        day   => 17
    ));
    $two->one($one);
    $xml->object($two);
    $xml_string = $xml->dump_xml;
    $object = $test->_force_inflation(XML->new_from_xml($xml_string));
    is_deeply $object, $two, '... and contained objects should be deserializable, too';
}

sub constructor : Test(5) {
    my $test = shift;
    can_ok XML, 'new'; 
    my $one = One->new;
    ok my $xml = XML->new, '... and calling it should succeed';
    isa_ok $xml, XML, '... and the object it returns';

    my $bogus = bless {} => 'bogosity';
    throws_ok { XML->new($bogus) }
        qr/The object supplied must be a Kinetic object or subclass/,
        '... but if you feed it a non-Kinetic object, it should die';
    $xml = XML->new($one);
    isa_ok $xml, XML, '... but feeding it a valid Kinetic object should succeed';
}

sub object : Test(5) {
    my $xml = XML->new;
    my $one = One->new;
    can_ok $xml, 'object';
    my $bogus = bless {} => 'bogosity';
    throws_ok { $xml->object($bogus) }
        qr/The object supplied must be a Kinetic object or subclass/,
        '... but if you feed it a non-Kinetic object, it should die';
    ok $xml->object($one), '... but feeding it a Kinetic object should succeed';
    my $uno = $xml->object;
    is_deeply $one, $uno, '... and it should return the same object';

    my $un   = One->new;
    my $xml2 = XML->new($un);
    is_deeply $xml2->object, $un, 
        '... and passing the object into the constructor should succeed';
}

sub dump_xml : Test(5) {
    my $test = shift;
    my $one = One->new;
    $one->name('some name');
    $one->description('some description');
    my $xml = XML->new($one);
    my $one_guid = $one->guid;
    can_ok $xml, 'dump_xml';
    is_xml $xml->dump_xml, <<"    END_XML", '... and it should return the correct XML';
    <kinetic version="0.01">
      <one guid="$one_guid">
        <name>some name</name>
        <description>some description</description>
        <state>1</state>
        <bool>1</bool>
      </one>
    </kinetic>
    END_XML
    my $two = Two->new;
    $two->name('june17');
    $two->date(DateTime->new(
        year  => 1968,
        month => 6,
        day   => 17
    ));
    $two->one($one);
    $xml->object($two);
    my $two_guid = $two->guid;
    is_xml $xml->dump_xml({with_contained => 1}), <<"    END_XML", '... contained object should also be represented correctly';
    <kinetic version="0.01">
      <two guid="$two_guid">
        <name>june17</name>
        <description></description>
        <state>1</state>
        <one guid="$one_guid">
          <name>some name</name>
          <description>some description</description>
          <state>1</state>
          <bool>1</bool>
        </one>
        <age></age>
        <date>1968-06-17T00:00:00</date>
      </two>
    </kinetic>
    END_XML
    is_xml $xml->dump_xml({with_contained => 0}), <<"    END_XML", 'with_contained=0 should refer to contained objects by GUID';
    <kinetic version="0.01">
      <two guid="$two_guid">
        <name>june17</name>
        <description></description>
        <state>1</state>
        <one guid="$one_guid" relative="1"/>
        <age></age>
        <date>1968-06-17T00:00:00</date>
      </two>
      <one guid="$one_guid">
        <name>some name</name>
        <description>some description</description>
        <state>1</state>
        <bool>1</bool>
      </one>
    </kinetic>
    END_XML

    my ($foo, $bar, $baz) = @{$test->{test_objects}};
    $xml->object($foo);
    my ($guid, $id) = ($foo->guid, $foo->{id});
    is_xml $xml->dump_xml, <<"    END_XML", '... and if the object has an id, it should be in the XML';
    <kinetic version="0.01">
      <one guid="$guid">
        <name>foo</name>
        <description></description>
        <state>1</state>
        <bool>1</bool>
      </one>
    </kinetic>
    END_XML
}

1;
