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
use aliased 'XML::Genx::Simple' => 'XML';

=head1 Name

Kinetic::XML - The Kinetic xml serialization class

=head1 Synopsis

  use Kinetic::XML;

=head1 Description

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

  my $xml = Kinetic::XML->new;

Creates and returns a new xml object.

=cut

sub new {
    my ($class, $object) = @_;
    my $self = bless {}, $class;
    return $self unless $object;
    unless (UNIVERSAL::isa($object, 'Kinetic')) {
        require Carp;
        Carp::croak "The object supplied must be a Kinetic object or subclass";
    }
    $self->object($object);
}

##############################################################################
# Class Methods
##############################################################################

=head2 Instance Methods

##############################################################################

=head3 new_from_xml

Loads the data in an XML representation of the Kinetic business object as a
new object.

##############################################################################

=head3 write_xml

  $self->write_xml(file   => $file_name, %params);
  $self->write_xml(handle => $file_handle, %params);

Writes the XML representation of the Kinetic object to the specified file or
file handle. Accepts the same parameters as C<dump_xml()>. The XML output is
the same as would be returned by C<dump_xml()>, but will be streamed to the
file handle, potentially making the output more efficient. A file handle is
simply any kind of object with a C<print()> method, but be sure to expect
output decoded to Perl's internal C<utf8> string format to be output the file
handle.

B<Throws:>

=over 4

=item Exception::Fatal::IO

=back

=cut

sub write_xml {
    my $self = shift;
    my %params = @_;
    my $fh = delete $params{handle} || do {
        my $file = delete $params{file};
        #IO::File->new($file, ">:utf8")
        #  or throw_io ['Cannot open file "[_1]": [_2]', $file, $!];
    };
    $self->_write_xml(_xml_writer($fh), \%params);
    $fh->close;
    return $self;
}

##############################################################################

=head3 dump_xml

  my $xml = $xml->dump_xml;

Dumps an XML representation of the object.

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

sub dump_xml {
    my $self   = shift;
    my $xml    = XML::Genx::Simple->new;
    my $object = $self->object;
    eval {
        $xml->StartDocString;
        $self->_add_object_to_xml($xml, $object);
        $xml->EndDocument;
    };
    die "Writing XML failed: $@" if $@;
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
            $self->_add_object_to_xml($xml, $attr->get($object));
        }
        else {
            $xml->Element( $name => $object->$name );
        }
    }
    $xml->EndElement;
}

##############################################################################

=head3 update_from_xml

Loads the data in an XML representation of the Kinetic business object in
order to update its values.

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
            require Carp;
            Carp::croak "The object supplied must be a Kinetic object or subclass";
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
