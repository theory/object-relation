package Kinetic::Meta::Attribute;

# $Id$

use strict;
use base 'Class::Meta::Attribute';
use Kinetic::Context;
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

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Accessor Methods

=head3 label

  my $label = $class->label;

Returns the localized form of the label for the attribute, such as "Name".

=cut

sub label {
    Kinetic::Context->language->maketext(shift->SUPER::label);
}

##############################################################################

=head3 widget_meta

  my $wm = $attr->widget_meta;

Returns a L<Widget::Meta|Widget::Meta> object describing the type of widget to
be used to allow input for an attribute. If no widget is provided, then no
field is required.

=cut

sub widget_meta { shift->{widget_meta} }

1;
__END__

##############################################################################

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item L<Kinetic::Base|Kinetic::Base>

The Kinetic base class.

=item L<Kinetic::Meta|Kinetic::Meta>

The class for Kinetic class automation, introspection, and data validation.

=item L<Kinetic::Meta::Class|Kinetic::Meta::Class>

Kinetic class introspection.

=item L<Widget::Meta|Widget::Meta>

Metadata for user interface widgets.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
