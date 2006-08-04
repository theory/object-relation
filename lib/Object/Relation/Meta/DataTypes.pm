package Object::Relation::Meta::DataTypes;

# $Id$

use strict;

our $VERSION = '0.11';

use Object::Relation::Meta::Type;
use Object::Relation::Functions qw(:gtin :uuid);
use Data::Types;
use Object::Relation::Exceptions qw(throw_invalid);
use version;

=head1 Name

Object::Relation::Meta::DataTypes - Object::Relation data type definition

=head1 Synopsis

  package Object::Relation::Foo;
  use Object::Relation;

  meta 'foo';
  has bar => ( type => 'bool' );
  build;

=head1 Description

This module handles the definition of fundamental data types used by TKP. As
these data types are loaded by TKP and are always available for use, this
module should never be used directly. Other data types may be loaded from the
modules in the Object::Relation::DataType name space. Classes that inherit from
L<Object::Relation::Base|Object::Relation::Base> and are defined by
L<Object::Relation::Meta|Object::Relation::Meta> are also available as data types,
referenceable by their key names.

Consult L<Object::Relation::Meta|Object::Relation::Meta> and
L<Class::Meta|Class::Meta> for details on creating new Object::Relation classes with
attributes of the types defined by this module.

=cut

sub _make_isa_check {
    my $pkg = shift;
    return [ sub {
        return unless defined $_[0];
        UNIVERSAL::isa($_[0], $pkg)
          or throw_invalid(['Value "[_1]" is not a valid [_2] object',
                            $_[0], $pkg]);
    } ];
};

Object::Relation::Meta::Type->class_validation_generator(\&_make_isa_check);

##############################################################################

=head1 Data Types

The Data types defined by this module are:

=over 4

=item uuid

A globally unique identifier as generated by Data::UUID.

=cut

Object::Relation::Meta::Type->add(
    key     => 'uuid',
    name    => 'Universally Unique Identifier',
    check   => sub {
        uuid_to_bin $_[0]
            or throw_invalid(['Value "[_1]" is not a UUID', $_[0]]);
    }
);

##############################################################################

=item string

A Perl string, decoded to its internal, utf8 format.

=cut

Object::Relation::Meta::Type->add(
    key     => 'string',
    name    => 'String',
    check   => sub {
        return unless ref $_[0];
        throw_invalid([ 'Value "[_1]" is not a string', $_[0] ]);
    }
);

##############################################################################

=item integer

=item int

An integer. Throws a Fatal::Invalid exception if the value is not a whole
number.

=cut

Object::Relation::Meta::Type->add(
    key     => 'integer',
    alias   => 'int',
    name    => 'Integer',
    check   => sub {
        return unless defined $_[0];
        Data::Types::is_int($_[0])
          or throw_invalid([ 'Value "[_1]" is not an integer', $_[0] ]);
    }
);

##############################################################################

=item whole

A whole number, which is to say any integer greater than or equal to 0. Throws
a Fatal::Invalid exception if the value is not a whole number.

=cut

Object::Relation::Meta::Type->add(
    key     => 'whole',
    name    => 'Whole Number',
    check   => sub {
        return unless defined $_[0];
        Data::Types::is_whole($_[0])
          or throw_invalid([ 'Value "[_1]" is not a whole number', $_[0] ]);
    }
);

##############################################################################

=item posint

A positive integer. Throws a Fatal::Invalid exception if the value is not a
posint number.

=cut

Object::Relation::Meta::Type->add(
    key     => 'posint',
    name    => 'Positive Integer',
    check   => sub {
        return unless defined $_[0];
        Data::Types::is_count($_[0])
          or throw_invalid([ 'Value "[_1]" is not a positive integer', $_[0] ]);
    }
);

##############################################################################

=item bool

A boolean value.

=cut

use Class::Meta::Types::Boolean;

##############################################################################

=item binary

Binary data. Attributes of this type should be used to store relatively small
quantities of binary data, such as small Web images and the like. Larger
quantities of binary data should be stored in blob attributes (TBD).

=cut

Object::Relation::Meta::Type->add(
    key   => 'binary',
    name  => 'Binary Data',
);

##############################################################################

=item version

A L<version|version> object.

=cut

Object::Relation::Meta::Type->add(
    key   => 'version',
    name  => 'Version',
    check => 'version',
    bake  => sub { version->new(shift) },
    # John Peacock says he might implement this method in version.pm soonish.
#    raw   => sub { ref $_[0] ? shift->serialize : shift },
    raw   => sub {
        return shift unless ref $_[0];
        (my $ver = shift->normal) =~ s/^v//;
        my @parts = split /\./, $ver;
        my $format = 'v%d' . ('.%03d') x $#parts;
        sprintf $format, @parts;
    },
);

##############################################################################

=item operator

Operator strings. Allowable operators are:

=over

=item ==

=item E<gt>

=item E<lt>

=item E<gt>=

=item E<lt>=

=item !=

=item eq

=item ne

=item gt

=item lt

=item ge

=item le

=item =~

=item !~

=back

=cut

my %ops = ( map { $_ => undef } qw(== > < >= <= != eq ne gt lt ge le =~ !~) );

Object::Relation::Meta::Type->add(
    key   => 'operator',
    name  => 'Operator',
    check => sub {
        throw_invalid( [ 'Value "[_1]" is not a valid operator', $_[0] ] )
            unless exists $ops{ $_[0] };
    },
);

##############################################################################

=item attribute

L<Object::Relation::Meta::Attribute|Object::Relation::Meta::Attribute> objects.

=cut

Object::Relation::Meta::Type->add(
    key   => 'attribute',
    name  => 'Attribute',
    raw   => sub { ref $_[0] ? $_[0]->class->key . '.' . $_[0]->name : shift },
    bake  => sub { Object::Relation::Meta->attr_for_key(shift) },
    check => 'Object::Relation::Meta::Attribute',
);

##############################################################################

=item gtin

A GTIN code, which includes UPC-A and EAN codes. Some examples:

  036000291452
  0036000291452
  725272730706
  0978020137962
  4007630000116

Validity of a GTIN is calculated by the C<isa_gtin()> function imported from
L<Object::Relation::Functions|Object::Relation::Functions>.

=cut

Object::Relation::Meta::Type->add(
    key   => 'gtin',
    name  => 'GTIN',
    check => sub {
        throw_invalid( [ 'Value "[_1]" is not a valid GTIN', $_[0] ] )
            unless isa_gtin($_[0]);
    },
);

=back

=cut

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@kineticode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
