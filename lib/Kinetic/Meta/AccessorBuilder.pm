package Kinetic::Meta::AccessorBuilder;

# $Id$

use strict;
use Kinetic::Exceptions qw(throw_invalid throw_read_only);
use Class::Meta;

=head1 Name

Kinetic::Meta::AccessorBuilder - Builds Kinetic attribute accessors

=head1 Description

This module handles the creation of attributes for Kinetic classes. It never
be used directly. Consult L<Kinetic|Kinetic> and
L<Class::Meta|Class::Meta> for details on creating new Kinetic classes with
attributes of the types defined by this module.

=cut

##############################################################################

=head1 Interface

=head2 Functions

=head3 build_attr_get

  my $code = build_attr_get($attribute);

This method returns a code reference that, when passed a Kinetic object,
will return the value of an attribute. The attribute for which the value will
be returned is the attribute passed in to C<build_attr_get()>. See the
Class::Meta documentation for more information.

=cut

sub build_attr_get {
    UNIVERSAL::can($_[0]->package, $_[0]->name);
}

##############################################################################

=head3 build_attr_set

  my $code = build_attr_set($attribute);

This method returns a code reference that, when passed a Kinetic object and
a value, will set an attribute of the object with the new value. The attribute
for which the value will be set is the attribute passed in to
C<build_attr_set()>. See the Class::Meta documentation for more information.

=cut

*build_attr_set = \&build_attr_get;

##############################################################################

my $req_chk = sub {
    throw_invalid('Attribute must be defined') unless defined $_[0];
};

##############################################################################

=head3 build

  build($class, $attribute, $create, @checks);

This function builds the accessor or accessors for an attribute for a
Kinetic class. For most attributes, a single accessor will be created with
the same name as the attribute itself.

=cut

sub build {
    my ($pkg, $attr, $create, @checks) = @_;
    unshift @checks, $req_chk if $attr->required;
    my $name = $attr->name;

    no strict 'refs';

    if ($attr->context == Class::Meta::CLASS) {
        # Create a class attribute! Create a closure.
        my $data = $attr->default;
        if ($create == Class::Meta::GET) {
            # Create GET accessor.
            *{"${pkg}::$name"} = sub {
                # XXX Turn off this error in certain modes?
                throw_read_only(['Cannot assign to read-only attribute "[_1]"',
                                 $name])
                  if @_ > 1;
                $data;
            };

        } else {
            # Create GETSET accessor(s).
            if (@checks) {
                *{"${pkg}::$name"} = sub {
                    my $pkg = shift;
                    return $data unless @_;
                    # Check the value passed in.
                    $_->($_[0]) for @checks;
                    # Assign the value.
                    $data = $_[0];
                };
            } else {
                *{"${pkg}::$name"} = sub {
                    my $self = shift;
                    return $data unless @_;
                    # Assign the value.
                    $data = shift;
                };
            }
        }
        return;
    }

    # If we get here, it's an object attribute.
    if ($create == Class::Meta::GET) {
        # Create GET accessor.
        *{"${pkg}::$name"} = sub {
            # XXX Turn off this error in certain modes?
            throw_read_only(['Cannot assign to read-only attribute "[_1]"',
                             $name])
              if @_ > 1;
            $_[0]->{$name};
        };

    } else {
        # Create GETSET accessor(s).
        if (@checks) {
            *{"${pkg}::$name"} = sub {
                my $self = shift;
                return $self->{$name} unless @_;
                # Check the value passed in.
                $_->($_[0]) for @checks;
                # Assign the value.
                return $self->{$name} = $_[0];
            };
        } else {
            *{"${pkg}::$name"} = sub {
                my $self = shift;
                return $self->{$name} unless @_;
                # Assign the value.
                return $self->{$name} = shift;
            };
        }
    }
}

1;
__END__

##############################################################################

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item <LKinetic::Meta::DataTypes|Kinetic::Meta::DataTypes>

This module defines the data types used for Kinetic object attributes.

=item L<Class::Meta|Class::Meta>

This module provides the interface for the Kinetic class automation and
introspection defined here.

=item L<Kinetic::Base|Kinetic::Base>

The Kinetic base class. All Kinetic classes that store data in the data store
inherit from this class.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

