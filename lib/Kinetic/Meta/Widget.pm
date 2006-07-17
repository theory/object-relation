package Kinetic::Meta::Widget;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.2');

use base 'Widget::Meta';
use aliased 'Kinetic::Util::Language';

=head1 Name

Kinetic::Meta::Wiget - Kinetic object attribute widget specifications

=head1 Synopsis

  # Assuming Kinetic::Thingy was generated by Kinetic::Meta.
  my $class = Kinetic::Thingy->my_class;

  for my $attr ($class->attributes) {
      my $wm = $attr->widget_meta;
      if ($wm->type eq 'text') {
          output_text_field($wm);
      } elsif ($wm->type eq 'select') {
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
    Language->get_handle->maketext( shift->SUPER::tip );
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
