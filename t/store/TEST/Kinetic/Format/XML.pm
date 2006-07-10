package TEST::Kinetic::Format::XML;

# $Id$

use strict;
use warnings;

use base 'TEST::Class::Kinetic';

use Test::XML;
use Test::More;
use Test::Exception;
use Class::Trait qw(
    TEST::Kinetic::Traits::Store
    TEST::Kinetic::Traits::SampleObjects
);

use Kinetic::Util::Constants qw/UUID_RE/;

use aliased 'Test::MockModule';
use aliased 'Kinetic::Store' => 'Store', ':all';
use aliased 'Kinetic::DataType::DateTime';
use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two';    # contains a TestApp::Simple::One object

use aliased 'Kinetic::Format::XML';

__PACKAGE__->SKIP_CLASS(
    $ENV{KS_CLASS}
    ? 0
    : "Not testing Data Stores"
) if caller;    # so I can run the tests directly from vim
__PACKAGE__->runtests unless caller;

sub setup : Test(setup) {
    my $test = shift;
    $test->mock_dbh;
    $test->create_test_objects;
}

sub teardown : Test(teardown) {
    my $test = shift;
    $test->unmock_dbh;
}

sub constructor : Test(3) {
    my $test = shift;
    can_ok XML, 'new';
    ok my $formatter = XML->new, '... and calling it should succeed';
    isa_ok $formatter, XML, '... and the object it returns';
}

sub serialize : Test(7) {
    my $test = shift;
    my $formatter = Kinetic::Format::XML->new;
    my ( $foo, $bar, $baz ) = $test->test_objects;
    can_ok $formatter, 'serialize';
    ok my $xml = $formatter->serialize($foo),
      '... and serializing an object should succeed';
    is_well_formed_xml $xml, '... and it should return valid XML';
    $xml =~ s/${\UUID_RE}/XXX/g;
    my $expected = <<'    END_EXPECTED';
    <opt 
        name="foo" 
        Key="one" 
        bool="1" 
        description="" 
        state="1" 
        uuid="XXX" 
    />
    END_EXPECTED
    is_xml $xml, $expected, '... and it should return the correct XML';

    # test contained object serialization

    my $two = Two->new;
    $two->name('june17');
    $two->date(
        DateTime->new(
            year  => 1968,
            month => 6,
            day   => 17
        )
    );
    $two->one($foo);
    ok $xml = $formatter->serialize($two),
      'Serializing an object with a contained object should succeed';
    is_well_formed_xml $xml, '... and it should return valid XML';
    $xml =~ s/${\UUID_RE}/XXX/g;

    $expected = <<'    END_EXPECTED';
    <opt
        name="june17"
        Key="two"
        age=""
        date="1968-06-17T00:00:00"
        description=""
        state="1"
        uuid="XXX">
        <one name="foo" Key="one" bool="1" description="" state="1" uuid="XXX" />
    </opt>
    END_EXPECTED
    is_xml $xml, $expected, '... and the XML should be the correct XML';
}

sub deserialize : Test(5) {
    my $test = shift;
    my $formatter = Kinetic::Format::XML->new;
    my ( $foo, $bar, $baz ) = $test->test_objects;
    can_ok $formatter, 'deserialize';
    my $xml = $formatter->serialize($foo);

    my $bad_key = $xml;
    $bad_key =~ s/one/no_such_key/;

    throws_ok { $formatter->deserialize($bad_key) }
      'Kinetic::Util::Exception::Fatal::InvalidClass',
      '... and it should throw an exception if it finds an invalid key';
    my $new_foo = $formatter->deserialize($xml);
    foreach ( $new_foo, $foo ) {

        # XXX we have to do this because id exists in the objects, but not in
        # the XML so it doesn't persist and is therefore not returned.
        delete $_->{id};
    }

    diag "Return to XML format tests when we need them";
return;
    is_deeply $new_foo, $foo,
      '... and it should be able to deserialize a Kinetic object from XML';

    # test contained objects

    my $two = Two->new;
    $two->name('june17');
    $two->date(
        DateTime->new(
            year  => 1968,
            month => 6,
            day   => 17
        )
    );
    $two->one($foo);
    $xml = $formatter->serialize($two);
    ok my $new_object = $formatter->deserialize($xml),
      'We should be able to deserialize contained XML objects';
    $test->force_inflation($new_object);

    foreach ( $two, $new_object ) {
        delete $_->{id};
        delete $_->one->{id};
    }
    is_deeply $two, $new_object, '... and the should return the correct object';
}

sub content_type : Test(2) {
    my $test      = shift;
    my $formatter = Kinetic::Format::XML->new;
    can_ok $formatter, 'content_type';
    is $formatter->content_type, 'text/xml',
      '... and it should return the correct content type';
}

1
