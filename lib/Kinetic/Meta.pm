package Kinetic::Meta;

# $Id$

use strict;
use base 'Class::Meta';
use Kinetic::Meta::DataTypes;
use Kinetic::Meta::Attribute;
use Kinetic::Meta::Class;
use Kinetic::Exceptions qw(throw_exlib);
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

=head1 Author

Kineticode, Inc. <info@kineticode.com>

=head1 See Also

=over 4

=item L<Kinetic::Base|Kinetic::Base>

The Kinetic base class.

=item L<Kinetic::Meta::Class|Kinetic::Meta::Class>

The Kinetic class metadata class.

=back

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
