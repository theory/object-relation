package Kinetic::Meta::Class;

# $Id$

use strict;
use base 'Class::Meta::Class';
use Kinetic::Util::Context;

=head1 Name

Kinetic::Meta::Class - Kinetic class metadata class.

=head1 Synopsis

  my $class = MyThingy->my_class;
  my $thingy = MyThingy->new;

  print "Examining object of ", ($class->abstract ? "abstract " : ''),
    "class ", $class->package, $/;

  print "\nConstructors:\n";
  for my $ctor ($class->constructors) {
      print "  o ", $ctor->name, $/;
  }

  print "\nAttributes:\n";
  for my $attr ($class->attributes) {
      print "  o ", $attr->name, " => ", $attr->get($thingy) $/;
  }

  print "\nMethods:\n";
  for my $meth ($class->methods) {
      print "  o ", $meth->name, $/;
  }

=head1 Description

This class inherits from L<Class::Meta::Class|Class::Meta::Class> to provide
class metadata for Kinetic classes. See the L<Class::Meta|Class::Meta>
documentation for details on meta classes. See the L<"Accessor Methods"> for
the additional attributes.

=cut

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Accessor Methods

=head3 name

  my $name = $class->name;

Returns the localized form of the name of the class, such as "Thingy".

=cut

sub name {
    Kinetic::Util::Context->language->maketext(shift->SUPER::name);
}

##############################################################################

=head3 plural_name

  my $plural_name = $class->plural_name;

Returns the localized plural form of the name of the class, such as
"Thingies".

=cut

sub plural_name {
    Kinetic::Util::Context->language->maketext(shift->{plural_name});
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
