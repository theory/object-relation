package Kinetic::Meta::DataTypes;

# $Id$

use strict;
use Class::Meta::Type;
use Data::UUID;
use Data::Types;
use Kinetic::DateTime;
use Kinetic::Exceptions qw(throw_invalid);
use Kinetic::Meta::AccessorBuilder;

=head1 Name

Kinetic::Meta::DataTypes - Kinetic data type definition

=head1 Synopsis

  package Kinetic::Foo;
  use strict;
  use base 'Kinetic';

  BEGIN {
      my $cm = Kinetic::Meta->new( key => 'foo );
      $cm->add_attribute( name => 'bar',
                          type => 'bool' );
     $cm->build;
  }

=head1 Description

This module handles the definition of data types used by Kinetic. It should
never be used directly. Consult L<Kinetic::Meta|Kinetic::Meta> and
L<Class::Meta|Class::Meta> for details on creating new Kinetic classes with
attributes of the types defined by this module.

=cut

sub _make_isa_check {
    my $pkg = shift;
    return sub {
        return unless defined $_[0];
        UNIVERSAL::isa($_[0], $pkg)
          or throw_invalid(['Value "[_1]" is not a [_2] object', $_[0], $pkg]);
    };
};

##############################################################################

=head1 Data Types

The Data types defined by this module are:

=over 4

=item guid

A globally unique identifier as generated to Data::UUID.

=cut

my $ug = Data::UUID->new;
Class::Meta::Type->add(
    key     => "guid",
    name    => "Globally Unique Identifier",
    builder => 'Kinetic::Meta::AccessorBuilder',
    check   => sub {
        eval { $ug->from_string($_[0]) }
          or throw_invalid(['Value "[_1]" is not a GUID', $_[0]]);
    }
);

=item string

A Perl string, decoded to its internal, utf8 format.

=cut

Class::Meta::Type->add(
    key     => "string",
    name    => "String",
    builder => 'Kinetic::Meta::AccessorBuilder',
    check   => sub {
        return unless defined $_[0] && ref $_[0];
        $_[2]->class->handle_error("Value '$_[0]' is not a valid string");
    }
);

##############################################################################

=item whole

A whole number. Throws a Fatal::Invalid exception if the value is not a valid
number.

=cut

Class::Meta::Type->add(
    key     => "whole",
    name    => "Whole Number",
    builder => 'Kinetic::Meta::AccessorBuilder',
    check   => sub {
        return unless defined $_[0];
        Data::Types::is_whole($_[0])
          or throw_invalid("Value '$_[0]' is not a whole number");
    }
);

##############################################################################

=item bool

A boolean value.

=cut

use Class::Meta::Types::Boolean;

##############################################################################

=item datetime

A Kinetic::DateTime object.

=cut

BEGIN {
    Class::Meta::Type->add(
        key     => "datetime",
        name    => "DateTime",
        builder => 'Kinetic::Meta::AccessorBuilder',
        check   => _make_isa_check('Kinetic::DateTime')
    );
}

##############################################################################

=item user

A Kinetic::Party::Person::User object.

=cut

BEGIN {
    Class::Meta::Type->add(
        key     => "user",
        name    => "User",
        builder => 'Kinetic::Meta::AccessorBuilder',
        check   => _make_isa_check('Kinetic::Party::Person::User')
    );
}

##############################################################################

=item state

A Kinetic::State object.

=cut

BEGIN {
    Class::Meta::Type->add(
        key     => "state",
        name    => "State",
        builder => 'Kinetic::Meta::AccessorBuilder',
        check   => sub {
            UNIVERSAL::isa($_[0], 'Kinetic::State')
              or throw_invalid(['Value "[_1]" is not a [_2] object', $_[0],
                                'Kinetic::State']);
            throw_invalid(['Cannot assign permanent state'])
              if $_[0] == Kinetic::State->PERMANENT;
        }
    );
}

=back

=cut

1;
__END__

##############################################################################

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item L<Kinetic::Meta|Kinetic::Meta>

The Kinetic metadata class.

=item L<Class::Meta|Class::Meta>

Class automation, introspection, and data type validation. Used to generate
Kinetic classes.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This Library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
