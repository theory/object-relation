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
use aliased 'Test::MockModule';

use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

use aliased 'Kinetic::XML';

__PACKAGE__->runtests unless caller;

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

sub object : Test(no_plan) {
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

sub dump_xml : Test(no_plan) {
    my $one = One->new;
    $one->name('some name');
    $one->description('some description');
    $one->{guid} = 'Fake guid'; # XXX yeah, I know.  If there's a better way ...
    my $xml = XML->new($one);
    can_ok $xml, 'dump_xml';
    is_xml $xml->dump_xml, <<'    END_XML', '... and it should return the correct XML';
    <one guid="Fake guid">
      <name>some name</name>
      <description>some description</description>
      <state>Active</state>
      <bool>1</bool>
    </one>
    END_XML
    my $two = Two->new;
    $two->name('june17');
    $two->date(DateTime->new( 
        year  => 1968,
        month => 6,
        day   => 17 
    ));
    $two->one($one);
    $two->{guid} = 'another fake guid';
    $xml->object($two);
    is_xml $xml->dump_xml, <<'    END_XML', '... contained object should also be represented correctly';
    <two guid="another fake guid">
      <name>june17</name>
      <description></description>
      <state>Active</state>
      <one guid="Fake guid">
        <name>some name</name>
        <description>some description</description>
        <state>Active</state>
        <bool>1</bool>
      </one>
      <age></age>
      <date>1968-06-17T00:00:00</date>
    </two>
    END_XML
    diag "You ain't done, foo!  See \%params";
}
