package Kinetic::Meta::Widget;

# $Id$

use strict;
use base 'Widget::Meta';
use Kinetic::Context;

=head1 Name

Kinetic::Meta::Wiget - Kinetic object attribute widget specifications

=head1 Synopsis

  # Assuming Kinetic::Thingy was generated by Kinetic::Meta.
  my $class = Kinetic::Thingy->my_class;

  for my $attr ($class->attributes) {
      my $wm = $attr->widget_meta;
      if ($wm->kind eq 'text') {
          output_text_field($wm);
      } elsif ($wm->kind eq 'select') {
          output_select_list($wm);
      } else {
          die "Huh, wha?";
      }
  }

=head1 Description

This class inherits from L<Widget::Meta|Widget::Meta> to provide widget
metadata for Kinetic class attributes. See the L<Widget::Meta|Widget:Meta>
documentation for details on widget metadata. See the L<"Instance Interface">
for the attributes added to Kinetic::Meta::Widget in addition to those
defined by Widget::Meta.

=cut

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Accessor Methods

=head3 tip

  my $tip = $class->tip;

Returns the localized form of the tip for the widget, such as "Name of this
object".

=cut

sub tip {
    Kinetic::Context->language->maketext(shift->SUPER::tip);
}

1;
__END__

##############################################################################

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item L<Kinetic::Meta|Kinetic::Meta>

The class for Kinetic class automation, introspection, and data validation.

=item L<Kinetic::Meta::Class|Kinetic::Meta::Class>

Kinetic class introspection.

=item L<Kinetic::Meta::Attribute|Kinetic::Meta::Attribute>

Kinetic attribute introspection.

=item L<Widget::Meta|Widget::Meta>

Metadata for user interface widgets.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This Library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
