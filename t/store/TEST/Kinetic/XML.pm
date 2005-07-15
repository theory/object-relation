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

use Kinetic::Meta;
use Kinetic::Util::Language::en;
use aliased 'Kinetic::DateTime';
use aliased 'Test::MockModule';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

use aliased 'Kinetic::XML';

use Kinetic::Util::Exceptions qw/sig_handlers/;
BEGIN { sig_handlers(1) }

__PACKAGE__->runtests unless caller;

BEGIN {
    package MyTestThingy;
    use base 'Kinetic';
    my $km = Kinetic::Meta->new(
        key         => 'thingy',
        name        => 'Thingy',
        plural_name => 'Thingies',
    );
    $km->add_constructor(
        name   => 'new',
        create => 1,
    );
    $km->add_attribute(
        name          => 'foo',
        type          => 'string',
        label         => 'Foo',
        indexed       => 1,
        on_delete     => 'CASCADE',
        store_default => 'ick',
        widget_meta   => Kinetic::Meta::Widget->new(
            type => 'text',
            tip  => 'Kinetic',
        )
    );
    $km->build;

    package MyTestPartof;
    use base 'Kinetic';
    $km = Kinetic::Meta->new(
        key         => 'partof',
        name        => 'Partof',
        plural_name => 'Partofs',
    );
    $km->add_constructor(
        name   => 'new',
        create => 1,
    );
    $km->add_attribute(
        name          => 'thingy',
        type          => 'thingy',
        relationship  => 'part_of',
    );
    $km->build;

    Kinetic::Util::Language::en->add_to_lexicon(
      'Thingy'     => 'Thingy',
      'Thingies'   => 'Thingies',
      'Partof'     => 'Partof',
      'Partofs'    => 'Partofs',
      'References' => 'References',
    );
}

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

sub clear_km_keys : Test(shutdown) {
    Kinetic::Meta->clear('thingy');
    Kinetic::Meta->clear('partof');
}

sub write_xml : Test(5) {
    can_ok XML, 'write_xml';
    my $one = One->new;
    $one->name('some name');
    $one->description('some description');
    my $xml = XML->new({ object => $one });
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
        no warnings 'redefine';
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
    my $xml = XML->new({object => $updated_object}); # note that one does not have an id
    my $xml_string = $xml->dump_xml;
    my $object = $test->_force_inflation(XML->update_from_xml($xml_string));
    ok exists $object->{id}, '... and an existing guid should provide its ID for the update';
    is_deeply $object, $updated_object, '... and the new object should be correct';

    $updated_object->{guid} = 'No such guid';
    $xml = XML->new({ object => $updated_object}); 
    $xml_string = $xml->dump_xml;
    throws_ok {XML->update_from_xml($xml_string)}
        'Kinetic::Util::Exception::Fatal::NotFound',
        '... but a non-existing guid should throw an exception';
}

sub new_from_xml : Test(7) {
    my $test = shift;
    can_ok XML, 'new_from_xml';
    throws_ok { XML->new_from_xml }
        'Kinetic::Util::Exception::Fatal::RequiredArguments',
        '... and calling it without an argument should fail';

    my $no_version = <<'    END_XML';
    <kinetic>
      <instance key="one">
        <attr name="guid">Fake guid</attr>
        <attr name="name">some name</attr>
        <attr name="description">some description</attr>
        <attr name="state">1</attr>
        <attr name="bool">1</attr>
      </instance>
    </kinetic>
    END_XML

    throws_ok { XML->new_from_xml($no_version) }
        'Kinetic::Util::Exception::Fatal::XML',
        '... and calling it with kinetic XML without a version should fail';

    my $no_such_class = <<'    END_XML';
    <kinetic version="0.01">
      <instance key="no_such_class">
        <attr name="guid">Fake guid</attr>
        <attr name="name">some name</attr>
        <attr name="description">some description</attr>
        <attr name="state">1</attr>
        <attr name="bool">1</attr>
      </instance>
    </kinetic>
    END_XML

    throws_ok { XML->new_from_xml($no_such_class) }
        'Kinetic::Util::Exception::Fatal::UnknownClass',
        '... and calling it with an unknown class should fail';

    my $one = One->new;
    $one->name('some name');
    $one->description('some description');
    my $xml = XML->new({ object => $one});
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
    is_deeply $object, $two, 'Contained objects should be deserializable, too';

    my $contained_xml = <<"    END_XML"; 
    <kinetic version="0.01">
      <two guid="@{[$two->guid]}">
        <age></age>
        <date>1968-06-17T00:00:00</date>
        <description></description>
        <name>june17</name>
        <one guid="@{[$one->guid]}">
          <bool>1</bool>
          <description>some description</description>
          <name>some name</name>
          <state>1</state>
        </one>
        <state>1</state>
      </two>
    </kinetic>
    END_XML
    $object = $test->_force_inflation(XML->new_from_xml($contained_xml));
    is_deeply $object, $two, '... even if we are using old-style xml';
}

sub constructor : Test(5) {
    my $test = shift;
    can_ok XML, 'new'; 
    my $one = One->new;
    ok my $xml = XML->new, '... and calling it should succeed';
    isa_ok $xml, XML, '... and the object it returns';

    my $bogus = bless {} => 'bogosity';
    throws_ok { XML->new({ object => $bogus}) }
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

sub dump_xml : Test(7) {
    my $one = One->new;
    $one->name('some name');
    $one->description('some description');
    my $xml = XML->new($one);
    my $one_guid = $one->guid;
    can_ok $xml, 'dump_xml';
    is_xml $xml->dump_xml, <<"    END_XML", '... and it should return the correct XML';
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description">some description</attr>
        <attr name="guid">$one_guid</attr>
        <attr name="name">some name</attr>
        <attr name="state">1</attr>
      </instance>
    </kinetic>
    END_XML
    my $not_referenced = Two->new;
    $not_referenced->name('june17');
    $not_referenced->date(DateTime->new(
        year  => 1968,
        month => 6,
        day   => 17
    ));
    $not_referenced->one($one);
    $xml->object($not_referenced);
    my $not_referenced_guid = $not_referenced->guid;
    is_xml $xml->dump_xml(with_referenced => 1), <<"    END_XML", '... contained object should also be represented correctly';
    <kinetic version="0.01">
      <instance key="two">
        <attr name="age"></attr>
        <attr name="date">1968-06-17T00:00:00</attr>
        <attr name="description"></attr>
        <attr name="guid">$not_referenced_guid</attr>
        <attr name="name">june17</attr>
        <instance key="one">
          <attr name="bool">1</attr>
          <attr name="description">some description</attr>
          <attr name="guid">$one_guid</attr>
          <attr name="name">some name</attr>
          <attr name="state">1</attr>
        </instance>
        <attr name="state">1</attr>
      </instance>
    </kinetic>
    END_XML
    is_xml $xml->dump_xml(with_referenced => 0), <<"    END_XML", 'with_referenced=0 should be a no-op with "has" relationships';
    <kinetic version="0.01">
      <instance key="two">
        <attr name="age"></attr>
        <attr name="date">1968-06-17T00:00:00</attr>
        <attr name="description"></attr>
        <attr name="guid">$not_referenced_guid</attr>
        <attr name="name">june17</attr>
        <instance key="one">
          <attr name="bool">1</attr>
          <attr name="description">some description</attr>
          <attr name="guid">$one_guid</attr>
          <attr name="name">some name</attr>
          <attr name="state">1</attr>
        </instance>
        <attr name="state">1</attr>
      </instance>
    </kinetic>
    END_XML

    my $partof = MyTestPartof->new;
    my $thingy = MyTestThingy->new(foo => 'bar');
    $partof->thingy($thingy);
    $xml->object($partof);
    my ($partof_guid, $thingy_guid) = ($partof->guid, $thingy->guid);
    is_xml $xml->dump_xml, <<"    END_XML", 'Referenced objects should only include the GUID';
    <kinetic version="0.01">
      <instance key="partof">
        <attr name="guid">$partof_guid</attr>
        <attr name="state">1</attr>
        <instance key="thingy" guid="$thingy_guid" referenced="1"/>
      </instance>
    </kinetic>
    END_XML
    is_xml $xml->dump_xml(with_referenced => 1), <<"    END_XML", '... but they should append the referenced object if you ask nicely';
    <kinetic version="0.01">
      <instance key="partof">
        <attr name="guid">$partof_guid</attr>
        <attr name="state">1</attr>
        <instance key="thingy" guid="$thingy_guid" referenced="1"/>
      </instance>
      <instance key="thingy">
        <attr name="foo">bar</attr>
        <attr name="guid">$thingy_guid</attr>
        <attr name="state">1</attr>
      </instance>
    </kinetic>
    END_XML

    my $foo = One->new;
    $foo->name('foo');
    $xml->object($foo);
    my $guid = $foo->guid;
    is_xml $xml->dump_xml, <<"    END_XML", '... and if the object has an id, it should be in the XML';
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description"></attr>
        <attr name="guid">$guid</attr>
        <attr name="name">foo</attr>
        <attr name="state">1</attr>
      </instance>
    </kinetic>
    END_XML
}

sub dump_xml_with_stylesheet : Test(1) {
    my $one = One->new;
    $one->name('some name');
    $one->description('some description');
    my $xml = XML->new({
        object         => $one,
        stylesheet_url => 'http://foobar/xslt_stylesheet',
    });
    my $one_guid = $one->guid;
    is_xml $xml->dump_xml, <<"    END_XML", 'Supplying a stylesheet URL should embed it in the XML';
    <?xml-stylesheet type="text/xsl" href="http://foobar/xslt_stylesheet"?>
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description">some description</attr>
        <attr name="guid">$one_guid</attr>
        <attr name="name">some name</attr>
        <attr name="state">1</attr>
      </instance>
    </kinetic>
    END_XML
}

1;
