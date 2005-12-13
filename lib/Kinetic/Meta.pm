package Kinetic::Meta;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.1');

use base 'Class::Meta';
use Kinetic::Meta::DataTypes;
use Kinetic::Meta::Attribute;
use Kinetic::Meta::Class;
use Kinetic::Util::Exceptions qw(throw_exlib throw_invalid_class);
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

=head1 Dynamic APIs

This class supports the dynamic loading of extra methods specifically designed
to be used with particular Kinetic data store implementations. This is so that
the store APIs can easily dispatch to attribute objects, class objects, and
data types to get data-store specific metadata without having to do extra work
themselves. Data store implementors needing store-specific metadata methods
should add them as necessary to the C<import()> methods of
L<Kinetic::Meta::Class|Kinetic::Meta::Class>,
L<Kinetic::Meta::Attribute|Kinetic::Meta::Attribute>, and/or/
L<Kinetic::Meta::Type|Kinetic::Meta::Type>

In general, however, Kinetic users will not need to worry about loading
data-store specific APIs, as the data stores will load them themselves. And
since the methods should either be protected or otherwise transparent, no one
else should use them, anyway.

As of this writing, only a single data-store specific API label is supported:

  use Kinetic::Meta ':with_dbstore_api';

More may be added in the future.

=cut

sub import {
    my ($pkg, $api_label) = @_;
    return unless $api_label;
    $_->import($api_label) for qw(
        Kinetic::Meta::Class
        Kinetic::Meta::Attribute
        Kinetic::Meta::Type
    );
}

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

In addition to the parameters supported by C<< Class::Meta->new >>,
C<< Kinetic::Meta->new >> supports these extra attributes:

=over

=item sort_by

This attribute is the name of an attribute or array reference of names of the
attributes to use when sorting a list of objects of the class. If
C<sort_order> is not specified, it defaults to the first attribute declared
after the C<uuid> and C<state> attributes.

=item extends

This attribute specifies a single Kinetic class name that the class extends.
Extension is similar to inheritance, only extended class objects have their
own UUIDs and states, and there can be multiple extending objects for a single
extended objecct (think one person acting as several users).

=back

=cut

__PACKAGE__->default_error_handler(\&throw_exlib);

sub new {
    my $pkg  = shift;
    my $self = $pkg->SUPER::new(
        # We must specify the package
        package         => scalar caller,
        @_,
        class_class     => $pkg->class_class,
        attribute_class => $pkg->attribute_class,
    );

    my $class   = $self->class;
    my $extend  = $class->extends or return $self;
    my $package = $class->package;

    my %attrs = map { $_->name => undef } $class->attributes;

    # Turn keys into class objects.
    my $key     = $extend->key;
    my $ext_pkg = $extend->package;

    # Make sure that we're not using inheritance!
    throw_invalid_class [
        'I cannot extend [_1] into [_2] because [_2] inherits from [_1]',
        $ext_pkg,
        $class,
    ] if $package->isa($ext_pkg);

    # Add an attribute for the extended object.
    $self->add_attribute(
                name => $key,
                type => $key,
            required => 1,
                once => 1,
               label => $extend->{name},
                view => Class::Meta::TRUSTED,
              create => Class::Meta::NONE,
             default => sub { $ext_pkg->new },
        relationship => 'extends',
    );

    # Add attributes from the extended class.
    for my $attr ($extend->attributes) {
        my $name = $attr->name;
        my $attr_name = exists $attrs{$name} ? "$key\_$name" : $name;
        # I need Attribute objects on the Attribute object!
        $self->add_attribute(
                    name => $attr_name,
                    type => $attr->type,
                required => $attr->required,
                    once => $attr->once,
                   label => $attr->{label},
                    desc => $attr->desc,
                    view => $attr->view,
                   authz => $attr->authz,
                  create => Class::Meta::NONE,
                 context => $attr->context,
                 default => $attr->default,
             widget_meta => $attr->widget_meta,
                  unique => $attr->unique,
                distinct => $attr->distinct,
                 indexed => $attr->indexed,
              persistent => $attr->persistent,
            delegates_to => $extend,
                 acts_as => $attr,
        );
        # Set up the delegation method.
        no strict 'refs';
        *{"$package\::$attr_name"} = eval qq{
            sub { shift->{$key}->$name(\@_) }
        };
    }

    # Set up the accessor for the extended object.
    no strict 'refs';
    *{"$package\::$key"} = eval qq{ sub { shift->{$key} } };

    return $self;
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

##############################################################################

=head2 Class Methods

=head3 for_key

  my $class = Kinetic::Meta->for_key($key);

This method overrides the implementation inherited from
L<Class::Meta|Class::Meta> to throw an exception no class object exists for
the key passed as its sole argument. To use C<for_key()> without getting an
exception, call C<< Class::Meta->for_key() >>, instead.

=cut

sub for_key {
    my ($pkg, $key) = @_;
    if (my $class = $pkg->SUPER::for_key($key)) {
        return $class;
    }
    throw_invalid_class [
        'I could not find the class for key "[_1]"',
        $key
    ];
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
