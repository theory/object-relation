package Kinetic::Meta::Attribute;

# $Id$

use strict;
use base 'Class::Meta::Attribute';
use Kinetic::Util::Context;
use Widget::Meta;

=head1 Name

Kinetic::Meta::Attribute - Kinetic object attribute introspection

=head1 Synopsis

  # Assuming MyThingy was generated by Kinetic::Meta.
  my $class = MyThingy->my_class;
  my $thingy = MyThingy->new;

  print "\nAttributes:\n";
  for my $attr ($class->attributes) {
      print "  o ", $attr->name, " => ", $attr->get($thingy), $/;
      if ($attr->authz >= Class::Meta::SET && $attr->type eq 'string') {
          $attr->get($thingy, 'hey there!');
          print "    Changed to: ", $attr->get($thingy) $/;
      }
  }

=head1 Description

This class inherits from L<Class::Meta::Attribute|Class::Meta::Attribute> to
provide attribute metadata for Kinetic classes. See the
L<Class::Meta|Class:Meta> documentation for details on meta classes. See the
L<"Instance Interface"> section for the attributes added to
Kinetic::Meta::Attribute in addition to those defined by
Class::Meta::Attribute.

=cut

sub new {
    my $self = shift->SUPER::new(@_);
    $self->{indexed} ||= $self->{unique};
    return $self;
}

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Accessor Methods

=head3 label

  my $label = $attr->label;

Returns the localized form of the label for the attribute, such as "Name".

=cut

sub label {
    Kinetic::Util::Context->language->maketext(shift->SUPER::label);
}

##############################################################################

=head3 widget_meta

  my $wm = $attr->widget_meta;

Returns a L<Widget::Meta|Widget::Meta> object describing the type of widget to
be used to allow input for an attribute. If no widget is provided, then no
field is required.

=cut

sub widget_meta { shift->{widget_meta} }

##############################################################################

=head3 unique

  my $unique = $attr->unique;

Returns true if an attribute is unique across all objects of a class.

=cut

sub unique { shift->{unique} }

##############################################################################

=head3 indexed

  my $indexed = $attr->indexed;

Returns true if an attribute is indexed in the data store, and false if it is
not. Note that this is a suggestion only, since not all data stores
necessarily support indexes. Always returns a true value if the C<unique>
attribute is set to a true value.

=cut

sub indexed { shift->{indexed} }

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. <info@kineticode.com>

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
