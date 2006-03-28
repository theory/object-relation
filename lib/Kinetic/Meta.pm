package Kinetic::Meta;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.1');

use base 'Class::Meta';
use Kinetic::Meta::DataTypes;
use Kinetic::Meta::Attribute;
use Kinetic::Meta::Class;
use Kinetic::Meta::Method;
use Kinetic::Util::Exceptions qw(
    throw_exlib
    throw_invalid_class
    throw_invalid_attr
);
use Class::Meta::Types::String;    # Move to DataTypes.

use Readonly;
Readonly my $BASE_CLASS => 'Kinetic';

=head1 Name

Kinetic::Meta - Kinetic class automation, introspection, and data validation

=head1 Synopsis

  package MyThingy;

  use strict;

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

Any class created with L<Kinetic::Meta|Kinetic::Meta> will automatically have
L<Kinetic|Kinetic> pushed onto its C<@ISA> array unless it already inherits
from L<Kinetic|Kinetic>.

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
    my ( $pkg, $api_label ) = @_;
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
attributes to use when sorting a list of objects of the class. If C<sort_by>
is not specified, it defaults to the first attribute declared after the
C<uuid> and C<state> attributes.

=item extends

This attribute specifies a single Kinetic class name that the class extends.
Extension is similar to inheritance, only extended class objects have their
own UUIDs and states, and there can be multiple extending objects for a single
extended object (think one person acting as several users).

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
        method_class    => $pkg->method_class,
    );

    my $class    = $self->class;
    my $package  = $class->package;
    my $extended = $class->extends;
    my $mediated = $class->mediates;

    unless ( $BASE_CLASS eq $package ) { # no circular inheritance
        unless ( $package->isa($BASE_CLASS) ) {
            # force packages to inherit from Kinetic
            # XXX unfortunately, there's some deep magic in "use base" which
            # causes the simple "push @ISA" to fail.
            #no strict 'refs';
            #push @{"$package\::ISA"}, $BASE_CLASS;
            eval <<"            ADD_BASE_CLASS";
            package $package;
            use base '$BASE_CLASS';
            ADD_BASE_CLASS
            if ( my $error = $@ ) {
                # This should never happen ...
                # If it does, there's a good chance you're in the wrong
                # directory and the config file can't be found.
                throw_invalid_class [
                    'I could not load the class "[_1]": [_2]',
                    $BASE_CLASS,
                    $error,
                ];
            }
        }
    }

    if ($extended and $mediated) {
        throw_invalid_class [
            '[_1] can either extend or mediate another class, but not both',
            $class->package,
        ];
    }

    # Set up attributes if this class extends another class.
    elsif ($extended) {
        my $ext_pkg = $extended->package;

        # Make sure that we're not using inheritance!
        throw_invalid_class [
            '[_1] cannot extend [_2] because it inherits from it',
            $package,
            $ext_pkg,
        ] if $package->isa($ext_pkg);

        $self->_add_delegates(
            $extended,
            'extends',
            1,
            sub { $extended->package->new },
            $class->type_of,
        );
    }

    # Set up attributes if this class mediates another class.
    elsif ($mediated) {
        $self->_add_delegates(
            $mediated,
            'mediates',
            1,
            sub { $mediated->package->new }
        );
    }

    # Set up attributes if this class is a type of another class.
    if (my $type = $class->type_of) {
        $self->_add_delegates($type, 'type_of', 0);
    }

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

The subclass or Class::Meta::Attribute that will be used to represent attribute
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

=head3 method_class

  my $method_class = Kinetic::Meta->method_class;
  Kinetic::Meta->method_class($method_class);

The subclass or Class::Meta::Method that will be used to represent method
objects. The value of this class method is only used at startup time when
classes are loaded, so if you want to change it form the default, which is
"Kinetic::Meta::Method", do it before you load any Kinetic classes.

=cut

my $method_class = 'Kinetic::Meta::Method';

sub method_class {
    shift;
    return $method_class unless @_;
    $method_class = shift;
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

##############################################################################

=head3 attr_for_key

  my $attribute = Kinetic::Meta->attr_for_key('foo.bar');

This method returns a L<Kinetic::Meta::Attribute|Kinetic::Meta::Attribute>
object for a given class key and attribute. The class key and attribute name
are separated by a dot (".") in the argument. In this above example, the
attribute "bar" would be returned for the class with the key "foo".

=cut

sub attr_for_key {
    my $pkg = shift;
    my ($key, $attr_name) = split /\./ => shift;
    if (my $attr = $pkg->for_key($key)->attributes($attr_name)) {
        return $attr;
    }
    throw_invalid_attr [
        'I could not find the attribute "[_1]" in class "[_2]"',
        $attr_name,
        $key,
    ];
}

##############################################################################

=begin private

=head1 Private Interface

=head2 Private Instance Methods

=head3 _add_delegates

  $km->_add_delegates($ref, $rel, $persist, $default);

This method is called by C<new()> to add delegating attributes to a
Kinetic::Meta::Class that extends, mediates, or is a type of another class.
The arguments are as follows:

=over

=item 1 $ref

The first argument is a Kinetic::Meta::Class object representing the class
that the current class references for the relationship.

=item 2 $rel

The second argument is a string denoting the type of relationship, one of
"extends", "mediates", or "type_of".

=item 3 $persist

A boolean value indicating whether the attributes should be persistent or not.
Only "type_of" attributes should not be persistent.

=item 4 $default

The default value for the attribute, if any.

=back

=cut

sub _add_delegates {
    my ($self, $ref, $rel, $persist, $def, @others) = @_;
    my $class = $self->class;
    my $key   = $ref->key;

    # Add attribute for the object.
    $self->add_attribute(
                name => $key,
                type => $key,
            required => 1,
               label => $ref->{label},
                view => Class::Meta::TRUSTED,
              create => Class::Meta::RDWR,
             default => $def,
        relationship => $rel,
        widget_meta  => Kinetic::Meta::Widget->new(
                type => 'search',
                tip  => $ref->{label},
        ),
    );

    # XXX Kinetic::Meta::Class::Schema->parents doesn't work because it
    # only returns non-abstract parents and, besides, doesn't figure out
    # what they are until build() is called.

    my $parent = ($class->Class::Meta::Class::parents)[0];

    # This isn't redundant because attributes can have been added to $class
    # only by _add_delegates(). It won't return any for the current class
    # until after build() is called, and since this is new(), the class itself
    # hasn't declared any yet!

    my %attrs = map { $_->name => undef }
        $class->attributes, $parent->attributes;

    # Disallow attributes with the same names as other important relations.
    $attrs{$_->key} = undef for grep { defined } @others;

    # Add attributes from the extended class.
    for my $attr ($ref->attributes) {
        my $name      = $attr->name;
        my $attr_name = exists $attrs{$name} ? "$key\_$name" : $name;

        # Create a new attribute that references the original attribute.
        $self->add_attribute(
            name         => $attr_name,
            type         => $attr->type,
            required     => $attr->required,
            once         => $attr->once,
            label        => $attr->{label},
            desc         => $attr->desc,
            view         => $attr->view,
            authz        => $attr->authz,
            create       => Class::Meta::NONE,
            context      => $attr->context,
            default      => $attr->default,
            widget_meta  => $attr->widget_meta,
            unique       => $attr->unique,
            distinct     => $attr->distinct,
            indexed      => $attr->indexed,
            persistent   => $attr->persistent && $persist,
            delegates_to => $ref,
            acts_as      => $attr,
        );
        # Delegation methods are created by Kinetic::Meta::AccessorBuilder.
    }

    if ($persist) {
        # Copy over the methods, too.
        my $pack = $class->package;
        my %meths = map { $_->name => undef }
            $class->methods, $parent->methods;

        for my $meth ($ref->methods) {
            my $name      = $meth->name;
            my $meth_name = exists $meths{$name} ? "$key\_$name" : $name;

            $self->add_method(
                name         => $meth_name,
                label        => $meth->{label},
                desc         => $meth->desc,
                view         => $meth->view,
                context      => $meth->context,
                args         => $meth->args,
                returns      => $meth->returns,
                delegates_to => $ref,
                acts_as      => $meth,
            );

            # Create the delegating method.
            no strict 'refs';
            *{"$pack\::$meth_name"} = eval qq{
                sub {
                    my \$o = shift->$key or return;
                    \$o->$name(\@_);
                }
            };
        }
    }

    return $self;
}

=end private

=cut

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
