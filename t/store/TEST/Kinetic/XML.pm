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

use Class::Trait qw(TEST::Kinetic::Traits::Store);
use Kinetic::Meta;
use Kinetic::Util::Language::en;
use aliased 'Kinetic::DateTime';
use aliased 'Test::MockModule';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';    # contains a TestApp::Simple::One object

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
        name         => 'thingy',
        type         => 'thingy',
        relationship => 'part_of',
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
            objects         => { $one->uuid => $one, },
            objects_by_name => { one        => $one, },
        } => shift;
    }

    sub lookup {
        my ( $self, $search_class, %params ) = @_;
        return $self->{objects}{ $params{uuid} };
    }

    # not in the Store class, but used here as a testing hook
    sub _lookup {
        my ( $self, $key ) = @_;
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
    my $xml      = XML->new( { object => $one } );
    my $one_uuid = $one->uuid;
    my $file     = 'one_xml';
    $xml->write_xml( file => $file );
    file_exists_ok $file,   '... and it should create the file';
    file_contents_is $file, $xml->dump_xml,
      '... and it should have the correct data';

    my $io_file = MockModule->new('IO::File');
    $io_file->mock( 'new', sub { } );    # deliberately return a false value
    throws_ok { $xml->write_xml( file => $file ) }
      'Kinetic::Util::Exception::Fatal::IO',
      '... but it should throw an exception if it can not open the file';
    unlink $file or die "Could not unlink file ($file): $!";

    {
        no warnings 'redefine';

        package Faux::IO;
        sub new { bless {} => shift }
        sub print { $_[0]->{contents} = $_[1] }
        sub contents { shift->{contents} }
        sub close    { }
    }
    my $fh = Faux::IO->new;
    $xml->write_xml( handle => $fh );
    is $fh->contents, $xml->dump_xml,
      '... and it should work properly with a file handle';
}

sub update_from_xml : Test(4) {
    my $test = shift;
    can_ok XML, 'update_from_xml';
    my $fstore         = Faux::Store->new;
    my $one            = $fstore->_lookup('one');
    my $updated_object = One->new( uuid => $one->uuid );
    my $store          = MockModule->new('Kinetic::Store');
    $store->mock( new => Faux::Store->new );
    $updated_object->name( $one->name );
    $updated_object->state( $one->state );
    $updated_object->bool( $one->bool );
    $updated_object->description('This is not the same description');
    my $xml =
      XML->new( { object => $updated_object } )
      ;    # note that one does not have an id
    my $xml_string = $xml->dump_xml;
    my $object = $test->force_inflation( XML->update_from_xml($xml_string) );

    #diag $xml_string;
    ok exists $object->{id},
      '... and an existing uuid should provide its ID for the update';
    is_deeply $object, $updated_object,
      '... and the new object should be correct';

    $updated_object->{uuid} = 'No such uuid';
    $xml = XML->new( { object => $updated_object } );
    $xml_string = $xml->dump_xml;
    throws_ok { XML->update_from_xml($xml_string) }
      'Kinetic::Util::Exception::Fatal::NotFound',
      '... but a non-existing uuid should throw an exception';
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
        <attr name="uuid">Fake uuid</attr>
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
        <attr name="uuid">Fake uuid</attr>
        <attr name="name">some name</attr>
        <attr name="description">some description</attr>
        <attr name="state">1</attr>
        <attr name="bool">1</attr>
      </instance>
    </kinetic>
    END_XML

    throws_ok { XML->new_from_xml($no_such_class) }
      'Kinetic::Util::Exception::Fatal::InvalidClass',
      '... and calling it with an unknown class should fail';

    my $one = One->new;
    $one->name('some name');
    $one->description('some description');
    my $xml        = XML->new( { object => $one } );
    my $xml_string = $xml->dump_xml;
    my $object     = $test->force_inflation( XML->new_from_xml($xml_string) );
    is_deeply $object, $one, '... and it should return a valid object';

    my $two = Two->new;
    $two->name('june17');
    $two->date(
        DateTime->new(
            year  => 1968,
            month => 6,
            day   => 17
        )
    );
    $two->one($one);
    $xml->object($two);
    $xml_string = $xml->dump_xml;
    $object     = $test->force_inflation( XML->new_from_xml($xml_string) );
    is_deeply $object, $two, 'Contained objects should be deserializable, too';

    my $contained_xml = <<"    END_XML";
    <kinetic version="0.01">
      <two uuid="@{[$two->uuid]}">
        <age></age>
        <date>1968-06-17T00:00:00</date>
        <description></description>
        <name>june17</name>
        <one uuid="@{[$one->uuid]}">
          <bool>1</bool>
          <description>some description</description>
          <name>some name</name>
          <state>1</state>
        </one>
        <state>1</state>
      </two>
    </kinetic>
    END_XML
    $object = $test->force_inflation( XML->new_from_xml($contained_xml) );
    is_deeply $object, $two, '... even if we are using old-style xml';
}

sub constructor : Test(5) {
    my $test = shift;
    can_ok XML, 'new';
    my $one = One->new;
    ok my $xml = XML->new, '... and calling it should succeed';
    isa_ok $xml, XML, '... and the object it returns';

    my $bogus = bless {} => 'bogosity';
    throws_ok { XML->new( { object => $bogus } ) }
      'Kinetic::Util::Exception::Fatal::InvalidClass',
      '... but if you feed it a non-Kinetic object, it should die';
    $xml = XML->new($one);
    isa_ok $xml, XML,
      '... but feeding it a valid Kinetic object should succeed';
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
    my $xml      = XML->new($one);
    my $one_uuid = $one->uuid;
    can_ok $xml, 'dump_xml';
    is_xml $xml->dump_xml,
      <<"    END_XML", '... and it should return the correct XML';
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description">some description</attr>
        <attr name="name">some name</attr>
        <attr name="state">1</attr>
        <attr name="uuid">$one_uuid</attr>
      </instance>
    </kinetic>
    END_XML
    my $not_referenced = Two->new;
    $not_referenced->name('june17');
    $not_referenced->date(
        DateTime->new(
            year  => 1968,
            month => 6,
            day   => 17
        )
    );
    $not_referenced->one($one);
    $xml->object($not_referenced);
    my $not_referenced_uuid = $not_referenced->uuid;
    is_xml $xml->dump_xml( with_referenced => 1 ),
      <<"    END_XML", '... contained object should also be represented correctly';
    <kinetic version="0.01">
      <instance key="two">
        <attr name="age"></attr>
        <attr name="date">1968-06-17T00:00:00</attr>
        <attr name="description"></attr>
        <attr name="name">june17</attr>
        <instance key="one">
          <attr name="bool">1</attr>
          <attr name="description">some description</attr>
          <attr name="name">some name</attr>
          <attr name="state">1</attr>
          <attr name="uuid">$one_uuid</attr>
        </instance>
        <attr name="state">1</attr>
        <attr name="uuid">$not_referenced_uuid</attr>
      </instance>
    </kinetic>
    END_XML
    is_xml $xml->dump_xml( with_referenced => 0 ),
      <<"    END_XML", 'with_referenced=0 should be a no-op with "has" relationships';
    <kinetic version="0.01">
      <instance key="two">
        <attr name="age"></attr>
        <attr name="date">1968-06-17T00:00:00</attr>
        <attr name="description"></attr>
        <attr name="name">june17</attr>
        <instance key="one">
          <attr name="bool">1</attr>
          <attr name="description">some description</attr>
          <attr name="name">some name</attr>
          <attr name="state">1</attr>
          <attr name="uuid">$one_uuid</attr>
        </instance>
        <attr name="state">1</attr>
        <attr name="uuid">$not_referenced_uuid</attr>
      </instance>
    </kinetic>
    END_XML

    my $partof = MyTestPartof->new;
    my $thingy = MyTestThingy->new( foo => 'bar' );
    $partof->thingy($thingy);
    $xml->object($partof);
    my ( $partof_uuid, $thingy_uuid ) = ( $partof->uuid, $thingy->uuid );
    is_xml $xml->dump_xml,
      <<"    END_XML", 'Referenced objects should only include the UUID';
    <kinetic version="0.01">
      <instance key="partof">
        <attr name="state">1</attr>
        <instance key="thingy" uuid="$thingy_uuid" referenced="1"/>
        <attr name="uuid">$partof_uuid</attr>
      </instance>
    </kinetic>
    END_XML
    is_xml $xml->dump_xml( with_referenced => 1 ),
      <<"    END_XML", '... but they should append the referenced object if you ask nicely';
    <kinetic version="0.01">
      <instance key="partof">
        <attr name="state">1</attr>
        <instance key="thingy" uuid="$thingy_uuid" referenced="1"/>
        <attr name="uuid">$partof_uuid</attr>
      </instance>
      <instance key="thingy">
        <attr name="foo">bar</attr>
        <attr name="state">1</attr>
        <attr name="uuid">$thingy_uuid</attr>
      </instance>
    </kinetic>
    END_XML

    my $foo = One->new;
    $foo->name('foo');
    $xml->object($foo);
    my $uuid = $foo->uuid;
    is_xml $xml->dump_xml,
      <<"    END_XML", '... and if the object has an id, it should be in the XML';
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description"></attr>
        <attr name="name">foo</attr>
        <attr name="state">1</attr>
        <attr name="uuid">$uuid</attr>
      </instance>
    </kinetic>
    END_XML
}

sub dump_xml_with_resources : Test(9) {
    my $one = One->new;
    $one->name('some name');
    $one->description('some description');
    my $stylesheet = 'http://foobar/xslt_stylesheet';
    my $resources  = 'http://foobar/';
    my $xml        = XML->new(
        {
            object         => $one,
            stylesheet_url => $stylesheet,
            resources_url  => $resources,
        }
    );

    # we have more resources than are defined in this test class as the test
    # suite generates some other resources.  This does not affect the validity
    # of the test so long as we're aware of these other classes.

    # namespaces are not used as XML::Genx appears to have problems generating
    # them correctly :(

    my $resource_xml = <<'    END_RESOURCES';
    <resource href="http://foobar/one/search"    id="one"/>
    <resource href="http://foobar/partof/search" id="partof"/>
    <resource href="http://foobar/simple/search" id="simple"/>
    <resource href="http://foobar/thingy/search" id="thingy"/>
    <resource href="http://foobar/two/search"    id="two"/>
    END_RESOURCES

    my $one_uuid = $one->uuid;
    is_xml $xml->dump_xml,
      <<"    END_XML", 'Supplying a stylesheet URL should embed it in the XML';
    <?xml-stylesheet type="text/xsl" href="$stylesheet"?>
    <kinetic version="0.01">
      $resource_xml
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description">some description</attr>
        <attr name="name">some name</attr>
        <attr name="state">1</attr>
        <attr name="uuid">$one_uuid</attr>
      </instance>
    </kinetic>
    END_XML

    can_ok $xml, 'stylesheet_url';
    is $xml->stylesheet_url, $stylesheet,
      '... and it should return the correct stylesheet';
    $stylesheet = 'http://foobar/new_xslt_stylesheet';
    ok $xml->stylesheet_url($stylesheet),
      '... and we should be able to set it to a new value';
    is $xml->stylesheet_url, $stylesheet,
      '... and it should return the new stylesheet';

    is_xml $xml->dump_xml,
      <<"    END_XML", '... and new XML should use the new stylesheet';
    <?xml-stylesheet type="text/xsl" href="$stylesheet"?>
    <kinetic version="0.01">
      $resource_xml
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description">some description</attr>
        <attr name="name">some name</attr>
        <attr name="state">1</attr>
        <attr name="uuid">$one_uuid</attr>
      </instance>
    </kinetic>
    END_XML

    ok $xml->stylesheet_url(undef),
      'We should be able to set it to an undefined value';
    ok !defined $xml->stylesheet_url, '... and the it should now return undef';

    is_xml $xml->dump_xml,
      <<"    END_XML", '... and new XML should not have a stylesheet URL';
    <kinetic version="0.01">
      $resource_xml
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description">some description</attr>
        <attr name="name">some name</attr>
        <attr name="state">1</attr>
        <attr name="uuid">$one_uuid</attr>
      </instance>
    </kinetic>
    END_XML
}

sub dump_xml_with_stylesheet : Test(9) {
    my $one = One->new;
    $one->name('some name');
    $one->description('some description');
    my $stylesheet = 'http://foobar/xslt_stylesheet';
    my $xml        = XML->new(
        {
            object         => $one,
            stylesheet_url => $stylesheet,
        }
    );
    my $one_uuid = $one->uuid;
    is_xml $xml->dump_xml,
      <<"    END_XML", 'Supplying a stylesheet URL should embed it in the XML';
    <?xml-stylesheet type="text/xsl" href="$stylesheet"?>
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description">some description</attr>
        <attr name="name">some name</attr>
        <attr name="state">1</attr>
        <attr name="uuid">$one_uuid</attr>
      </instance>
    </kinetic>
    END_XML

    can_ok $xml, 'stylesheet_url';
    is $xml->stylesheet_url, $stylesheet,
      '... and it should return the correct stylesheet';
    $stylesheet = 'http://foobar/new_xslt_stylesheet';
    ok $xml->stylesheet_url($stylesheet),
      '... and we should be able to set it to a new value';
    is $xml->stylesheet_url, $stylesheet,
      '... and it should return the new stylesheet';

    is_xml $xml->dump_xml,
      <<"    END_XML", '... and new XML should use the new stylesheet';
    <?xml-stylesheet type="text/xsl" href="$stylesheet"?>
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description">some description</attr>
        <attr name="name">some name</attr>
        <attr name="state">1</attr>
        <attr name="uuid">$one_uuid</attr>
      </instance>
    </kinetic>
    END_XML

    ok $xml->stylesheet_url(undef),
      'We should be able to set it to an undefined value';
    ok !defined $xml->stylesheet_url, '... and the it should now return undef';

    is_xml $xml->dump_xml,
      <<"    END_XML", '... and new XML should not have a stylesheet URL';
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description">some description</attr>
        <attr name="name">some name</attr>
        <attr name="state">1</attr>
        <attr name="uuid">$one_uuid</attr>
      </instance>
    </kinetic>
    END_XML
}

sub specify_desired_attributes : Test(13) {
    my $one = One->new;
    $one->name('some name');
    $one->description('some description');

    throws_ok { XML->new( { attributes => { bool => 1 } } ) }
      'Kinetic::Util::Exception::Fatal::Invalid',
      'Specifying attributes as a hashref should throw an exception';

    my $xml = XML->new(
        {
            object     => $one,
            attributes => [qw/bool uuid state/],
        }
    );

    my $one_uuid = $one->uuid;
    is_xml $xml->dump_xml,
      <<"    END_XML", 'Specifying desired attributes to be returned should work';
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="state">1</attr>
        <attr name="uuid">$one_uuid</attr>
      </instance>
    </kinetic>
    END_XML

    can_ok $xml, 'attributes';
    ok $xml->attributes( [qw/bool state/] ),
      '... and we should be able to set the attributes';
    is_xml $xml->dump_xml,
      <<"    END_XML", '... and have the new xml reflect this';
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="state">1</attr>
      </instance>
    </kinetic>
    END_XML

    ok $xml->attributes('state'), 'We should be able to set a single attribute';
    is_xml $xml->dump_xml,
      <<"    END_XML", '... and have the new xml only show that attribute';
    <kinetic version="0.01">
      <instance key="one">
        <attr name="state">1</attr>
      </instance>
    </kinetic>
    END_XML

    ok $xml->attributes(undef),
      'We should be able to "unset" requested attributes';
    is_xml $xml->dump_xml, <<"    END_XML", '... and get all of the attributes';
    <kinetic version="0.01">
      <instance key="one">
        <attr name="bool">1</attr>
        <attr name="description">some description</attr>
        <attr name="name">some name</attr>
        <attr name="state">1</attr>
        <attr name="uuid">$one_uuid</attr>
      </instance>
    </kinetic>
    END_XML

    # must test contained objects
    #
    # what happens if we specify a contained object but not
    # any of its keys?

    my $two = Two->new;
    $two->name('june17');
    $two->date(
        DateTime->new(
            year  => 1968,
            month => 6,
            day   => 17
        )
    );
    $two->one($one);
    $xml->object($two);
    my $two_uuid = $two->uuid;
    $xml->attributes(undef);
    is_xml $xml->dump_xml( with_referenced => 1 ),
      <<"    END_XML", 'Contained object should also be represented correctly';
    <kinetic version="0.01">
      <instance key="two">
        <attr name="age"></attr>
        <attr name="date">1968-06-17T00:00:00</attr>
        <attr name="description"></attr>
        <attr name="name">june17</attr>
        <instance key="one">
          <attr name="bool">1</attr>
          <attr name="description">some description</attr>
          <attr name="name">some name</attr>
          <attr name="state">1</attr>
          <attr name="uuid">$one_uuid</attr>
        </instance>
        <attr name="state">1</attr>
        <attr name="uuid">$two_uuid</attr>
      </instance>
    </kinetic>
    END_XML

    $xml->attributes( [qw/date uuid name one/] );
    is_xml $xml->dump_xml( with_referenced => 1 ),
      <<"    END_XML", '... even if we specify them directly';
    <kinetic version="0.01">
      <instance key="two">
        <attr name="date">1968-06-17T00:00:00</attr>
        <attr name="name">june17</attr>
        <instance key="one">
          <attr name="bool">1</attr>
          <attr name="description">some description</attr>
          <attr name="name">some name</attr>
          <attr name="state">1</attr>
          <attr name="uuid">$one_uuid</attr>
        </instance>
        <attr name="uuid">$two_uuid</attr>
      </instance>
    </kinetic>
    END_XML

    $xml->attributes( [qw/name one.uuid one.name/] );
    is_xml $xml->dump_xml( with_referenced => 1 ),
      <<"    END_XML", '... or specify their attributes without specifying the object';
    <kinetic version="0.01">
      <instance key="two">
        <attr name="name">june17</attr>
        <instance key="one">
          <attr name="name">some name</attr>
          <attr name="uuid">$one_uuid</attr>
        </instance>
      </instance>
    </kinetic>
    END_XML

    $xml->attributes( [qw/date uuid name/] );
    is_xml $xml->dump_xml( with_referenced => 1 ),
      <<"    END_XML", 'with_referenced is a no-op if they specify attributes but not the contained object';
    <kinetic version="0.01">
      <instance key="two">
        <attr name="date">1968-06-17T00:00:00</attr>
        <attr name="name">june17</attr>
        <attr name="uuid">$two_uuid</attr>
      </instance>
    </kinetic>
    END_XML
}

1;
__END__
