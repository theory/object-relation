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
    shift->SUPER::new(
        # We must specify the package
        package         => scalar caller,
        @_,
        class_class     => 'Kinetic::Meta::Class',
        attribute_class => 'Kinetic::Meta::Attribute',
    );
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
