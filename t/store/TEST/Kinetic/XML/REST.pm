package TEST::Kinetic::XML::REST;

# $Id: XML.pm 1094 2005-01-11 19:09:08Z curtis $

use strict;
use warnings;

use base 'TEST::Class::Kinetic';
use Test::More;
use Test::Exception;
use Test::XML;
use Encode qw(is_utf8);

use aliased 'Kinetic::XML::REST', 'XML';

__PACKAGE__->runtests unless caller;

{

    package Faux::REST;
    sub new { bless {}, shift }

    sub domain       { 'domain' }
    sub path         { 'path' }
    sub output_type  { 'output_type' }
    sub query_string { 'query_string' }
    sub base_url     { 'base_url' }
    sub xslt         { 'xslt' }
}

sub constructor : Test(5) {
    can_ok XML, 'new';
    throws_ok { XML->new } qr/Mandatory parameter 'rest' missing/,
      '... and calling it without parameters should fail';
    throws_ok { XML->new( { rest => bless {}, 'no_such_package' } ) }
      qr/The 'rest' parameter.*does not have the method: 'domain'/,
      '... and calling it without a valid "rest" argument should fail';

    ok my $xml = XML->new( { rest => Faux::REST->new } ),
      'Calling new() with valid arguments should succeed';
    isa_ok $xml, XML, '... and the object it returns';
}

sub properties : Test(12) {
    my $xml = XML->new( { rest => Faux::REST->new } );
    can_ok $xml, 'ns';
    throws_ok { $xml->ns('asdf') } 'Kinetic::Util::Exception::Fatal',
      '... and asking for a namespace which does not exist should fail';
    ok my $ns = $xml->ns('kinetic'),
      'Asking for a namespace which does exist should succeed';
    isa_ok $ns, 'XML::Genx::Namespace', '... and the object it returns';

    can_ok $xml, 'elem';
    throws_ok { $xml->elem('asdf') } 'Kinetic::Util::Exception::Fatal',
      '... and asking for an element which does not exist should fail';
    ok my $elem = $xml->elem('class_key'),
      'Asking for an element which does exist should succeed';
    isa_ok $elem, 'XML::Genx::Element', '... and the object it returns';

    can_ok $xml, 'attr';
    throws_ok { $xml->attr('asdf') } 'Kinetic::Util::Exception::Fatal',
      '... and asking for an attribute which does not exist should fail';
    ok my $attr = $xml->attr('href'),
      'Asking for an attribute which does exist should succeed';
    isa_ok $attr, 'XML::Genx::Attribute', '... and the object it returns';
}

sub delegate : Test(12) {
    my @methods = qw/
      AddAttribute
      AddNamespace
      AddText
      DeclareNamespace
      DeclareElement
      Element
      EndDocument
      EndElement
      GetDocString
      PI
      StartDocString
      StartElement
      /;
    my $xml = XML->new( { rest => Faux::REST->new } );

    foreach my $method (@methods) {
        ok $xml->can($method),
          "The delegated method '$method' should be available";
    }
}

sub build : Test(3) {
    my $xml = XML->new( { rest => Faux::REST->new } );
    can_ok $xml, 'build';
    ok my $result = $xml->build('some_title'),
      '... and calling it should succeed';
    is_well_formed_xml $result, '... and it should return well-formed XML';
}

1;
