package Kinetic::Meta::AccessorBuilder;

# $Id$

use strict;
use Kinetic::Util::Exceptions qw(throw_invalid throw_read_only);
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

my $thaw = sub {
    $_[0] =~ m/^(\d\d\d\d).(\d\d).(\d\d).(\d\d).(\d\d).(\d\d)(\.\d*)?/;
    return Kinetic::DateTime->new(
        year       => $1,
        month      => $2,
        day        => $3,
        hour       => $4,
        minute     => $5,
        second     => $6,
        nanosecond => $7 ? $7 * 1.0E9 : 0
    );
};

my %builders = (
    default => {
        get => sub {
            my $name = shift;
            return sub {
                # XXX Turn off this error in certain modes?
                throw_read_only(['Cannot assign to read-only attribute "[_1]"',
                                 $name])
                  if @_ > 1;
                $_[0]->{$name};
            };
        },
        getset => sub {
            my ($name, @checks) = @_;
            return sub {
                my $self = shift;
                return $self->{$name} unless @_;
                # Assign the value.
                $self->{$name} = shift;
                return $self;
            } unless @checks;
            return sub {
                my $self = shift;
                return $self->{$name} unless @_;
                # Check the value passed in.
                $_->($_[0]) for @checks;
                # Assign the value.
                $self->{$name} = $_[0];
                return $self;
            };
        },
    },
    state => {
        # State is always get/set.
        getset => sub {
            my ($name, @checks) = @_;
            return sub {
                my $self = shift;
                unless (@_) {
                    return ref $self->{$name}
                      ? $self->{$name}
                      : $self->{$name} = Kinetic::Util::State->new($self->{$name})
                }
                # Check the value passed in.
                $_->($_[0]) for @checks;
                # Assign the value.
                $self->{$name} = shift;
                return $self;
            };
        },
    },
    datetime => {
        get => sub {
            my $name = shift;
            return sub {
                # XXX Turn off this error in certain modes?
                throw_read_only(['Cannot assign to read-only attribute "[_1]"',
                                 $name])
                  if @_ > 1;
                # Do we need to inflate the DateTime object?
                $_[0]->{$name} = $thaw->($_[0]->{$name})
                  if $_[0]->{$name} and not ref $_[0]->{$name};
                return $_[0]->{$name};
            };
        },
        getset => sub {
            my ($name, @checks) = @_;
            return sub {
                my $self = shift;
                unless (@_) {
                    # Do we need to inflate the DateTime object?
                    $self->{$name} = $thaw->($self->{$name})
                      if $self->{$name} and not ref $self->{$name};
                    return $self->{$name};
                }
                # Check the value passed in.
                $_->($_[0]) for @checks;
                # Assign the value.
                $self->{$name} = shift;
                return $self;
            };
        },
    }
);

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
    my $builder = $builders{$attr->type} || $builders{default};
    if ($create == Class::Meta::GET) {
        # Create GET accessor.
        *{"${pkg}::$name"} = $builder->{get}->($name);
    } else {
        # Create GETSET accessor(s).
        *{"${pkg}::$name"} = $builder->{getset}->($name, @checks);
    }
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
