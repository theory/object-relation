package Object::Relation::Meta::Type;

# $Id$

use strict;

use version;
our $VERSION = version->new('0.1.0');

use base 'Class::Meta::Type';
use Object::Relation::Meta::AccessorBuilder;
__PACKAGE__->default_builder('Object::Relation::Meta::AccessorBuilder');

=head1 Name

Object::Relation::Meta::Type - Object::Relation Data type validation and accessor building

=head1 Synopsis

  Object::Relation::Meta::Type->add(
      key     => "state",
      name    => "State",
      builder => 'Object::Relation::Meta::AccessorBuilder',
      raw     => sub { ref $_[0] ? shift->value : shift },
      store_raw   => sub { shift->store_value },
      check   => sub {
          UNIVERSAL::isa($_[0], 'Object::Relation::DataType::State')
              or throw_invalid(['Value "[_1]" is not a valid [_2] object',
                                $_[0], 'Object::Relation::DataType::State']);
          throw_invalid(['Cannot assign permanent state'])
            if $_[0] == Object::Relation::DataType::State->PERMANENT;
      }
  );

=head1 Description

This class subclasses L<Class::Meta::Type|Class::Meta::Type> to provide
additional attributes. These attributes can optionally be set via the call to
C<new()>, and may be fetched via their accessors.

=head1 Dynamic APIs

This class supports the dynamic loading of extra methods specifically designed
to be used with particular Object::Relation data store implementations. See
L<Object::Relation::Meta|Object::Relation::Meta> for details. The supported labels are:

=over

=item :with_dbstore_api

Adds a new() constructor to overload the parent. The purpose is to add a raw()
accessor that returns the database ID of an referenced object, rather than the
object itself.

=begin comment

=item new

Allow POD coverage tests to pass.

=end comment

=back

=cut

sub import {
    my ($pkg, $api_label) = @_;
    return unless $api_label;
    if ($api_label eq ':with_dbstore_api') {
        return if defined(&new);
        # Create methods specific to database stores.
        no strict 'refs';
        *{__PACKAGE__ . '::new'} = sub {
            my $self = shift->SUPER::new(@_);
            # Set the raw method to return the object ID. Use
            # Class::Meta->for_key to avoid Object::Relation::Meta->for_key's
            # exception.
            $self->{raw} ||= sub {
                my $obj = shift or return undef;
                return $obj->id;
            } if Class::Meta->for_key($self->key);
            return $self;
        };
    }
}

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 raw

  my $code = $type->raw;

Returns a code reference to get the raw value of a type. Used internally by
L<Object::Relation::Meta::Attribute|Object::Relation::Meta::Attribute>.

The code reference should simply expect the value returned by the C<get>
accessor as its sole argument. It can then take whatever steps are necessary
to return a serializable value. For example, if for a
L<Object::Relation::DataType::DateTime|Object::Relation::DataType::DateTime> data type, we might
want to get back a string in ISO-8601 format in the UTC time zone. The raw
code reference to do so might look like this:

  sub { shift->clone->set_time_zone('UTC')->iso8601 }

=cut

sub raw { shift->{raw} }

##############################################################################

=head3 store_raw

  my $code = $type->store_raw;

Returns a code reference to get the store raw value of a type. Used internally
by L<Object::Relation::Meta::Attribute|Object::Relation::Meta::Attribute>. In general, it will
exactly the same as C<raw()>, but may occasionally be different, as when
different data stores require different raw values for a particular data type.

For the L<Object::Relation::DataType::Duration|Object::Relation::DataType::Duration> type, for
example, C<raw()> would return an ISO-8601 string representation, while
C<store_raw()> would return one string representation for the PostgreSQL data
store, and a 0-padded ISO-8601 string for all other data stores.

As with the C<raw()> code reference. The store_raw code reference should expect
the value returned from an attribute's C<get()> method.

=cut

sub store_raw { shift->{store_raw} }

##############################################################################

=head3 bake

  my $code = $type->bake;

Returns a code reference to set the raw value of a type without actually
needing to set an object value. Used internally by
L<Object::Relation::Meta::Attribute|Object::Relation::Meta::Attribute>.

=cut

sub bake { shift->{bake} }

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004-2006 Kineticode, Inc. <info@obj_relode.com>

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
