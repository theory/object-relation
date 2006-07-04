package Kinetic::Meta::Widget;

# $Id$

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

use version;
our $VERSION = version->new('0.0.2');

use base 'Widget::Meta';
use Kinetic::Util::Context;

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
    Kinetic::Util::Context->language->maketext(shift->SUPER::tip);
}

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

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
