package TEST::Kinetic::Meta::XML;

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

use aliased 'TestApp::Simple';
use aliased 'TestApp::Simple::One';
use aliased 'TestApp::Simple::Two'; # contains a TestApp::Simple::One object

use aliased 'Kinetic::Meta::XML';

__PACKAGE__->runtests unless caller;

sub constructor : Test(no_plan) {
    can_ok XML, 'new';
    ok my $xml = XML->new, '... and calling it should succeed';
    isa_ok $xml, XML, '... and the object it returns';
    ok $xml = XML->new(One->my_class), 'Calling new with a K::M::Class object should succeed';
    ok my $class = $xml->class, '... and it should set the class() attribute';
    is_deeply $class, One->my_class, '... and be able to return the correct class';
}

sub class : Test(5) {
    my $xml = XML->new;
    can_ok $xml, 'class';
    ok ! $xml->class, '... and it should return false if a class has not been set';
    throws_ok { $xml->class(bless {} => 'Wheeze::Chiz') }
        'Kinetic::Util::Exception::Fatal::InvalidClass',
        '... and it should die if fed an invalid class object';
    my $class = One->my_class;
    ok $xml->class($class), 'class() should succeed if handed a valid K::M::Class object';
    is_deeply $xml->class, $class, '... and it should return the class it stored.';
}

sub write_xml : Test(5) {
    can_ok XML, 'write_xml';
    my $xml = XML->new(Simple->my_class);
    my $file = 'one_xml';
    $xml->write_xml(file => $file);
    file_exists_ok $file, '... and it should create the file';
    TODO: {
        local $TODO = 'This will not work until calculated attributes (GUID) are handled';
        file_contents_is $file, $xml->dump_xml,
            '... and it should have the correct data';
    }

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
    TODO: {
        local $TODO = 'This will not work until calculated attributes (GUID) are handled';
        is $fh->contents, $xml->dump_xml, '... and it should work properly with a file handle';
    }
}

sub dump_xml : Test(no_plan) {
    my $xml = XML->new(Simple->my_class);
    can_ok $xml, 'dump_xml';
    diag '$attribute->widget seems to fail';
    is_xml $xml->dump_xml, <<'END_XML', '... and it should return the correct XML';
<kinetic version="0.01">
  <class key="simple">
    <package>TestApp::Simple</package>
    <name>Simple</name>
    <plural_name>Simples</plural_name>
    <desc>KISS.</desc>
    <abstract>0</abstract>
    <is_a>Kinetic</is_a>
    <constructors>
      <constructor>
        <name>new</name>
      </constructor>
    </constructors>
    <attributes>
      <attribute>
        <name>guid</name>
        <label>GUID</label>
        <type>guid</type>
        <required>1</required>
        <unique>1</unique>
        <once>1</once>
        <default><!-- XXX Hrm, have to decide how to handle this, since many
                      defaults are calculated.--></default>
        <authz>RDWR</authz>
        <widget>
          <type>text</type>
          <tip>The globally unique identifier for this object</tip>
        </widget>
      </attribute>
      <attribute>
        <name>name</name>
        <label>Name</label>
        <type>string</type>
        <required>1</required>
        <unique>0</unique>
        <once>0</once>
        <default></default>
        <authz>RDWR</authz>
        <widget>
          <type>text</type>
          <tip>The name of this object</tip>
        </widget>
      </attribute>
      <attribute>
        <name>state</name>
        <label>State</label>
        <type>state</type>
        <required>1</required>
        <unique>0</unique>
        <once>0</once>
        <default>1</default>
        <authz>RDWR</authz>
        <widget>
          <type>dropdown</type>
          <tip>The state of this object</tip>
          <options>
            <!-- XXX Hrm, Not sure how to handle this, since State objectgs
                 will not be available in the client-unless we add them. -->
            <option>[1, 'Active']</option>
            <option>[0, 'Inactive']</option>
            <option>[-1, 'Deleted]</option>
            <option>[-2, 'Purged']</option>
          </options>
        </widget>
      </attribute>
    </attributes>
  </class>
</kinetic>
END_XML

<<'ACTUAL_XML'; # XXX just a comment
<kinetic version="0.01">
  <class key="simple">
    <package>TestApp::Simple</package>
    <name>Simple</name>
    <plural_name>Simples</plural_name>
    <desc></desc>
    <abstract>0</abstract>
    <is_a></is_a>
    <constructors>
      <constructor>
        <name>new</name>
      </constructor>
    </constructors>
    <attributes>
      <attribute>
        <name>guid</name>
        <label>GUID</label>
        <type>guid</type>
        <required>1</required>
        <unique>1</unique>
        <once>1</once>
        <default>FA37DA20-AC4B-11D9-9481-D6394B585510</default>
        <authz>4</authz>
      </attribute>
      <attribute>
        <name>name</name>
        <label>Name</label>
        <type>string</type>
        <required>1</required>
        <unique>
        </unique>
        <once>0</once>
        <default></default>
        <authz>4</authz>
      </attribute>
      <attribute>
        <name>description</name>
        <label>Description</label>
        <type>string</type>
        <required>0</required>
        <unique></unique>
        <once>0</once>
        <default></default>
        <authz>4</authz>
      </attribute>
      <attribute>
        <name>state</name>
        <label>State</label>
        <type>state</type>
        <required>1</required>
        <unique></unique>
        <once>0</once>
        <default>Active</default>
        <authz>4</authz>
      </attribute>
    </attributes>
  </class>
</kinetic>
ACTUAL_XML
}

1;
