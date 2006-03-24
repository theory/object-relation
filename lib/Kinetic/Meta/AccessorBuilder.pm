package Kinetic::Meta::AccessorBuilder;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.0.1');

use aliased 'Kinetic::Store';
use aliased 'Kinetic::Util::Collection';

use Kinetic::Util::Exceptions qw(throw_invalid throw_read_only);
use Class::Meta;

=head1 Name

Kinetic::Meta::AccessorBuilder - Builds Kinetic attribute accessors

=head1 Description

This module handles the creation of attributes for Kinetic classes. It should
never be used directly. Consult L<Kinetic|Kinetic> and
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
    throw_invalid([ 'Attribute "[_1]" must be defined', $_[1] ])
        unless defined $_[0];
};

my $once_chk = sub {
    my ($new, $key, $obj) = @_;
    no warnings;
    throw_invalid([ 'Attribute "[_1]" can be set only once', $key ])
      if defined $obj->{$key} && $obj->{$key} ne $new && $obj->is_persistent;
};

##############################################################################

=head3 build

  build($class, $attribute, $create, @checks);

This function builds the accessor or accessors for an attribute for a
Kinetic class. For most attributes, a single accessor will be created with
the same name as the attribute itself.

=cut

my $collection_builder = sub {
    my ($attr, $name, @checks) = @_;
    (my $key = $attr->type) =~ s/^collection_//; # XXX :(
    my $store = Store->new;
    return sub {
        my $self = shift;
        if (@_) {
            $_->($_[0], $name, $self) for @checks;
            _set( $self, $name, shift );
        }
        else {
            return $self->{$name} ? $self->{$name}
                 : $self->uuid    ? $store->_get_collection( $self, $attr )
                 :                  Collection->empty;
        }
    };
};

my %builders = (
    default => {
        collection => $collection_builder,
        get => sub {
            my $name = shift;
            return sub {
                # Turn off this error in certain modes?
                throw_read_only(['Cannot assign to read-only attribute "[_1]"',
                                 $name])
                  if @_ > 1;
                $_[0]->{$name};
            };
        },
        getset => sub {
            my ($attr, $name, @checks) = @_;
            if ($attr->persistent) {
                return sub {
                    my $self = shift;
                    return $self->{$name} unless @_;
                    # Assign the value.
                    return _set($self, $name, shift);
                } unless @checks;
                return sub {
                    my $self = shift;
                    return $self->{$name} unless @_;
                    # Check the value passed in.
                    $_->($_[0], $name, $self) for @checks;
                    # Assign the value.
                    return _set($self, $name, $_[0]);
                };
            } else {
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
                    $_->($_[0], $name, $self) for @checks;
                    # Assign the value.
                    $self->{$name} = $_[0];
                    return $self;
                };
            }
        },
    },

    bake => {
        get => sub {
            my ($name, $bake) = @_;
            return sub {
                my $self = shift;
                # XXX Turn off this error in certain modes?
                throw_read_only(['Cannot assign to read-only attribute "[_1]"',
                                 $name])
                  if @_ > 1;
                # Do we need to inflate the object?
                $self->{$name} = $bake->($self->{$name})
                    if defined $self->{$name} and not ref $self->{$name};
                return $self->{$name};
            };
        },
        getset => sub {
            my ($attr, $name, $bake, @checks) = @_;
            if ($attr->persistent) {
                return sub {
                    my $self = shift;
                    $self->{$name} = $bake->($self->{$name})
                        if defined $self->{$name} && !ref $self->{$name};
                    return $self->{$name} unless @_;
                    # Check the value passed in.
                    $_->($_[0], $name, $self) for @checks;
                    # Assign the value.
                    return _set($self, $name, shift);
                };
            } else {
                return sub {
                    my $self = shift;
                    $self->{$name} = $bake->($self->{$name})
                        if defined $self->{$name} && !ref $self->{$name};
                    return $self->{$name} unless @_;
                    # Check the value passed in.
                    $_->($_[0], $name, $self) for @checks;
                    # Assign the value.
                    $self->{$name} = shift;
                    return $self;
                };
            }
        },
    },
);

sub build {
    my ($pkg, $attr, $create, @checks) = @_;
    unshift @checks, $req_chk if $attr->required;
    unshift @checks, $once_chk if $attr->once;
    my $name = $attr->name;

    no strict 'refs';

    if ($attr->context == Class::Meta::CLASS) {
        # Create a class attribute! Create a closure.
        my $data = $attr->default;
        if ($create == Class::Meta::GET) {
            # Create GET accessor.
            *{"${pkg}::$name"} = sub {
                # XXX Turn off this error in certain modes?
                throw_read_only([
                    'Cannot assign to read-only attribute "[_1]"',
                    $name,
                ]) if @_ > 1;
                $data;
            };

        } else {
            # Create GETSET accessor(s).
            if (@checks) {
                *{"${pkg}::$name"} = sub {
                    my $pkg = shift;
                    return $data unless @_;
                    # Check the value passed in.
                    $_->($_[0], $name, $pkg) for @checks;
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
    my $bake    = Kinetic::Meta::Type->new($attr->type)->bake;
    my $builder = $bake ? $builders{bake} : $builders{default};

    # Create any delegation methods.
    if (my $rel = $attr->relationship) {
        if ($rel eq 'type_of') {
            _delegate($pkg, $attr, Class::Meta::READ);
        } elsif ($rel eq 'extends' || $rel eq 'mediates') {
            _delegate($pkg, $attr, Class::Meta::RDWR);
        } elsif ($attr->collection_of) {
            *{"$pkg\::$name"} = $builder->{collection}->($attr, $name, @checks);
            return;
        }
    }

    if ($create == Class::Meta::GET) {
        # Create GET accessor.
        *{"${pkg}::$name"} = $builder->{get}->($name, $bake);
    } else {
        # Create GETSET accessor(s).
        unshift @checks, $bake if $bake;
        *{"${pkg}::$name"} = $builder->{getset}->($attr, $name, @checks);
    }
}

##############################################################################

=begin private

=head2 Private Functions

=head3 _delegate

  _delegate($pkg, $attr, $auth);

Creates methods in $pkg that delegate to all of the attribute accessors of the
object referenced by $attr. The $authz argument should be either
C<Class::Meta::READ> or C<Class::Meta::RDWR>. If the former, the delegation
methods will be read-only accessors. If the latter, they'll be both accessors
and mutators unless the attribute being delegated to has its C<authz>
attribute set to C<Class::Meta::READ>, in which case its delegation method
will also be read-only.

The generated methods will have the same names as the attributes they point to
in the delegated object, unless a method with such a name already exists. In
such a case, the method will be named for the attribute containing the
delegated object, plus an underscore, plus the name of the attribute. For
example, if the delegated object was stored in the attribute "user", and its
class had "name" and "login" attributes, and a method called "name" already
existed, then the accessor methods created would be called C<user_name()> and
C<login()>.

This function should only be called for attributes that reference other
objects and that need to have delegation methods to access the attributes of
the referenced object. See
L<Kinetic::Meta::Attribute|Kinetic::Meta::Attribute> for a list of supported
relationships and descriptions their delegation method requirements.

=cut

sub _delegate {
    my ($pkg, $attr, $authz) = @_;
    my $class   = $attr->class;
    my $ref     = $attr->references;
    my $aname   = $attr->name;

    # Meta.pm maps the delegating attribute to the attribute it acts as.
    my %attrs = map  { $_->acts_as => $_->name }
                grep { ($_->delegates_to || '') eq $ref } $class->attributes;

    for my $attr ($ref->attributes) {
        next unless $attr->authz >= Class::Meta::READ;
        my $name = $attr->name;
        # The delegatting attribute should tell us its name.
        my $meth = $attrs{$attr};
        no strict 'refs';
        *{"${pkg}::$meth"} = eval(
            $authz == Class::Meta::READ || $attr->authz == Class::Meta::READ
                ? qq{sub {
                    my \$o = shift->{$aname};
                    throw_read_only([
                        'Cannot assign to read-only attribute "[_1]"',
                        '$meth',
                    ]) if \@_;
                    return unless \$o;
                    return \$o->$name;
                }}
                : qq{sub {
                     my \$self = shift;
                     my \$o = \$self->{$aname} or return;
                     return \$o->$name unless \@_;
                     \$o->$name(\@_);
                     \$self->_add_modified('$meth')
                         if \$o->_is_modified('$name');
                     return \$self;
                }}
        );
    }
}

##############################################################################

=head3 _set

  _set($object, $attr_name, $value);

This function is used to set an attribute to a new value. It will only set it
to the new value if it is different from the old value. In addition it will
add the name of the attribute to a list of changed attributes that can then be
fetched by the data store for updating the table with only the changed
attributes.

=cut

sub _set {
    my ($self, $key, $new) = @_;
    my $old = $self->{$key};
    COMPARE: {
        no warnings;
        return $self if defined $new == defined $old && $new eq $old;
    }

    $self->{$key} = $new;
    $self->_add_modified($key);
    return $self;
}

1;
__END__

##############################################################################

=end private

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
