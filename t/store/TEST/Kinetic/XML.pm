package TEST::Kinetic::XML;

# $Id: XML.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Test::XML;
use Test::File;
use Test::File::Contents;

use Encode qw(is_utf8);

use aliased 'Kinetic::DateTime';
use aliased 'Test::MockModule';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

use aliased 'Kinetic::XML';

__PACKAGE__->runtests unless caller;

{
    package Faux::Store;
    my $one;
    BEGIN {
        $one = TestApp::Simple::One->new;
    }
    sub new {
        $one->name('one_name');
        bless {
            objects => {
                $one->guid => $one,
            },
            objects_by_name => {
                one => $one,
            },
        } => shift;
    }
    sub lookup {
        my ($self, $search_class, %params) = @_;
        return $self->{objects}{$params{guid}};
    }
    # not in the Store class, but used here as a testing hook
    sub _lookup {
        my ($self, $key) = @_;
        return $self->{objects_by_name}{$key};
    }
}

sub write_xml : Test(5) {
    can_ok XML, 'write_xml';
    my $one = One->new;
    $one->name('some name');
    $one->description('some description');
    my $xml = XML->new($one);
    my $one_guid = $one->guid;
    my $file = 'one_xml';
    $xml->write_xml(file => $file);
    file_exists_ok $file, '... and it should create the file';
    file_contents_is $file, $xml->dump_xml,
        '... and it should have the correct data';

    my $io_file = MockModule->new('IO::File');
    $io_file->mock('new', sub {}); # deliberately return a false value
    throws_ok {$xml->write_xml(file => $file)}
        'Kinetic::Util::Exception::Fatal::IO',
        '... but it should throw an exception if it can not open the file';
    unlink $file or die "Could not unlink file ($file): $!";

    {
        package Faux::IO;
        sub new      { bless {} => shift }
        sub print    { $_[0]->{contents} = $_[1] }
        sub contents { shift->{contents} }
        sub close    {}
    }
    my $fh = Faux::IO->new;
    $xml->write_xml(handle => $fh);
    is $fh->contents, $xml->dump_xml, '... and it should work properly with a file handle';
}

sub update_from_xml : Test(4) {
    my $test = shift;
    can_ok XML, 'update_from_xml';
    my $fstore = Faux::Store->new;
    my $one = $fstore->_lookup('one');
    my $updated_object = One->new(guid => $one->guid);
    my $store = MockModule->new('Kinetic::Store');
    $store->mock(new => Faux::Store->new);
    $updated_object->name($one->name);
    $updated_object->state($one->state);
    $updated_object->bool($one->bool);
    $updated_object->description('This is not the same description');
    my $xml = XML->new($updated_object); # note that one does not have an id
    my $xml_string = $xml->dump_xml;
    my $object = $test->_force_inflation(XML->update_from_xml($xml_string));
    ok exists $object->{id}, '... and an existing guid should provide its ID for the update';
    is_deeply $object, $updated_object, '... and the new object should be correct';

    $updated_object->{guid} = 'No such guid';
    $xml = XML->new($updated_object); 
    $xml_string = $xml->dump_xml;
    throws_ok {XML->update_from_xml($xml_string)}
        'Kinetic::Util::Exception::Fatal::NotFound',
        '... but a non-existing guid should throw an exception';
}

sub new_from_xml : Test(6) {
    my $test = shift;
    can_ok XML, 'new_from_xml';
    throws_ok { XML->new_from_xml }
        'Kinetic::Util::Exception::Fatal::RequiredArguments',
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
        'Kinetic::Util::Exception::Fatal::XML',
        '... and calling it with kinetic XML without a version should fail';

    my $no_such_class = <<'    END_XML';
    <kinetic version="0.01">
      <no_such_class guid="Fake guid">
        <name>some name</name>
        <description>some description</description>
        <state>1</state>
        <bool>1</bool>
      </no_such_class>
    </kinetic>
    END_XML

    throws_ok { XML->new_from_xml($no_such_class) }
        'Kinetic::Util::Exception::Fatal::UnknownClass',
        '... and calling it with an unknown class should fail';

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
        'Kinetic::Util::Exception::Fatal::InvalidClass',
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
        'Kinetic::Util::Exception::Fatal::InvalidClass',
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
    is_xml $xml->dump_xml(with_contained => 1), <<"    END_XML", '... contained object should also be represented correctly';
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
    is_xml $xml->dump_xml(with_contained => 0), <<"    END_XML", 'with_contained=0 should refer to contained objects by GUID';
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

    my $foo = One->new;
    $foo->name('foo');
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
