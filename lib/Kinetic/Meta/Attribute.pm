package Kinetic::Meta::Attribute;

# $Id$

use strict;
use base 'Class::Meta::Attribute';
use Kinetic::Util::Context;
use Widget::Meta;

=head1 Name

Kinetic::Meta::Attribute - Kinetic object attribute introspection

=head1 Synopsis

  # Assuming MyThingy was generated by Kinetic::Meta.
  my $class = MyThingy->my_class;
  my $thingy = MyThingy->new;

  print "\nAttributes:\n";
  for my $attr ($class->attributes) {
      print "  o ", $attr->name, " => ", $attr->get($thingy), $/;
      if ($attr->authz >= Class::Meta::SET && $attr->type eq 'string') {
          $attr->get($thingy, 'hey there!');
          print "    Changed to: ", $attr->get($thingy) $/;
      }
  }

=head1 Description

This class inherits from L<Class::Meta::Attribute|Class::Meta::Attribute> to
provide attribute metadata for Kinetic classes. See the
L<Class::Meta|Class:Meta> documentation for details on meta classes. See the
L<"Instance Interface"> section for the attributes added to
Kinetic::Meta::Attribute in addition to those defined by
Class::Meta::Attribute.

=cut

my $build_mode = 0;
sub import {
    return unless @_ > 2;
    $build_mode = $_[2];
}

##############################################################################
# Class Methods
##############################################################################

=head1 Class Interface

=head2 Constructors

=head3 new

This method is designed to only be called internally by C<Kinetic::Meta>. It
overrides the behavior of C<< Class::Meta::Attribute->new >> to delete
attributes relevant only during data store schema generation. See
L<Kinetic::Build::Schema|Kinetic::Build::Schema> for more information.

=cut

sub new {
    my $self = shift->SUPER::new(@_);
    delete @{$self}{qw(indexed store_default)} unless $build_mode;
    return $self;
}

##############################################################################
# Instance Methods.
##############################################################################

=head1 Instance Interface

=head2 Accessor Methods

=head3 label

  my $label = $attr->label;

Returns the localized form of the label for the attribute, such as "Name".

=cut

sub label {
    Kinetic::Util::Context->language->maketext(shift->SUPER::label);
}

##############################################################################

=head3 widget_meta

  my $wm = $attr->widget_meta;

Returns a L<Widget::Meta|Widget::Meta> object describing the type of widget to
be used to allow input for an attribute. If no widget is provided, then no
field is required.

=cut

sub widget_meta { shift->{widget_meta} }

##############################################################################

=head3 unique

  my $unique = $attr->unique;

Returns true if an attribute is unique across all objects of a class.

=cut

sub unique { shift->{unique} }

##############################################################################

=head3 indexed

  my $indexed = $attr->indexed;

During date store schema generation, returns true if an attribute is indexed
in the data store, and false if it is not. Disabled when
C<Kinetic::Build::Schema> is not loaded.

=cut

sub indexed { shift->{indexed} }

##############################################################################

=head3 store_default

  my $store_default = $attr->store_default;

During date store schema generation, returns a default value meant to be
configured in a data store, if any. Disabled when C<Kinetic::Build::Schema>
is not loaded.

=cut

sub store_default { shift->{store_default} }

1;
__END__

##############################################################################

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. <info@kineticode.com>

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
