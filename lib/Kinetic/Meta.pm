package Kinetic::Meta;

# $Id$

use strict;
use base 'Class::Meta';
use Kinetic::Meta::DataTypes;
use Kinetic::Meta::Attribute;
use Kinetic::Meta::Class;
use Kinetic::Util::Exceptions qw(throw_exlib);
use Class::Meta::Types::String; # Move to DataTypes.

=head1 Name

Kinetic::Meta - Kinetic class automation, introspection, and data validation

=head1 Synopsis

  package MyThingy;

  use strict;
  use base 'Kinetic::Base';

  BEGIN {
      my $cm = Kinetic::Meta->new(
        key         => 'thingy',
        name        => 'Thingy',
        plural_name => 'Thingies',
      );
      $cm->build;
  }

=head1 Description

This class inherits from L<Class::Meta|Class::Meta> to provide class
automation, introspection, and data validation for Kinetic classes. It
overrides the behavior of Class::Meta to specify the use of the
L<Kinetic::Meta::Class|Kinetic::Meta::Class> subclass in place of
Class::Meta::Class.

=cut

##############################################################################
# Constructors.
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

  my $cm = Kinetic::Meta->new(%init);

Overrides the parent Class::Meta constructor in order to specify that the
class class be Kinetic::Meta::Class and that the attribute class be
Kinetic::Meta::Attribute.

=cut

__PACKAGE__->default_error_handler(\&throw_exlib);

sub new {
    my $pkg = shift;
    $pkg->SUPER::new(
        # We must specify the package
        package         => scalar caller,
        @_,
        class_class     => $pkg->class_class,
        attribute_class => $pkg->attribute_class,
    );
}

##############################################################################

=head2 Class Attributes

=head3 class_class

  my $class_class = Kinetic::Meta->class_class;
  Kinetic::Meta->class_class($class_class);

The subclass or Class::Meta::Class that will be used to represent class
objects. The value of this class attribute is only used at startup time when
classes are loaded, so if you want to change it form the default, which is
"Kinetic::Meta::Class", do it before you load any Kinetic classes.

=cut

my $class_class = 'Kinetic::Meta::Class';

sub class_class {
    shift;
    return $class_class unless @_;
    $class_class = shift;
}

##############################################################################

=head3 attribute_class

  my $attribute_class = Kinetic::Meta->attribute_class;
  Kinetic::Meta->attribute_class($attribute_class);

The subclass or Class::Meta::attribue that will be used to represent attribute
objects. The value of this class attribute is only used at startup time when
classes are loaded, so if you want to change it form the default, which is
"Kinetic::Meta::Attribute", do it before you load any Kinetic classes.

=cut

my $attribute_class = 'Kinetic::Meta::Attribute';

sub attribute_class {
    shift;
    return $attribute_class unless @_;
    $attribute_class = shift;
}

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
