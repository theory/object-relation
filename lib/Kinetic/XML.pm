package Kinetic::XML;

# $Id: XML.pm 1407 2005-03-23 02:55:28Z curtis $

# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted to you
# to modify and distribute this software under the terms of the GNU General
# Public License Version 2, and is only of importance to you if you choose to
# contribute your changes and enhancements to the community by submitting them
# to Kineticode, Inc.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with the
# Kinetic framework, to Kineticode, Inc., you confirm that you are the
# copyright holder for those contributions and you grant Kineticode, Inc.
# a nonexclusive, worldwide, irrevocable, royalty-free, perpetual license to
# use, copy, create derivative works based on those contributions, and
# sublicense and distribute those contributions and any derivatives thereof.

use strict;
use IO::File;
use XML::Genx::Simple;
use XML::Simple;
use Kinetic::Util::Exceptions ':all';

use Kinetic::Meta;
use Kinetic::Store;

use constant XML_VERSION => '0.01';

=head1 Name

Kinetic::XML - The Kinetic XML serialization class

=head1 Synopsis

  use Kinetic::XML;
  my $xml = Kinetic::XML->new;
  $xml->object($kinetic_object);
  my $xml_string = $xml->dump_xml;

=head1 Description

This class is used for serializing and deserializing Kinetic objects to and and
from XML.  New objects may be created or existing objects may be updated using
this class.

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

  my $xml = Kinetic::XML->new;
  # or
  my $xml = Kinetic::XML->new($kinetic_object);

Creates and returns a new xml object.  It optionally takes a L<Kinetic|Kinetic>
object as an argument.  This is equivalent to:

  my $xml = Kinetic::XML->new;
  $xml->object($kinetic_object);

=cut

sub new {
    my ($class, $object) = @_;
    my $self = bless {}, $class;
    return $self unless $object;
    $self->object($object);
}

##############################################################################
# Class Methods
##############################################################################

=head2 Instance Methods

##############################################################################

=head3 new_from_xml

 my $kinetic_object = Kinetic::XML->new_from_xml($xml);

Loads the data in an XML representation of the Kinetic business object as a
new object. This method will return a B<Kinetic> object, not a C<Kinetic::XML>
object.

=cut

sub new_from_xml {
    my ($class, $xml_string, $params) = @_;
    throw_required ['Required argument "[_1]" to [_2] not found', 1, 'new_from_xml()']
        unless $xml_string;
    my $self = $class->new;
    $self->{params} = $params || {};
    my $data = $self->_get_hash_from_xml($xml_string);
    my ($key) = keys %$data; # XXX Currently assumes only one key
    return $self->_fetch_object($key, $data->{$key}, $params);
}

##############################################################################

=head3 _get_hash_from_xml

  my $hash = $xml->_get_hash_from_xml($xml_string);

Given a string containing Kinetic XML, this method returns a hash representing
that XML.  This method will throw an exception if either a version number is
missing or if the XML is not valid Kinetic XML.

=cut

sub _get_hash_from_xml {
    my ($self, $xml_string) = @_;
    my $xml  = XML::Simple->new;
    my $data = $xml->XMLin($xml_string, suppressempty => undef, keyattr => []);
    my $version = delete $data->{version}
        or throw_xml "XML must have a version number.";
    return $data;
}

##############################################################################

=head3 _fetch_object

  my $object = $xml->_fetch_object($key, $data);

This method takes a Kinetic::Meta key and a hashref for its data and will
return an object for the appropriate class. Contained objects will also be
handled correctly.

=cut

sub _fetch_object {
    my ($self, $key, $data) = @_;
    foreach my $attribute (keys %$data) {
        if ('HASH' eq ref $data->{$attribute}) {
            $data->{$attribute} = $self->_fetch_object($attribute, $data->{$attribute});
        }
    }
    my $class = Kinetic::Meta->for_key($key)
        or throw_unknown_class ['I could not find the class for key "[_1]"', $key];

    # XXX Bleh! There's no validation here. We need validation by using the
    # individual attribute accessors.
    my $object;
    if ($self->{params}{update}) {
        my $store = Kinetic::Store->new;
        $object = $store->lookup($class, guid => $data->{guid});
        throw_not_found [
            'I could not find guid "[_1]" in data store for the [_2] class',
            $data->{guid},
            $class->package
        ] unless $object;
    }
    else {
        $object = $class->package->new(guid => $data->{guid});
    }
    while (my ($attr_name, $value) = each %$data) {
        # XXX for the time being, I need to assign directly instead of using
        # mutators.  Trying to use them results in "wide character in print" when
        # I am dealing with objects (State, DateTime, etc.)
        #$object->{$attr} = $value;
        if (my $attr = $class->attributes($attr_name)) {
            $attr->bake($object,$value);
        }
    }
    return $object;
}

##############################################################################

=head3 update_from_xml

 my $object = Kinetic::XML->update_from_xml($xml);

Loads the data in an XML representation of the Kinetic business object in
order to update its values.

=cut

sub update_from_xml {
    my ($class, $xml) = @_;
    return $class->new_from_xml($xml, {update => 1});
}

##############################################################################

=head3 write_xml

  $self->write_xml(file   => $file_name, %params);
  $self->write_xml(handle => $file_handle, %params);

Writes the XML representation of the Kinetic object to the specified file or
file handle. Accepts the same parameters as C<dump_xml()>. The XML output is
the same as would be returned by C<dump_xml()>.  A file handle is simply any
kind of object with a C<print()> method, but be sure to expect output decoded
to Perl's internal C<utf8> string format to be output the file handle.

B<Throws:>

=over 4

=item Exception::Fatal::IO

=back

=cut

sub write_xml {
    my $self   = shift;
    my %params = @_;
    my $fh = delete $params{handle} || do {
        my $file = delete $params{file};
        IO::File->new($file, ">:utf8")
          or throw_io ['Cannot open file "[_1]": [_2]', $file, $!];
    };
    $fh->print($self->dump_xml(%params));
    $fh->close;
    return $self;
}

##############################################################################

=head3 dump_xml

  my $xml = $xml->dump_xml([%params]);

Returns an XML representation of the object.  If called in list context, 
it returns a list of all XML sections produced (if more than one).  Otherwise,
it joins the XML sections with an empty string and returns them together.

Multiple XML sections might be obtained if C<with_contained> is false.

=over 4

=item with_contained

If passed a true value, any contained Kinetic objects will be serialized
within the XML for the main object. If it is false (the default), then
contained objects will merely be referenced by GUID and name.

=item with_collections

If passed a true value, then collections of contained Kinetic objects will be
serialized within the XML for the main object. If it is false (the default),
then contained objects will merely be referenced by GUID and name.

=back
=cut

my @OBJECTS;
sub dump_xml {
    my $self   = shift;
    my %params = @_;
    my $object = $self->object;
    push @OBJECTS => $object;
    local $self->{params} = \%params;
    my $xml    = XML::Genx::Simple->new;
    eval {
        $xml->StartDocString;
        $xml->StartElementLiteral('kinetic');
        $xml->AddAttributeLiteral(version => XML_VERSION);
        while (my $object = shift @OBJECTS) {
            $self->_add_object_to_xml($xml, $object);
        }
        $xml->EndElement;
        $xml->EndDocument;
    };
    throw_xml ["Writing XML failed: [_1]", $@] if $@;
    return $xml->GetDocString;
}

sub _add_object_to_xml {
    my ($self, $xml, $object) = @_;
    $xml->StartElementLiteral($object->my_class->key);
    $xml->AddAttributeLiteral(guid => $object->guid);

    foreach my $attr ($object->my_class->attributes) {
        my $name = $attr->name;
        next if 'guid' eq $name;
        if ($attr->references) {
            my $object = $attr->get($object);
            if (exists $self->{params}{with_contained} && ! $self->{params}{with_contained}) {
                # just guid
                my $name = $object->my_class->key;
                $xml->StartElementLiteral('',$name);
                $xml->AddAttributeLiteral('', guid => $object->guid);
                $xml->AddAttributeLiteral('', relative => 1);
                $xml->EndElement;
                push @OBJECTS => $object;
            } else {
                $self->_add_object_to_xml($xml, $object);
            }
        } else {
            $xml->Element( $name => ($attr->raw($object) || '') );
        }
    }
    $xml->EndElement;
}

##############################################################################

=head3 object

  $xml->object($object);
  my $same_object = $xml->object;

This getter/setter allows you to set or retrieve a Kinetic object for XML
serialization/deserialization.  This caches the object, so the reference count
is increased.

=cut

sub object {
    my $self = shift;
    if (@_) {
        my $object = shift;
        unless (UNIVERSAL::isa($object, 'Kinetic')) {
            throw_invalid_class [
                'Argument "[_1]" is not a valid [_2] object',
                1,
                'Kinetic'
            ];
        }
        $self->{object} = $object;
        return $self;
    }
    return $self->{object};
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2005 Kineticode, Inc. <info@kineticode.com>

This work is made available under the terms of Version 2 of the GNU General
Public License. You should have received a copy of the GNU General Public
License along with this program; if not, download it from
L<http://www.gnu.org/licenses/gpl.txt> or write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

This work is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See the GNU General Public License Version 2 for more
details.

=cut
