package Kinetic::Meta::XML;

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
use constant XML_VERSION => '0.01';

=head1 Name

Kinetic::Meta::XML - The Kinetic::Meta::Class XML serialization class

=head1 Synopsis

  use Kinetic::Meta::XML;

=head1 Description

This class is used for serializing and deserializing Kinetic::Meta::Class
objects to and and from XML.  New classes may be created or existing classes
may be updated using this class.

=cut

##############################################################################
# Constructors
##############################################################################

=head2 Constructors

=head3 new

  my $xml = Kinetic::Meta::XML->new;

Creates and returns a new xml object.

=cut

sub new {
    my ($class, $kinetic_class) = @_;
    my $self = bless {}, $class;
    return $self unless $kinetic_class;
    $self->class($kinetic_class);
}

##############################################################################
# Class Methods
##############################################################################

=head2 Instance Methods

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

my @CLASSES;
sub dump_xml {
    my $self   = shift;
    my %params = @_;
    my $class = $self->class;
    push @CLASSES => $class;
    local $self->{params} = \%params;
    my $xml    = XML::Genx::Simple->new;
    eval {
        $xml->StartDocString;
        $xml->StartElementLiteral('kinetic');
        $xml->AddAttributeLiteral(version => XML_VERSION);
        while (my $class = shift @CLASSES) {
            $self->_add_class_to_xml($xml, $class);
        }
        $xml->EndElement;
        $xml->EndDocument;
    };
    throw_xml ["Writing XML failed: [_1]", $@] if $@;
    return $xml->GetDocString;
}

my %attributes = (
    class    => [qw/
        package
        name
        plural_name
        desc
        abstract
        is_a
    /],
    multiple => {
        order  => [qw/
            constructors
            attributes
        /],
        lookup => {
            constructors => {
                label => 'constructor',
                attributes => [qw/name/],
            },
            attributes => {
                label  => 'attribute',
                attributes => [qw/
                    name
                    label
                    type
                    required
                    unique
                    once
                    default
                    relationship
                    authz
                    widget_meta
                /],
            },
        },
    },
    contained => {
        widget_meta => [qw/type tip/],
    },
);

sub _add_class_to_xml {
    my ($self, $xml, $class) = @_;
    $xml->StartElementLiteral('', 'class');
    $xml->AddAttributeLiteral(key => $class->key);
    # XXX this is temporary (?)
    local $^W;
    foreach my $attribute (@{$attributes{class}}) {
        $xml->Element( $attribute => ($class->$attribute || '') );
    }
    foreach my $multiple (@{$attributes{multiple}{order}}) {
        $xml->StartElementLiteral($multiple);
        my ($label, $attributes) 
            = @{$attributes{multiple}{lookup}{$multiple}}{qw/label attributes/};
        foreach my $thing ($class->$multiple) {
            $xml->StartElementLiteral($label);
            my $attr_object = $class->attributes($thing->name);
            foreach my $attribute (@$attributes) {
                if (my $contained_attrs = $attributes{contained}{$attribute}) {
                    if (my $contained = $attr_object->$attribute) {
                        $xml->StartElementLiteral($attribute);
                        foreach my $c_attr (@$contained_attrs) {
                            $xml->Element($c_attr => $contained->$c_attr);
                        }
                        $xml->EndElement;
                    }
                }
                else {
                    $xml->Element($attribute => ($thing->$attribute || '')); 
                }
            }
            $xml->EndElement;
        }
        $xml->EndElement;
    }
    $xml->EndElement;
}

##############################################################################

=head3 class

  $xml->class($class);
  my $same_class = $xml->class;

This getter/setter allows you to set or retrieve a Kinetic class object for XML
serialization/deserialization.  This caches the class, so the reference count
is increased.

=cut

sub class {
    my $self = shift;
    if (@_) {
        my $class = shift;
        unless (UNIVERSAL::isa($class, 'Kinetic::Meta::Class')) {
            throw_invalid_class [
                'Argument "[_1]" is not a valid [_2] class',
                1,
                'Kinetic'
            ];
        }
        $self->{class} = $class;
        return $self;
    }
    return $self->{class};
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
